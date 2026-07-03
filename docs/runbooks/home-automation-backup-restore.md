# Home automation backup and restore

This runbook covers the coordinated Restic backup for Home Assistant,
Mosquitto, InfluxDB, and UniFi on Icarus.

## Backup contents

The backup job creates this local staging tree:

```text
/var/backup/home-automation/current/
├── home-assistant/  cold copy of /var/lib/home-assistant
├── mosquitto/       cold copy of /var/lib/mosquitto
├── unifi/           cold copy of /var/lib/unifi
└── influxdb/        logical backup created by `influx backup`
```

Home Assistant, Mosquitto, and UniFi are stopped only while their local state is being
copied. InfluxDB remains online and is captured through its supported logical
backup command. The stopped services are restarted before Restic uploads the
staging tree to Vela.

## Vela preparation

The current Vela container uses these bind mounts:

```text
/config/rest-server      -> /config
/mnt/user/backups/restic -> /data
```

The container reads its password file from `/config/.htpasswd`, so the active
host file is:

```text
/config/rest-server/.htpasswd
```

Confirm this before changing credentials:

```bash
docker inspect rest-server |
  jq -r '.[0].Mounts[] | "\(.Source) -> \(.Destination) [\(.Mode)]"'

docker inspect rest-server |
  jq -r '.[0].Config.Env[]' |
  grep -E 'PASSWORD_FILE|OPTIONS|VIRTUAL_HOST'

ls -la /config/rest-server
```

Back up the current password file:

```bash
cp \
  /config/rest-server/.htpasswd \
  /config/rest-server/.htpasswd.bak
```

Append the private `rest-server` account. The `>>` operator is intentional;
using `>` would overwrite the working `restic-gitea` account:

```bash
docker run --rm \
  --entrypoint htpasswd \
  httpd:2.4-alpine \
  -Bbn \
  restic-home-automation \
  'REST_SERVER_HTTP_PASSWORD' \
  >> /config/rest-server/.htpasswd
```

Verify both accounts and retain the existing permissions:

```bash
cut -d: -f1 /config/rest-server/.htpasswd
chmod 0640 /config/rest-server/.htpasswd
docker restart rest-server
docker logs --tail 100 rest-server
```

Expected account names include:

```text
restic-gitea
restic-home-automation
```

The repository directory does not need to be created manually. The NixOS
Restic job uses `initialize = true`, so the first successful run initializes
the private repository under `/mnt/user/backups/restic`.

Store the HTTP password separately from the Restic repository encryption
password. The default repository URL is:

```text
rest:https://restic.c4rb0n.cloud/restic-home-automation
```

Add the encrypted values to `secrets/infrastructure.yaml`:

```yaml
restic:
  home_automation:
    repository_password: "<random repository encryption password>"
    environment: |
      RESTIC_REST_USERNAME=restic-home-automation
      RESTIC_REST_PASSWORD=<rest-server HTTP password>
```

Generate independent random values, for example:

```bash
openssl rand -base64 36
openssl rand -base64 36
```

Edit the encrypted file with:

```bash
sops secrets/infrastructure.yaml
```

Verify that the expected keys exist without printing their values:

```bash
sops --decrypt secrets/infrastructure.yaml |
  yq '{
    repository_password: (.restic.home_automation.repository_password != null),
    environment: (.restic.home_automation.environment != null)
  }'
```

## Enable and deploy

Icarus enables the coordinated job with:

```nix
infra.services.homeAutomationBackup.enable = true;
```

Validate and deploy:

```bash
nix fmt
nix flake check
task build HOST=icarus
task switch HOST=icarus
```

Confirm the generated timer and service:

```bash
systemctl status restic-backups-home-automation.timer --no-pager
systemctl list-timers restic-backups-home-automation.timer --all
systemctl cat restic-backups-home-automation.service
```

## Schedule, downtime, and failure behavior

The default timer configuration is:

```text
OnCalendar=04:30
RandomizedDelaySec=15m
Persistent=true
```

The backup therefore starts once per day between `04:30` and approximately
`04:45`. `Persistent=true` means that a timer occurrence missed while Icarus
was powered off runs after the host returns. It does not retry a backup that
started and failed.

Each invocation follows this order:

1. stop Home Assistant, Mosquitto, and UniFi;
2. copy their state to the local staging tree;
3. create the logical InfluxDB backup;
4. restart Home Assistant, Mosquitto, and UniFi;
5. upload the completed staging tree to Vela;
6. apply the retention policy.

The service-stop window therefore covers only local copies and the logical
InfluxDB backup. Vela availability does not extend the Home Assistant, Mosquitto, or UniFi
downtime because all three services are restarted before Restic begins its
network upload. An exit trap also starts all three services if local staging
fails.

The generated systemd service has a two-hour `TimeoutStartSec`. If Restic does
not finish within that period, systemd terminates the invocation and records a
failure. There is no automatic same-day restart loop; the next scheduled
attempt is the next timer occurrence. Retry manually after fixing the cause:

```bash
sudo systemctl reset-failed restic-backups-home-automation.service
sudo systemctl start restic-backups-home-automation.service
sudo journalctl -fu restic-backups-home-automation.service
```

Inspect the effective schedule and timeout with:

```bash
systemctl list-timers restic-backups-home-automation.timer --all
systemctl show restic-backups-home-automation.service \
  --property=TimeoutStartUSec \
  --property=Result \
  --property=ExecMainStatus
```

## First manual backup

Start the job manually while watching its log:

```bash
sudo systemctl start restic-backups-home-automation.service
sudo journalctl -fu restic-backups-home-automation.service
```

In another terminal, confirm that Home Assistant, Mosquitto, and UniFi return to the
running state after local staging completes:

```bash
systemctl status \
  podman-home-assistant.service \
  podman-unifi.service \
  mosquitto.service \
  influxdb2.service \
  --no-pager
```

A successful run should leave a populated staging tree:

```bash
sudo du -sh /var/backup/home-automation/current/*
sudo test -f /var/backup/home-automation/current/home-assistant/.storage/core.config_entries
sudo test -f /var/backup/home-automation/current/mosquitto/mosquitto.db
sudo test -d /var/backup/home-automation/current/unifi
sudo test -d /var/backup/home-automation/current/influxdb
```

## Inspect and check the repository

The NixOS Restic module creates a host-local wrapper containing the configured
repository and credentials:

```bash
sudo restic-home-automation snapshots
sudo restic-home-automation check
```

Inspect the latest snapshot contents:

```bash
sudo restic-home-automation ls latest \
  /var/backup/home-automation/current
```

## Test restore without touching live state

Restore the latest snapshot into a disposable directory:

```bash
sudo rm -rf /var/tmp/home-automation-restic-test
sudo install -d -m 0700 /var/tmp/home-automation-restic-test

sudo restic-home-automation restore latest \
  --target /var/tmp/home-automation-restic-test
```

Validate the expected data:

```bash
restore_root=/var/tmp/home-automation-restic-test/var/backup/home-automation/current

sudo test -f "$restore_root/home-assistant/.storage/core.config_entries"
sudo test -f "$restore_root/home-assistant/home-assistant_v2.db"
sudo test -f "$restore_root/mosquitto/mosquitto.db"
sudo test -d "$restore_root/unifi"
sudo test -d "$restore_root/influxdb"
```

Check the restored Home Assistant SQLite database:

```bash
sudo python - <<'PY'
import sqlite3

path = "/var/tmp/home-automation-restic-test/var/backup/home-automation/current/home-assistant/home-assistant_v2.db"
connection = sqlite3.connect(path)
try:
    print(connection.execute("PRAGMA integrity_check;").fetchone()[0])
finally:
    connection.close()
PY
```

Expected output:

```text
ok
```

Remove the test restore after validation:

```bash
sudo rm -rf /var/tmp/home-automation-restic-test
```

## Full restore

Perform a full restore only while the live services are stopped.

### 1. Restore a snapshot to staging

```bash
sudo rm -rf /var/tmp/home-automation-restore
sudo install -d -m 0700 /var/tmp/home-automation-restore

sudo restic-home-automation restore latest \
  --target /var/tmp/home-automation-restore
```

Set a reusable source path:

```bash
restore_root=/var/tmp/home-automation-restore/var/backup/home-automation/current
```

### 2. Stop the live services

```bash
sudo systemctl stop podman-home-assistant.service
sudo systemctl stop podman-unifi.service
sudo systemctl stop mosquitto.service
sudo systemctl stop influxdb2.service
```

### 3. Preserve the current state

```bash
stamp="$(date +%F-%H%M%S)"

sudo mv /var/lib/home-assistant "/var/lib/home-assistant.before-restore-$stamp"
sudo mv /var/lib/mosquitto "/var/lib/mosquitto.before-restore-$stamp"
sudo mv /var/lib/unifi "/var/lib/unifi.before-restore-$stamp"
sudo mv /var/lib/influxdb2 "/var/lib/influxdb2.before-restore-$stamp"
```

### 4. Restore Home Assistant

```bash
sudo install -d -m 0750 /var/lib/home-assistant
sudo rsync \
  --archive \
  --hard-links \
  --acls \
  --xattrs \
  --numeric-ids \
  "$restore_root/home-assistant/" \
  /var/lib/home-assistant/
```

The SOPS-managed `/config/secrets.yaml` bind mount overrides the restored file
when the container starts.

### 5. Restore Mosquitto

```bash
sudo install -d -o mosquitto -g mosquitto -m 0750 /var/lib/mosquitto
sudo rsync \
  --archive \
  --hard-links \
  --acls \
  --xattrs \
  --numeric-ids \
  "$restore_root/mosquitto/" \
  /var/lib/mosquitto/

sudo chown -R mosquitto:mosquitto /var/lib/mosquitto
```

### 6. Restore UniFi

```bash
sudo install -d -m 0750 /var/lib/unifi
sudo rsync \
  --archive \
  --hard-links \
  --acls \
  --xattrs \
  --numeric-ids \
  "$restore_root/unifi/" \
  /var/lib/unifi/
```

### 7. Restore InfluxDB

Start a clean InfluxDB service and restore the logical backup:

```bash
sudo install -d -o influxdb2 -g influxdb2 -m 0750 /var/lib/influxdb2
sudo systemctl start influxdb2.service
```

Use the operator token managed by SOPS:

```bash
sudo influx restore \
  --host http://127.0.0.1:8086 \
  --token "$(sudo cat /run/secrets/influxdb/operator_token)" \
  --full \
  "$restore_root/influxdb"
```

If the target InfluxDB instance is already provisioned and `--full` reports
conflicts, stop and inspect the error before deleting data. Do not combine a
partial restore with the preserved pre-restore state unless the intended
organization and bucket mappings are understood.

### 8. Start and validate

```bash
sudo systemctl start mosquitto.service
sudo systemctl start podman-unifi.service
sudo systemctl start podman-home-assistant.service

systemctl status \
  influxdb2.service \
  mosquitto.service \
  podman-unifi.service \
  podman-home-assistant.service \
  --no-pager
```

Validate:

```bash
curl --fail http://127.0.0.1:8086/health
curl --fail http://127.0.0.1:8123
sudo journalctl \
  -u influxdb2 \
  -u mosquitto \
  -u podman-unifi \
  -u podman-home-assistant \
  --since "10 minutes ago" \
  --no-pager
```

Keep the `*.before-restore-*` directories until Home Assistant, MQTT clients,
Zigbee devices, and InfluxDB measurements have been validated.

## Failure behavior

The staging command installs an exit trap before stopping Home Assistant and
Mosquitto. If copying state or creating the InfluxDB backup fails, the trap
starts both services again. The Restic cleanup command is also idempotent and
starts both services after the backup attempt.

If Vela is unavailable, local staging has already completed and Home Assistant
and Mosquitto have already restarted. Restic normally reports the backend error
and exits. A hung invocation is terminated by systemd after two hours. The
timer does not retry failed executions automatically; either start the service
manually after Vela returns or wait for the next daily invocation.

Check failures with:

```bash
systemctl status restic-backups-home-automation.service --no-pager
sudo journalctl \
  -u restic-backups-home-automation.service \
  -n 200 \
  --no-pager
```
