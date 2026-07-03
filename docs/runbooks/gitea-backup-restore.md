# Gitea backup and restore runbook

This runbook covers the Gitea instance on `mia` and its Restic repository on `vela`.

## Architecture

```text
mia
└── gitea.service
    └── /var/lib/gitea
        └── restic-backups-gitea.service
            └── HTTPS: restic.c4rb0n.cloud
                └── vela nginx-proxy
                    └── rest-server:8000
                        └── /mnt/user/backups/restic
```

The public wildcard certificate for `*.c4rb0n.cloud` is issued through DNS-01 and is
terminated by `nginx-proxy` on `vela`. The Restic service does not publish port `8000`
to the LAN; it is reachable only through the shared Docker `proxy` network.

## Vela configuration

The Portainer stack contains a service equivalent to:

```yaml
rest-server:
  image: restic/rest-server:0.14.0
  container_name: rest-server
  restart: unless-stopped
  networks:
    - proxy
  environment:
    - VIRTUAL_HOST=restic.${BASE_DOMAIN}
    - VIRTUAL_PORT=8000
    - CERT_NAME=${BASE_DOMAIN}
    - NETWORK_ACCESS=internal
    - PASSWORD_FILE=/config/.htpasswd
    - OPTIONS=--private-repos --log -
  volumes:
    - /mnt/user/backups/restic:/data
    - ${REST_SERVER_APPDATA}:/config
  expose:
    - "8000"
```

Expected environment paths on `vela`:

```text
REST_SERVER_APPDATA=/mnt/user/appdata/rest-server
```

The private repository username is `restic-gitea`, matching the first path component
of the repository URL. Create or reset that account on `vela` with:

```bash
docker exec -it rest-server create_user restic-gitea
```

The resulting password hash is stored in:

```text
/mnt/user/appdata/rest-server/.htpasswd
```

After changing the password, update `RESTIC_REST_PASSWORD` in the SOPS secret on
`mia` and apply the NixOS configuration.

## Normal schedule

Inspect the configured timers:

```bash
systemctl status gitea-dump.timer --no-pager
systemctl status restic-backups-gitea.timer --no-pager
systemctl list-timers --all | grep -E 'gitea|restic'
```

The expected schedule is:

| Unit                         | Purpose                      | Schedule                      |
| ---------------------------- | ---------------------------- | ----------------------------- |
| `gitea-dump.timer`           | Local Gitea-native dump      | `03:15`                       |
| `restic-backups-gitea.timer` | Consistent off-host snapshot | `04:00` plus up to 15 minutes |

A completed one-shot Restic service normally becomes `inactive (dead)` with a
successful result. That does not mean the timer is disabled.

## Run a backup manually

Start the configured job rather than invoking `restic backup` directly. The systemd
unit includes the required stop/start hooks for SQLite consistency.

```bash
sudo systemctl start restic-backups-gitea.service
sudo journalctl -fu restic-backups-gitea.service
```

After completion:

```bash
systemctl status restic-backups-gitea.service --no-pager -l
systemctl is-active gitea.service
sudo restic-gitea snapshots
```

Success criteria:

- the journal contains `snapshot <id> saved`
- `restic-backups-gitea.service` completed successfully
- `gitea.service` is active again
- the new snapshot appears in `restic-gitea snapshots`

If the backup fails and Gitea did not restart:

```bash
sudo systemctl start gitea.service
sudo systemctl status gitea.service --no-pager -l
```

## Inspect the server side

On `vela`:

```bash
docker ps --filter name=rest-server
docker logs --since 15m rest-server
du -sh /mnt/user/backups/restic
```

Successful traffic through `nginx-proxy` and `rest-server` produces HTTP `200`
responses for repository data, index, snapshot, and lock operations.

Do not edit files inside `/mnt/user/backups/restic` manually.

## Check repository integrity

Run a metadata and repository-structure check:

```bash
sudo restic-gitea check
```

After initial setup, major storage changes, or suspected corruption, read and verify all
stored pack data:

```bash
sudo restic-gitea check --read-data
```

The full data check reads the complete repository and can be significantly slower than
a normal check.

## Test a restore without affecting production

Restore the latest snapshot into a disposable directory:

```bash
sudo rm -rf /var/tmp/gitea-restic-test
sudo install -d -m 0700 /var/tmp/gitea-restic-test

sudo restic-gitea restore latest \
  --target /var/tmp/gitea-restic-test
```

Verify the important state:

```bash
sudo test -f \
  /var/tmp/gitea-restic-test/var/lib/gitea/data/gitea.db &&
  echo "database restored"

sudo test -d \
  /var/tmp/gitea-restic-test/var/lib/gitea/repositories &&
  echo "repositories restored"

sudo find /var/lib/gitea/repositories \
  -type d -name '*.git' | wc -l

sudo find /var/tmp/gitea-restic-test/var/lib/gitea/repositories \
  -type d -name '*.git' | wc -l

sudo du -sh /var/tmp/gitea-restic-test/var/lib/gitea
```

Remove the test restore after validation:

```bash
sudo rm -rf /var/tmp/gitea-restic-test
```

A restore test should be repeated after meaningful changes to the backup topology or
credential handling, and periodically as an operational check.

## Restore production

Use this procedure only when the live Gitea state must be replaced by a Restic
snapshot.

### 1. Select and restore a snapshot into staging

```bash
sudo restic-gitea snapshots

snapshot=<snapshot-id>
sudo rm -rf /var/tmp/gitea-production-restore
sudo install -d -m 0700 /var/tmp/gitea-production-restore

sudo restic-gitea restore "$snapshot" \
  --target /var/tmp/gitea-production-restore
```

Confirm that the staged state is present:

```bash
sudo test -f \
  /var/tmp/gitea-production-restore/var/lib/gitea/data/gitea.db
sudo test -d \
  /var/tmp/gitea-production-restore/var/lib/gitea/repositories
```

### 2. Stop automated backup and Gitea

```bash
sudo systemctl stop restic-backups-gitea.timer
sudo systemctl stop gitea.service
```

### 3. Preserve the current state and install the restore

```bash
rollback="/var/lib/gitea.pre-restore-$(date +%F-%H%M%S)"
sudo mv /var/lib/gitea "$rollback"
sudo install -d -o gitea -g gitea -m 0750 /var/lib/gitea

sudo rsync \
  --archive \
  --hard-links \
  --acls \
  --xattrs \
  --numeric-ids \
  /var/tmp/gitea-production-restore/var/lib/gitea/ \
  /var/lib/gitea/

sudo chown -R gitea:gitea /var/lib/gitea
```

The rollback directory remains on the same disk and is only a short-term operational
safety copy. It is not a substitute for the off-host backup.

### 4. Start and validate Gitea

```bash
sudo systemctl start gitea.service
sudo systemctl status gitea.service --no-pager -l
sudo journalctl -u gitea.service --since '10 minutes ago' --no-pager
```

Validate:

- web login
- organizations, teams, users, and permissions
- repository browsing
- HTTPS clone
- SSH clone through TCP port `2222`
- a test push
- issues, attachments, avatars, and LFS objects where applicable

### 5. Re-enable scheduled backups

```bash
sudo systemctl start restic-backups-gitea.timer
systemctl status restic-backups-gitea.timer --no-pager
```

After the restored service has been accepted, remove staging and eventually remove the
short-term rollback copy:

```bash
sudo rm -rf /var/tmp/gitea-production-restore
# Remove the rollback directory only after explicit validation.
```

## Applying configuration changes

After changing the Gitea or Restic module:

```bash
nix fmt
task build HOST=mia
task switch HOST=mia
```

Then inspect the timers and run one manual backup:

```bash
systemctl status restic-backups-gitea.timer --no-pager
sudo systemctl start restic-backups-gitea.service
sudo journalctl -u restic-backups-gitea.service --since '10 minutes ago' --no-pager
sudo restic-gitea snapshots
```
