# Nix systems

NixOS and nix-darwin configurations for workstations, laptops, and self-hosted infrastructure.

## Repository layout

- `hosts/`: NixOS host placement and machine-specific configuration
- `hosts-darwin/`: nix-darwin hosts
- `services/`: reusable self-hosted service modules
- `modules/`: reusable workstation, role, and platform modules
- `inventory/`: machine-readable service placement
- `docs/`: architecture, migrations, and runbooks
- `decisions/`: architecture decision records
- `secrets/`: SOPS-encrypted data only

See `AGENTS.md` for repository conventions.

## Common workflow

The flake provides a project-local [Task](https://taskfile.dev/) runner with
[nix-output-monitor](https://github.com/maralorn/nix-output-monitor). No global installation is
required:

```sh
# List tasks
nix run .#task

# Build without activating
nix run .#task -- build

# Activate until reboot
nix run .#task -- test

# Activate permanently
nix run .#task -- switch
```

The host defaults to `hostname -s`. Override it when managing another host:

```sh
nix run .#task -- build HOST=mia
```

After entering `nix develop`, the shorter `task build`, `task test`, and `task switch` commands
are available. Extra arguments can be forwarded after `--`, for example:

```sh
task update -- nixpkgs home-manager stylix
task build -- --print-build-logs
```
