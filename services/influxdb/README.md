# InfluxDB

Native NixOS InfluxDB 2 deployment for Home Assistant time-series data.

The module provisions:

- organization `bsw`
- bucket `homeassistant`
- administrator credentials from SOPS
- a stable bucket-scoped Home Assistant write token from SOPS
- loopback-only InfluxDB on port `8086`
- HTTPS access through Nginx at `influx.<infra.domain>`

Expected SOPS keys:

```yaml
influxdb:
  admin_password: "..."
  operator_token: "..."
  home_assistant_token: "..."
```

The Home Assistant token must also be present as `influxdb_token` in the
SOPS-managed Home Assistant `secrets.yaml` content. Retain the operator token;
it is required for administration and full logical restores.

Backups use `influx backup`, not a live copy of `/var/lib/influxdb2`.
