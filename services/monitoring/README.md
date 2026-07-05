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

## Phase 1 scope

The first implementation contains:

- Prometheus for local metric storage and alert-rule evaluation;
- Grafana with a provisioned Prometheus data source and Icarus dashboard;
- Node Exporter collectors for host, hardware-monitor, systemd, and textfile
  metrics;
- Blackbox Exporter probes for the enabled HTTP services;
- TCP probes for Mosquitto and the inverter's Modbus endpoint;
- repository-specific metrics for backup results, the active NixOS profile, and
  the configured Zigbee coordinator device;
- alert rules for low filesystem space and inodes, memory pressure, high
  temperature, failed systemd units, failed probes, stale or failed backups,
  and missing Zigbee hardware.

The service does not alert on Icarus itself being unreachable. Prometheus,
Grafana, and the dashboard run on Icarus, so they cannot provide an independent
host-down signal. That check belongs on another device in a later deployment.

Grafana currently permits anonymous viewer access because the other service
frontends use publicly reachable hostnames. Administrative access still uses
Grafana's own authentication. Authentication through a shared identity proxy is
not part of phase 1.

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

Phase 1 reads the result and completion time of the existing systemd Restic
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
```

Inspect current Prometheus targets at `http://127.0.0.1:9090/targets` through an
SSH tunnel when troubleshooting. The Prometheus and exporter ports are bound to
loopback and are not opened in the firewall.

## Roadmap

### Maintenance and growth control

This is the next implementation step after phase 1. It should add declarative,
conservative cleanup jobs on Icarus and metrics for their effectiveness:

- Nix store size;
- age and result of the last Nix garbage collection;
- reclaimable and total Nix store paths where practical;
- Podman image count and total image size;
- dangling and unused Podman image count and size;
- age and result of the last container-image prune;
- filesystem space recovered by each cleanup operation;
- configurable retention for old NixOS generations;
- scheduled Nix garbage collection and store optimisation;
- scheduled pruning of container images that are not used by current
  containers.

Cleanup must be implemented before alerts are added for stale Nix and container
artifacts. The monitoring layer should observe a declared maintenance policy,
not substitute for one.

### Phase 2: application-aware health

- Home Assistant API integration as a distinct second-stage implementation;
- unavailable Home Assistant entities;
- Zigbee device freshness using device-specific thresholds;
- Zigbee battery levels and sustained link-quality degradation;
- authenticated MQTT publish/subscribe round-trip latency;
- Mosquitto `$SYS` metrics and important topic freshness;
- inverter MQTT availability and state-topic freshness;
- InfluxDB-specific write and storage metrics;
- service-specific health endpoints and expected-content checks.

The Home Assistant integration requires a dedicated, least-privilege API token
stored through sops-nix. It is intentionally not part of phase 1.

### Phase 3: update and recovery assurance

- age of `flake.lock` and the deployed repository revision;
- scheduled evaluation or build of newer repository revisions;
- newer generation built but not activated;
- running kernel differing from the current system profile;
- Restic repository integrity checks;
- scheduled test restores;
- explicit monitoring of Paperless off-host backup coverage;
- Alertmanager and a selected external notification channel;
- an external Icarus reachability probe hosted on another device.

## Persistent state

Prometheus and Grafana keep local state under their standard NixOS service data
directories. The provisioned dashboard, data source, scrape configuration, and
alert rules are declarative.

Prometheus data is operational telemetry and is not included in the current
backup set. Grafana's provisioned configuration can be reconstructed from this
repository. Any manually created Grafana dashboards or users are mutable state
and should not be relied upon until a backup policy is declared.
