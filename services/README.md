# Shared services

This directory contains host-independent NixOS service modules.

A host imports `../../services` and enables only the services it owns:

```nix
{
  imports = [../../services];
  infra.services.gitea.enable = true;
}
```

Current shared infrastructure includes Gitea, the static hub, Mosquitto, InfluxDB,
Paperless-ngx, Home Assistant, UniFi Network Application, the inverter data collector, scheduled host
housekeeping, and the cross-service home-automation backup job.

Service placement belongs in `hosts/` and `inventory/services.yaml`; service implementation
belongs here.
