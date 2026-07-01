# Home automation migration and recovery

This runbook moves Home Assistant and Mosquitto from Icarus to Mia and creates
a fresh native InfluxDB 2 deployment.

## Target architecture

| Component | Deployment | Persistent state |
| --- | --- | --- |
| Home Assistant 2025.12.3 | Podman OCI container | `/var/lib/home-assistant` |
| Mosquitto | native NixOS service | `/var/lib/mosquitto` |
| InfluxDB 2 | native NixOS service | `/var/lib/influxdb2` |
| TLS | native Nginx and ACME | NixOS-managed |
| Off-host backup | native Restic job | Vela `rest-server` |

Home Assistant uses host networking. Nginx proxies
`https://ha.c4rb0n.cloud` to `127.0.0.1:8123`. InfluxDB listens only on
`127.0.0.1:8086` and is exposed as `https://influx.c4rb0n.cloud`.
Mosquitto listens on LAN TCP port `1883`.

## Zigbee coordinator

The migration reuses the existing coordinator and Zigbee network:

```text
Device: Silicon Labs Sonoff Zigbee 3.0 USB Dongle Plus
USB vendor/product: 10c4:ea60
ID_SERIAL: Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001
Stable host path: /dev/serial/by-id/usb-Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001-if00-port0
Container path: /dev/ttyZIGBEE
```

Mapping the stable host path to the existing container path preserves ZHA's
stored serial configuration. Copy the complete `.storage` directory and move
the same physical dongle; devices should not require pairing again.

## Required encrypted values

Add these values to `secrets/infrastructure.yaml` using `sops`:

```yaml
mosquitto:
  users:
    mosquitto:
      password_hash: "$7$..."

influxdb:
  admin_password: "..."
  operator_token: "..."
  home_assistant_token: "..."

home_assistant:
  secrets_yaml: |
    influxdb_token: "same value as influxdb.home_assistant_token"
    # Preserve all other Home Assistant !secret values.

restic:
  home_automation:
    repository_password: "..."
    environment: |
      RESTIC_REST_USERNAME=restic-home-automation
      RESTIC_REST_PASSWORD=...
```

Extract the existing Mosquitto hash without the username:

```bash
sudo cut -d: -f2- \
  ~/docker-compose/data/mosquitto-data/config/mosquitto.passwd
```

Do not commit Icarus's plaintext Home Assistant `secrets.yaml`.

## Preparation deployment on Mia

The host enables native Mosquitto and InfluxDB immediately, while Home
Assistant and the combined backup remain disabled from automatic execution:

```nix
infra.services = {
  mosquitto.enable = true;
  influxdb.enable = true;

  homeAssistant = {
    enable = true;
    autoStart = false;
  };

  homeAutomationBackup.enable = false;
};
```

Validate and apply:

```bash
nix fmt
nix flake check
task build HOST=mia
task switch HOST=mia

systemctl status mosquitto influxdb2 --no-pager
curl --fail http://127.0.0.1:8086/health
systemctl status podman-home-assistant --no-pager
```

Home Assistant being inactive is expected while `autoStart = false`.

## Create the cold transfer on Icarus

Stop only the services being moved:

```bash
cd ~/docker-compose
docker compose stop homeassistant mosquitto
```

Archive the complete Home Assistant configuration and Mosquitto persistence:

```bash
stamp="$(date +%F-%H%M%S)"

sudo tar \
  --xattrs \
  --acls \
  --numeric-owner \
  --zstd \
  -C data \
  -cpf "/tmp/home-automation-${stamp}.tar.zst" \
  home-assistant-data/config \
  mosquitto-data/data/mosquitto.db

sudo chown mhr:mhr "/tmp/home-automation-${stamp}.tar.zst"
scp "/tmp/home-automation-${stamp}.tar.zst" \
  mhr@mia:/var/tmp/
```

Leave the Icarus containers stopped and their state unchanged for rollback.

## Restore state on Mia

```bash
sudo rm -rf /var/tmp/home-automation-restore
sudo install -d -m 0700 /var/tmp/home-automation-restore

sudo tar \
  --zstd \
  --xattrs \
  --acls \
  --numeric-owner \
  -xpf "/var/tmp/home-automation-${stamp}.tar.zst" \
  -C /var/tmp/home-automation-restore

sudo rsync \
  --archive \
  --hard-links \
  --acls \
  --xattrs \
  --delete \
  /var/tmp/home-automation-restore/home-assistant-data/config/ \
  /var/lib/home-assistant/

sudo systemctl stop mosquitto
sudo install \
  -o mosquitto \
  -g mosquitto \
  -m 0600 \
  /var/tmp/home-automation-restore/mosquitto-data/data/mosquitto.db \
  /var/lib/mosquitto/mosquitto.db
```

The SOPS-managed `/config/secrets.yaml` mount overrides the copied runtime
file. Ensure `home_assistant/secrets_yaml` contains every required key before
starting the container.

## Adjust Home Assistant configuration

Update the restored `configuration.yaml`:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
    - ::1

influxdb:
  api_version: 2
  ssl: false
  host: 127.0.0.1
  port: 8086
  organization: bsw
  bucket: homeassistant
  token: !secret influxdb_token
  max_retries: 3
  default_measurement: state
```

After startup, change the MQTT integration from the old Icarus address to
`127.0.0.1:1883`. External MQTT clients use Mia's LAN address or the stable
`mqtt.c4rb0n.cloud` name.

## Move hardware and start

Move the Sonoff dongle from Icarus to Mia and verify it:

```bash
ls -l /dev/serial/by-id/
udevadm info \
  --query=property \
  --name=/dev/serial/by-id/usb-Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001-if00-port0 \
  | grep -E 'ID_VENDOR|ID_MODEL|ID_SERIAL'
```

Set automatic startup:

```nix
infra.services.homeAssistant.autoStart = true;
```

Then apply and inspect:

```bash
task build HOST=mia
task switch HOST=mia

systemctl status mosquitto influxdb2 podman-home-assistant --no-pager
journalctl -fu podman-home-assistant
```

## Functional validation

Verify:

- `https://ha.c4rb0n.cloud` loads with a trusted certificate
- existing users and dashboards are present
- ZHA opens the coordinator at `/dev/ttyZIGBEE`
- Zigbee entities recover without re-pairing
- MQTT connects using user `mosquitto`
- ESPHome integrations reconnect
- automations, scripts, and scenes execute
- InfluxDB health is green and the `homeassistant` bucket receives data

Useful commands:

```bash
curl --fail https://ha.c4rb0n.cloud
curl --fail https://influx.c4rb0n.cloud/health
journalctl -u mosquitto -u influxdb2 -u podman-home-assistant --since today
```

## Combined backup

The combined backup module remains separate because it coordinates all three
services. It creates this staging tree:

```text
/var/backup/home-automation/current/
├── home-assistant/  cold copy of /var/lib/home-assistant
├── mosquitto/       cold copy of /var/lib/mosquitto
└── influxdb/        logical InfluxDB backup
```

On Vela, create a private `rest-server` account named
`restic-home-automation`. Then enable:

```nix
infra.services.homeAutomationBackup.enable = true;
```

Apply and test:

```bash
task build HOST=mia
task switch HOST=mia

sudo systemctl start restic-backups-home-automation.service
sudo journalctl -fu restic-backups-home-automation.service
sudo restic-home-automation snapshots
sudo restic-home-automation check
```

The job restarts Mosquitto and Home Assistant before Restic uploads the staged
data, so service downtime is independent of network transfer time.

## Test a restore

```bash
sudo rm -rf /var/tmp/home-automation-restic-test
sudo install -d -m 0700 /var/tmp/home-automation-restic-test

sudo restic-home-automation restore latest \
  --target /var/tmp/home-automation-restic-test

sudo test -d \
  /var/tmp/home-automation-restic-test/var/backup/home-automation/current/home-assistant/.storage
sudo test -f \
  /var/tmp/home-automation-restic-test/var/backup/home-automation/current/mosquitto/mosquitto.db
sudo test -d \
  /var/tmp/home-automation-restic-test/var/backup/home-automation/current/influxdb
```

For production recovery, stop Home Assistant and Mosquitto, restore their
staged directories to `/var/lib/home-assistant` and `/var/lib/mosquitto`, then
run `influx restore --full` against the logical InfluxDB backup using the
retained operator token. Restore InfluxDB into an empty replacement instance.
