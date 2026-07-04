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

## Icarus port registry

Check this table before assigning a port to a new service on Icarus. Keep the table in sync with
service defaults and any host-network containers. Loopback-only ports are reserved locally even
though they are not exposed through the firewall.

|  Port | Protocol | Bind/exposure | Owner and purpose                               |
| ----: | :------: | :------------ | :---------------------------------------------- |
|    22 |   TCP    | LAN           | Primary OpenSSH daemon; key authentication only |
|    80 |   TCP    | LAN           | Nginx HTTP and ACME redirects                   |
|   443 |   TCP    | LAN           | Nginx HTTPS virtual hosts                       |
|  1883 |   TCP    | LAN           | Mosquitto MQTT                                  |
|  2222 |   TCP    | LAN           | Gitea built-in SSH server                       |
|  2223 |   TCP    | LAN           | Paperless scanner-only SFTP daemon              |
|  3000 |   TCP    | loopback      | Gitea HTTP backend                              |
|  3478 |   UDP    | LAN           | UniFi STUN                                      |
|  5432 |   TCP    | loopback      | PostgreSQL                                      |
|  6789 |   TCP    | LAN           | UniFi throughput test                           |
|  8080 |   TCP    | LAN           | UniFi device inform                             |
|  8082 |   TCP    | loopback      | Infrastructure hub backend                      |
|  8086 |   TCP    | loopback      | InfluxDB HTTP API                               |
|  8123 |   TCP    | LAN           | Home Assistant HTTP backend                     |
|  8443 |   TCP    | LAN           | UniFi application HTTPS backend                 |
|  8843 |   TCP    | LAN           | UniFi guest portal HTTPS                        |
|  8880 |   TCP    | LAN           | UniFi guest portal HTTP                         |
| 10001 |   UDP    | LAN           | UniFi discovery                                 |
| 18554 |   TCP    | loopback      | Home Assistant internal service                 |
| 18555 |   TCP    | LAN           | Home Assistant internal service                 |
| 27117 |   TCP    | loopback      | UniFi MongoDB                                   |
| 28981 |   TCP    | loopback      | Paperless-ngx HTTP backend                      |

Ports exposed by host-network containers may change with application upgrades. Confirm the live
state on Icarus when changing those services:

```sh
ss -tlpen
ss -ulpen
```

## nixos-anywhere installation

To install using nixos-anywhere alongside with required keyfiles, do

    rm -rf ./nixos-anywhere-extra-files
    install -d \
      -m 0700 \
      ./nixos-anywhere-extra-files/var/lib/sops-nix

    install \
      -m 0600 \
      "$HOME/.config/sops/age/keys.txt" \
      ./nixos-anywhere-extra-files/var/lib/sops-nix/key.txt

And then run the installation, e.g. for icarus:

    nix run github:nix-community/nixos-anywhere -- \
      --flake '.#icarus' \
      --target-host 'icarus' \
      --build-on remote \
      --copy-host-keys \
      --extra-files ./nixos-anywhere-extra-files
