# Icarus

Icarus is the Lenovo ThinkCentre home-server host. This configuration intentionally starts with a
small recovery baseline: storage, networking, SSH, and the existing native Gitea service. Add the
remaining home-automation services only after this baseline has booted and remote access has been
verified.

## Observed hardware

The following information was collected from the running Arch Linux installation before the NixOS
reinstall:

| Item                 | Observed value                                                       |
| -------------------- | -------------------------------------------------------------------- |
| Architecture         | `x86_64`                                                             |
| System               | Lenovo ThinkCentre                                                   |
| Processor            | Intel Core i5-6500T, four cores                                      |
| Memory               | 7.6 GiB usable                                                       |
| Installation disk    | `SAMSUNG MZ7TY256HDHP-000L7`                                         |
| Disk serial          | `S307NDAHA17537`                                                     |
| Disk capacity        | 238.5 GiB                                                            |
| Stable disk path     | `/dev/disk/by-id/ata-SAMSUNG_MZ7TY256HDHP-000L7_S307NDAHA17537`      |
| Existing disk layout | 200 MiB EFI partition and an ext4 root partition                     |
| Network interface    | `eno1` under the previous Arch installation                          |
| Previous LAN address | `10.20.31.41`                                                        |
| kexec support        | Present; `/sys/kernel/kexec_loaded` reported `0` before installation |

The Disko configuration destroys and recreates the entire Samsung SSD. It creates a 1 GiB EFI
System Partition and uses the remaining space for an ext4 root filesystem. Compressed RAM swap is
provided by `zramSwap` rather than a disk partition.

Before installation, verify that the stable disk path still resolves to the expected device:

```sh
ssh mhr@10.20.31.41 \
  'readlink -f /dev/disk/by-id/ata-SAMSUNG_MZ7TY256HDHP-000L7_S307NDAHA17537 && \
   lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS'
```

Do not continue unless it resolves to the 238.5 GiB Samsung SSD with serial
`S307NDAHA17537`.

## SSH bootstrap

The `mhr` account accepts this public key:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILf46c7nmSRrmr/6iZ0ozwxSaGyQa9YJjmCXyu3+w/HN mhr@mia
```

Password and keyboard-interactive SSH authentication are disabled. The `mhr` account belongs to
`wheel` and has passwordless sudo during the bootstrap phase. Reconsider passwordless sudo after
the host is stable.

## SOPS and Gitea prerequisite

Gitea depends on secrets from `secrets/infrastructure.yaml`, including Cloudflare and Restic
credentials. This host uses its SSH Ed25519 host key as the SOPS age identity:

```text
/etc/ssh/ssh_host_ed25519_key
```

Run nixos-anywhere with `--copy-host-keys` so the current host key survives the reinstall. Before
installation, confirm that the matching public host key is included as a recipient in `.sops.yaml`
and rekey `secrets/infrastructure.yaml` when necessary. Otherwise `sops-nix` cannot decrypt the
Gitea service secrets after boot.

Inspect the current host key with:

```sh
ssh mhr@10.20.31.41 \
  'sudo ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key'
```

## Pre-install checks

From the repository root:

```sh
nix fmt
nix flake check
nix build .#nixosConfigurations.icarus.config.system.build.toplevel
nix eval --raw .#nixosConfigurations.icarus.pkgs.stdenv.hostPlatform.system
nix eval .#nixosConfigurations.icarus.config.disko.devices
```

The platform evaluation must return `x86_64-linux`.

## Installation

The source Mac does not need to cross-compile the target closure. Build on Icarus while its current
x86_64 Linux installation is still running:

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake '.#icarus' \
  --target-host 'mhr@10.20.31.41' \
  --build-on remote \
  --copy-host-keys
```

The command kexecs into the installer, erases the configured Samsung SSD, installs NixOS, and
reboots. Keep the verified Docker Compose and system-access archives outside Icarus throughout the
installation.

## First-boot validation

```sh
ssh mhr@10.20.31.41
sudo systemctl --failed
sudo systemctl status sshd --no-pager
sudo systemctl status gitea --no-pager
sudo systemctl status nginx --no-pager
sudo systemctl status sops-nix --no-pager
findmnt / /boot
lsblk -f
```

Confirm Gitea over HTTPS and its SSH port only after the previous Gitea state has been restored.
Do not enable Home Assistant, Mosquitto, or InfluxDB until this baseline remains stable across a
reboot.
