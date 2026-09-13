# Nix systems

NixOS and nix-darwin configurations for workstations, laptops, and self-hosted infrastructure.

## Repository layout

- `hosts/<host>/`: NixOS host placement and machine-specific configuration; a
  `config.toml` next to `default.nix` holds the desktop knobs (WM switches, theme,
  keyboard, Waybar facts, gopass stores, repo-sync) consumed by the shared layer
- `hosts-darwin/<host>/`: nix-darwin hosts (same optional `config.toml`)
- `flake-modules/`: flake-parts wiring — `nixos/` (auto-discovered `nixosConfigurations`),
  `darwin/` (`darwinConfigurations`), `dev/` (devShell, task app, formatter, checks)
- `services/`: reusable self-hosted service modules
- `modules/`: reusable workstation, role, and platform modules
- `home/`: home-manager — repo-specific apps (firefox, git, ssh, herdr, zsh, …) and `darwin/`
- `docs/`: architecture, migrations, runbooks, and `inventory/services.yaml` (service placement)
- `secrets/`: SOPS-encrypted data only

### The shared desktop layer (`nix-desktop`)

Sway/niri/Waybar/swaync, token theming with a runtime switcher, tmux session
persistence, gopass (store switcher, browser bridge, SSH-passphrase askpass) and
the periodic repository sync (`services.repo-sync`, ex `gitea-sync`) are **not**
in this repo: they come from the flake input `nix-desktop`
(`github:whifflash/nix-desktop`), shared with the work config. Hosts feed it
through `hosts/<host>/config.toml`; the only nix-side values are paths
(`ui.theme.wallpapersDir`, `swaylock.image`). To hack on it, clone it next to
this repo (`../nix-desktop`) — the Taskfile then builds against the checkout
(`task info` shows which) — push there, and `task update-desktop` here.

### The shared lab layer (`nix-labs`)

Lab and development environments — Zephyr per chip family (`zephyr-arm`,
`zephyr-riscv`, `zephyr-esp32`, `zephyr-full`), SDR with the LimeSDR (`sdr`,
`sdr-full`), the Sipeed SLogic logic analyzer (`logic`) and PlatformIO — are
devShells in the flake input `nix-labs` (`github:whifflash/nix-labs`), also
shared with the work config. They are fetched on demand, so they never enter a
host's closure; `[features] labs` in `hosts/<host>/config.toml` only installs the
udev rules for that hardware, the device groups and the `labs` flake-registry
entry pinned to this flake's revision.

```sh
lab list                       # what is available
lab logic                      # enter an environment (= nix develop labs#logic)
lab init zephyr-arm ~/src/blinky && cd ~/src/blinky && direnv allow
lab vm logic                   # QEMU fallback with the USB device redirected in
```

Same dev loop as above: checkout at `../nix-labs`, `task info`, `task update-labs`.
(The old `environments/Platformio/shell.nix` is now `lab platformio`; the SDR half
of `role_hardware-development` is `lab sdr`.)

See `AGENTS.md` for repository conventions.

## Automatic development shell

The repository contains a `.envrc` that loads `devShells.default` from
`flake.nix` through `nix-direnv`. Direnv and nix-direnv are managed by Home
Manager on both NixOS and macOS.

After cloning the repository, approve it once from the repository root:

```sh
direnv allow
```

After that, entering the repository automatically loads the development shell,
and leaving it restores the previous environment. Changes to the flake cause
nix-direnv to refresh the environment. Generated state is stored in `.direnv/`,
which is ignored by Git.

To force a reload after changing `.envrc` or the shell definition:

```sh
direnv reload
```

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
|  2586 |   TCP    | loopback      | ntfy HTTP backend                               |
|  3001 |   TCP    | loopback      | Grafana HTTP backend                            |
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
