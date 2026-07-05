# Infrastructure monitoring

This module provides the health view for Icarus and establishes the monitoring
foundation for additional household infrastructure.

It follows the repository's service architecture: the reusable implementation
lives in `services/monitoring`, while a host opts in through
`infra.services.monitoring.enable`.

## Enablement

```nix
infra.services.monitoring.enable = true;
```

Grafana is published at `health.<infra.domain>` by default. The module uses the
shared wildcard certificate managed by the hub and therefore currently requires
`infra.services.hub.enable` on the same host.

## Scope

The current implementation contains:

- Prometheus for local metric storage and alert-rule evaluation;
- Grafana with a provisioned Prometheus data source and Icarus dashboard;
- Node Exporter collectors for host, hardware-monitor, systemd, and textfile
  metrics;
- Blackbox Exporter probes for the enabled HTTP services;
- TCP probes for Mosquitto and the inverter's Modbus endpoint;
- repository-specific metrics for backup results, the active NixOS profile,
  the configured Zigbee coordinator device, Nix store growth, system generations,
  Podman image growth, and housekeeping results;
- authenticated MQTT publish/subscribe round-trip checks;
- important MQTT topic freshness and expected-payload checks;
- conservative PV inverter payload, status, and lifetime-counter checks;
- Alertmanager with severity-based ntfy phone notifications;
- alert rules for low filesystem space and inodes, memory pressure, high
  temperature, failed systemd units, failed probes, stale or failed backups,
  missing Zigbee hardware, MQTT health, notification-path health, and basic PV
  inverter health.

The service does not alert on Icarus itself being unreachable. Prometheus,
Grafana, and the dashboard run on Icarus, so they cannot provide an independent
host-down signal. That check belongs on another device in a later deployment.

Grafana currently permits anonymous viewer access because the other service
frontends use publicly reachable hostnames. Administrative access still uses
Grafana's own authentication. Authentication through a shared identity proxy is
not currently implemented.

## Automatically derived targets

The module derives probes from enabled `infra.services` modules:

- hub;
- Gitea;
- Home Assistant;
- InfluxDB;
- Paperless-ngx;
- UniFi;
- Mosquitto;
- the inverter data collector's Modbus endpoint.

Additional household devices can be added without modifying the module:

```nix
infra.services.monitoring = {
  additionalHttpTargets.router = "https://192.0.2.1";
  additionalTcpTargets.ssh = "192.0.2.10:22";
};
```

## Backup interpretation

Monitoring reads the result and completion time of the existing systemd Restic
units. A backup is considered stale after 36 hours, allowing for the daily
schedule and its randomized delay.

This verifies that the configured job completed successfully. It does not yet
prove repository integrity or restoreability. Paperless also has no declared
off-host backup in the current repository and is therefore not represented as a
healthy backed-up service.

## Validation

After switching Icarus:

```bash
systemctl status prometheus.service grafana.service --no-pager
systemctl status prometheus-node-exporter.service prometheus-blackbox-exporter.service --no-pager
systemctl status infra-monitoring-metrics.timer --no-pager
curl --fail --silent --show-error http://127.0.0.1:9090/-/healthy
curl --fail --silent --show-error --head https://health.c4rb0n.cloud
sudo systemctl start infra-monitoring-metrics.service
grep '^infra_\(nix\|nixos\|podman\|housekeeping\)' /var/lib/prometheus-node-exporter-text-files/infra.prom
```

Inspect current Prometheus targets at `http://127.0.0.1:9090/targets` through an
SSH tunnel when troubleshooting. The Prometheus and exporter ports are bound to
loopback and are not opened in the firewall.

## Roadmap

The ordered implementation plan and completion criteria are maintained in
[`ROADMAP.md`](./ROADMAP.md).

### Maintenance and growth control

The cleanup policy is implemented by `infra.services.housekeeping` and documented
in `services/housekeeping/README.md`. It provides scheduled Nix generation and
store cleanup, store optimisation, a five-entry systemd-boot limit, and safe
pruning of Podman images unused by every existing container.

Monitoring now records:

- Nix store size and path count;
- system-generation count and oldest retained generation age;
- timestamp, result, duration, and reclaimed bytes for Nix housekeeping;
- Podman image count, total image size, and the count and size of images not
  referenced by any existing container;
- timestamp, result, duration, and reclaimed bytes for Podman housekeeping;
- alerts for failed housekeeping and jobs that have not completed for eight days;
- dashboard history for Nix store and Podman image growth.

The monitoring layer observes the declared maintenance policy rather than
substituting for it. Reclaimable Podman size is calculated from images that are
not referenced by any container. Shared image layers mean the space actually
reclaimed by Podman can be lower than the sum of image sizes; the cleanup result
therefore records the measured reduction of `/var/lib/containers/storage`.

### Application-aware health

Implemented:

- authenticated MQTT publish/subscribe round-trip latency;
- important MQTT topic freshness and expected-payload checks;
- inverter MQTT availability and state-topic freshness;
- conservative PV inverter payload, fault-state, and lifetime-counter checks;
- Alertmanager with severity-based ntfy phone notifications.

Backlog:

- Home Assistant API integration;
- unavailable Home Assistant entities;
- Zigbee device freshness using device-specific thresholds;
- Zigbee battery levels and sustained link-quality degradation;
- Mosquitto `$SYS` metrics;
- InfluxDB-specific write and storage metrics;
- service-specific health endpoints and expected-content checks.

The Home Assistant integration requires a dedicated, least-privilege API token
stored through sops-nix. It is intentionally deferred.

### Update and recovery assurance backlog

- age of `flake.lock` and the deployed repository revision;
- scheduled evaluation or build of newer repository revisions;
- newer generation built but not activated;
- running kernel differing from the current system profile;
- Restic repository integrity checks;
- scheduled test restores;
- explicit monitoring of Paperless off-host backup coverage;
- an external Icarus reachability probe hosted on another device.

## Persistent state

Prometheus and Grafana keep local state under their standard NixOS service data
directories. The provisioned dashboard, data source, scrape configuration, and
alert rules are declarative.

Prometheus data is operational telemetry and is not included in the current
backup set. Grafana's provisioned configuration can be reconstructed from this
repository. Any manually created Grafana dashboards or users are mutable state
and should not be relied upon until a backup policy is declared.

Other monitoring-related state:

| Path                                             | Owner               | Purpose                                | Backup expectation                    |
| ------------------------------------------------ | ------------------- | -------------------------------------- | ------------------------------------- |
| `/var/lib/prometheus2`                           | Prometheus          | local time-series database             | operational telemetry, not backed up  |
| `/var/lib/grafana`                               | Grafana             | users and mutable dashboards           | avoid relying on mutable dashboards   |
| `/var/lib/prometheus-node-exporter-text-files`   | textfile collectors | generated Prometheus textfile metrics  | regenerated by timers and services    |
| `/var/lib/infra-monitoring-mqtt/mqtt-state.json` | MQTT probe          | last observed MQTT topic state         | regenerated from retained MQTT topics |
| `/var/lib/ntfy-sh/user.db`                       | ntfy                | declarative ntfy user and ACL database | rebuilt from declared users and ACLs  |

Rollback uses the normal NixOS generation mechanism:

```bash
sudo nixos-rebuild switch --rollback
```

This reverts declarative Prometheus, Alertmanager, Grafana provisioning, systemd
units, scripts, and Nginx configuration. It does not roll back Prometheus time
series, mutable Grafana state, or retained MQTT messages.

## Operations runbook

### Data flow

```text
exporters and probes -> Prometheus -> Alertmanager -> infra-alertmanager-ntfy -> ntfy -> phone
```

Grafana reads Prometheus directly. Node Exporter exposes host, systemd, and
textfile metrics. The MQTT probe reads retained Mosquitto topics and emits both
MQTT health metrics and conservative PV metrics.

### Local endpoints

| Component                | Endpoint                       | Exposure                   |
| ------------------------ | ------------------------------ | -------------------------- |
| Grafana                  | `https://health.c4rb0n.cloud`  | public HTTPS through Nginx |
| Prometheus               | `http://127.0.0.1:9090`        | loopback only              |
| Alertmanager             | `http://127.0.0.1:9093`        | loopback only              |
| Alertmanager-ntfy bridge | `http://127.0.0.1:9095`        | loopback only              |
| ntfy                     | `https://ntfy.c4rb0n.cloud`    | public HTTPS through Nginx |
| Mosquitto                | `127.0.0.1:1883`               | local broker               |
| Node Exporter            | configured NixOS exporter port | loopback scrape target     |
| Blackbox Exporter        | configured NixOS exporter port | loopback scrape target     |

### Secret keys

Secret values stay in SOPS and out of the Nix store.

| SOPS key                                                | Consumer                  |
| ------------------------------------------------------- | ------------------------- |
| `grafana/secret_key`                                    | Grafana                   |
| `monitoring/mqtt_password`                              | MQTT monitoring probe     |
| `mosquitto/users/monitoring/password_hash`              | Mosquitto monitoring user |
| `ntfy/users/alertmanager/password`                      | Alertmanager-ntfy bridge  |
| `ntfy/users/alertmanager/password_hash`                 | ntfy server               |
| `ntfy/users/mhr/password_hash`                          | ntfy server               |
| `inverter-data-collector/mqtt_password`                 | inverter data collector   |
| `mosquitto/users/inverter-data-collector/password_hash` | Mosquitto collector user  |

### Quick checks

```bash
systemctl status prometheus prometheus-alertmanager grafana infra-alertmanager-ntfy ntfy-sh nginx --no-pager
systemctl status infra-monitoring-metrics.timer infra-monitoring-mqtt.timer infra-monitoring-alert-canary.timer --no-pager
curl --fail --silent --show-error http://127.0.0.1:9090/-/healthy
curl --fail --silent --show-error http://127.0.0.1:9093/-/healthy
curl --fail --silent --show-error http://127.0.0.1:9095/-/healthy
curl --fail --silent --show-error --head https://health.c4rb0n.cloud
curl --fail --silent --show-error --head https://ntfy.c4rb0n.cloud
```

### Logs

```bash
journalctl -u prometheus -u prometheus-alertmanager -u grafana -n 200 --no-pager
journalctl -u infra-alertmanager-ntfy -u ntfy-sh -u nginx -n 200 --no-pager
journalctl -u infra-monitoring-mqtt -u inverter-data-collector -n 200 --no-pager
```

### Alert testing

Use the deterministic test facility rather than breaking a production service.
See [ALERT-TESTING.md](./ALERT-TESTING.md) for manual severity tests, grouping
tests, cleanup, and the scheduled canary.

### Adding alert topics or users

ntfy users, password-hash secret names, topics, and ACLs are declared in the
ntfy module. See `services/ntfy/README.md`. Monitoring publishes as the
`alertmanager` user and does not need additional ntfy privileges unless new
alert topics are added.

### Silences

For planned maintenance, prefer a narrow, expiring Alertmanager silence with a
comment. Avoid permanent inhibition rules unless repeated real alert cascades
justify them.

## Alert delivery with self-hosted ntfy

Alertmanager groups Prometheus alerts by alert name and severity and forwards them
through a local adapter to the self-hosted ntfy service at
`https://ntfy.c4rb0n.cloud`.

The ntfy service owns user and ACL provisioning. Monitoring uses the dedicated
`alertmanager` account and reads its password from this SOPS key:

```text
ntfy/users/alertmanager/password
```

The adapter routes alerts to separate topics by severity:

- `critical` -> `icarus-critical`, urgent phone notification;
- `warning` -> `icarus-warning`, high-priority phone notification;
- `info` -> `icarus-info`, low-priority notification;
- resolved alerts use the same severity topic with normal priority.

Alertmanager repeats unresolved critical alerts hourly and unresolved warning
alerts weekly. Info alerts use a long repeat interval so they do not repeat in
normal operation.

The notification opens the Grafana health dashboard. Credentials are passed
through a systemd credential and do not enter the Nix store. See
`services/ntfy/README.md` for user management, ACLs, phone setup, and manual test
commands.

Useful checks:

```bash
systemctl status prometheus-alertmanager infra-alertmanager-ntfy ntfy-sh
journalctl -u prometheus-alertmanager -u infra-alertmanager-ntfy -u ntfy-sh -n 100
curl --fail --silent --show-error http://127.0.0.1:9095/-/healthy
curl --fail --silent --show-error http://127.0.0.1:9095/metrics
```

The bridge exports Prometheus metrics for notification attempts, failed ntfy
publishes, the last successful publish, and the last scheduled canary publish.
Prometheus scrapes these metrics locally and alerts when the bridge cannot be
scraped, ntfy publishing fails, rule evaluation fails, or the scheduled canary
has not reached ntfy for 84 hours.

If ntfy is unavailable, do not expect a phone notification for the outage.
Use local diagnostics instead:

```bash
systemctl status prometheus prometheus-alertmanager infra-alertmanager-ntfy ntfy-sh nginx --no-pager
journalctl -u prometheus -u prometheus-alertmanager -u infra-alertmanager-ntfy -u ntfy-sh -u nginx -n 200 --no-pager
curl --fail --silent --show-error http://127.0.0.1:9090/-/healthy
curl --fail --silent --show-error http://127.0.0.1:9093/-/healthy
curl --fail --silent --show-error http://127.0.0.1:9095/metrics
curl --fail --silent --show-error --head https://ntfy.c4rb0n.cloud
```

For controlled firing, resolution, severity-routing, and grouping tests, enable
the optional test facility and follow [ALERT-TESTING.md](./ALERT-TESTING.md).

## MQTT health

The monitoring service provisions a dedicated Mosquitto account with access only to
the round-trip topic and the configured read-only health topics. Every minute it:

1. subscribes to the round-trip topic;
2. publishes a unique value and verifies that it is received;
3. samples configured important topics;
4. records topic presence, last observation time, and optional expected-payload health.

The default topic list follows the enabled inverter collector: its retained availability
topic must be `online`, and its state topic must continue producing messages.
For the inverter state topic, the probe also exports PV-specific metrics derived
from the retained JSON payload:

- `infra_pv_inverter_payload_valid`;
- `infra_pv_inverter_status` and `infra_pv_inverter_status_code`;
- `infra_pv_inverter_fault`;
- `infra_pv_ac_power_w` and `infra_pv_dc_power_w`;
- `infra_pv_ac_energy_total_wh`;
- `infra_pv_event_bitmask`;
- `infra_pv_payload_timestamp_seconds`.

Current PV alerts are deliberately conservative and warning-only. They cover
invalid payloads, stale payload timestamps, explicit inverter fault state, and a
decreasing lifetime energy counter. Daylight-aware production checks are a later
stage.

```bash
systemctl start infra-monitoring-mqtt.service
systemctl status infra-monitoring-mqtt.service
cat /var/lib/prometheus-node-exporter-text-files/mqtt.prom
```
