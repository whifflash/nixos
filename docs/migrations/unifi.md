# UniFi migration to Icarus

This migration restores the latest verified UniFi application backup into a
fresh controller running the same application version as the previous Docker
Compose deployment. The old MongoDB directory is retained as a fallback but is
not required for the normal migration.

## Source backup

The selected application backup is:

```text
/var/tmp/icarus-docker-compose-restore/docker-compose/data/unifi-backup/autobackup/autobackup_8.0.26_20260601_0030_1780273800005.unf
```

It was produced by UniFi Network Application 8.0.26. No relevant topology,
user, or configuration changes occurred after this backup.

## 1. Duplicate the backup

Never use the only extracted copy as the working import file.

```bash
sudo install -d -m 0700 /var/backups/unifi-import

sudo install \
  -o root \
  -g root \
  -m 0600 \
  /var/tmp/icarus-docker-compose-restore/docker-compose/data/unifi-backup/autobackup/autobackup_8.0.26_20260601_0030_1780273800005.unf \
  /var/backups/unifi-import/autobackup_8.0.26_20260601_0030_1780273800005.unf
```

Verify that the source and duplicate are identical:

```bash
sudo sha256sum \
  /var/tmp/icarus-docker-compose-restore/docker-compose/data/unifi-backup/autobackup/autobackup_8.0.26_20260601_0030_1780273800005.unf \
  /var/backups/unifi-import/autobackup_8.0.26_20260601_0030_1780273800005.unf
```

The hashes must match.

Copy the duplicate to the machine running the browser:

```bash
scp \
  mhr@icarus:/var/backups/unifi-import/autobackup_8.0.26_20260601_0030_1780273800005.unf \
  ./
```

## 2. Deploy without automatic startup

The initial host configuration should be:

```nix
infra.services = {
  unifi = {
    enable = true;
    autoStart = false;
  };

  homeAutomationBackup.enable = false;
};
```

Build and switch:

```bash
nix fmt
nix flake check
nix build .#nixosConfigurations.icarus.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#icarus
```

Confirm that the unit exists but remains stopped:

```bash
systemctl status podman-unifi.service --no-pager
```

## 3. Start the controller manually

```bash
sudo systemctl start podman-unifi.service
sudo journalctl -fu podman-unifi.service
```

In another terminal:

```bash
sudo podman ps --filter name=unifi
sudo podman logs --tail 200 unifi
sudo ss -lntup | grep -E ':(8080|8443|3478|10001)\b'
```

Open:

```text
https://unifi.c4rb0n.cloud
```

During first-run setup, choose the restore-from-backup path and upload:

```text
autobackup_8.0.26_20260601_0030_1780273800005.unf
```

Do not create and configure a new empty site before restoring the backup.

## 4. Validate the restore

Confirm all of the following:

- the expected site exists;
- switches and access points are listed;
- networks and WLANs match the previous deployment;
- controller users are present;
- devices reconnect and become online;
- device inform traffic reaches Icarus on TCP port 8080;
- the public UI works through `https://unifi.c4rb0n.cloud`.

Inspect recent logs when a device does not reconnect:

```bash
sudo journalctl \
  -u podman-unifi.service \
  --since "15 minutes ago" \
  --no-pager
```

The restored controller keeps its previous inform host configuration. When a
device still points to a stale address, use the device SSH interface to set the
inform URL to:

```text
http://10.20.31.41:8080/inform
```

Run `set-inform` a second time after the controller adopts the device when the
device requires it.

## 5. Enable automatic startup and backup

After the controller has been validated, update the host configuration:

```nix
infra.services = {
  unifi = {
    enable = true;
    autoStart = true;
  };

  homeAutomationBackup.enable = true;
};
```

Deploy again:

```bash
sudo nixos-rebuild switch --flake .#icarus
```

Run the first coordinated backup manually:

```bash
sudo systemctl start restic-backups-home-automation.service
sudo journalctl -fu restic-backups-home-automation.service
```

Confirm that UniFi returns to the running state after local staging:

```bash
systemctl status \
  podman-unifi.service \
  restic-backups-home-automation.service \
  --no-pager
```

## Rollback material

Do not delete these until the migrated controller has completed at least one
successful off-host backup and has operated normally for several days:

- the original `icarus-docker-compose.tar.zst` archive;
- the extracted `unifi-data` directory;
- the original `.unf` autobackup directory;
- `/var/backups/unifi-import/`.

## Upgrade the controller

The controller was restored at version `8.0.26` and then upgraded successfully
in controlled steps to `10.0.162`. Treat application upgrades as stateful
database migrations: create a rollback point, upgrade one release family at a
time, and validate the controller before continuing.

### 1. Create a rollback point

Run the coordinated Restic backup before changing the image:

```bash
sudo systemctl start restic-backups-home-automation.service
sudo journalctl -fu restic-backups-home-automation.service
```

Confirm that the snapshot exists:

```bash
sudo restic-home-automation snapshots
```

Keep the most recent `.unf` application backup as an additional recovery path.
A Restic snapshot of `/var/lib/unifi` is required because an application upgrade
may migrate the embedded database and make an image-only downgrade unsafe.

### 2. List published image versions

Use Skopeo in a temporary container so the host does not need a permanent
registry-inspection package:

```bash
sudo podman run --rm \
  quay.io/skopeo/stable:latest \
  list-tags \
  docker://docker.io/jacobalberty/unifi |
  jq -r '.Tags[]' |
  grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' |
  sort -V |
  tail -50
```

The equivalent command on a Docker host is:

```bash
docker run --rm \
  quay.io/skopeo/stable:latest \
  list-tags \
  docker://docker.io/jacobalberty/unifi |
  jq -r '.Tags[]' |
  grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' |
  sort -V |
  tail -50
```

Inspect a candidate tag before deploying it:

```bash
sudo podman pull docker.io/jacobalberty/unifi:10.0.162
sudo podman image inspect docker.io/jacobalberty/unifi:10.0.162
```

### 3. Upgrade in controlled steps

For a controller several release families behind, use this sequence:

1. select the newest patch release in the currently installed minor or major
   release family;
2. update the configured image tag;
3. deploy and wait for the controller database migration to finish;
4. validate the UI, devices, networks, WLANs, inform traffic, and recent logs;
5. run another coordinated Restic backup;
6. continue to the next release family.

Do not make several unvalidated major-version jumps in one deployment. The
successful Icarus migration used multiple steps from `8.0.26` through the
intermediate release families before reaching `10.0.162`.

Update the image in the Icarus service configuration or module, depending on
where the tag is currently set:

```nix
image = "docker.io/jacobalberty/unifi:10.0.162";
```

Pre-pull the selected image so registry or download failures are separated from
the NixOS switch:

```bash
sudo podman pull docker.io/jacobalberty/unifi:10.0.162
```

Build and deploy:

```bash
nix fmt
nix flake check
nix build .#nixosConfigurations.icarus.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#icarus
```

Follow the migration:

```bash
sudo journalctl -fu podman-unifi.service
```

In another terminal, inspect the container directly:

```bash
sudo podman logs --tail 300 unifi
systemctl status podman-unifi.service --no-pager
```

### 4. Validate every step

Before selecting the next image tag, confirm:

- the controller UI loads through `https://unifi.c4rb0n.cloud`;
- the expected site, networks, and WLANs are present;
- switches and access points reconnect;
- client and topology data continue updating;
- device inform traffic reaches TCP port 8080;
- no persistent database migration, adoption, or Java errors appear in logs.

After validation, create another coordinated backup:

```bash
sudo systemctl start restic-backups-home-automation.service
sudo journalctl -fu restic-backups-home-automation.service
```

### 5. Roll back an unsuccessful upgrade

Do not only restore the old image tag after a database migration. Restore the
matching pre-upgrade state as well:

1. stop `podman-unifi.service`;
2. restore `/var/lib/unifi` from the pre-upgrade Restic snapshot;
3. restore the previous image tag in the NixOS configuration;
4. rebuild and switch Icarus;
5. start UniFi and validate the controller.

Use the `.unf` backup to restore into a fresh controller only when a full state
restore is unavailable or deliberately not desired.
