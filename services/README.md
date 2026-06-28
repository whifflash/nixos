# Shared services

This directory contains host-independent NixOS service modules.

A host imports `../../services` and enables only the services it owns:

```nix
{
  imports = [../../services];
  infra.services.gitea.enable = true;
}
```

Service placement belongs in `hosts/` and `inventory/services.yaml`; service implementation
belongs here.
