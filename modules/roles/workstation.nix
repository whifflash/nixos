{
  inputs,
  lib,
  config,
  hostname,
  pkgs,
  ...
}:
let
  id = "role_workstation";
  cfg = config.${id};

  # USB-Drive Handling

  usbDrivePkg = pkgs.writeShellApplication {
    name = "usb-drive";
    runtimeInputs = with pkgs; [
      util-linux # lsblk, blkid, wipefs, mount, umount, blkdiscard, findmnt
      parted
      gptfdisk # sgdisk
      cryptsetup
      e2fsprogs # mkfs.ext4
      btrfs-progs # mkfs.btrfs
      coreutils
      gnugrep
      findutils
    ];
    text = builtins.readFile ../../scripts/util/usb-drive.sh;
  };

  # USB UDEV

  # 1) Hook script packaged (unchanged)
  usbDriveUdevHookPkg = pkgs.writeShellApplication {
    name = "usb-drive-udev-hook";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
      usbDrivePkg
    ];
    text = builtins.readFile ../../scripts/udev/usb-drive-udev-hook.sh;
  };

  # 2) Generate the rules TEXT with the hook's absolute path inlined
  usbDriveRules = pkgs.writeText "99-usb-drive.rules" ''
    # USB SATA/SCSI-style partitions (e.g., /dev/sdb1)
    KERNEL=="sd*[0-9]", SUBSYSTEM=="block", ENV{PARTLABEL}=="crypt-*", ACTION=="add",    RUN+="${usbDriveUdevHookPkg}/bin/usb-drive-udev-hook add"
    KERNEL=="sd*[0-9]", SUBSYSTEM=="block", ENV{PARTLABEL}=="crypt-*", ACTION=="remove", RUN+="${usbDriveUdevHookPkg}/bin/usb-drive-udev-hook remove"

    # USB NVMe namespaces (e.g., /dev/nvme0n1p1)
    KERNEL=="nvme*n*p[0-9]", SUBSYSTEM=="block", ENV{PARTLABEL}=="crypt-*", ACTION=="add",    RUN+="${usbDriveUdevHookPkg}/bin/usb-drive-udev-hook add"
    KERNEL=="nvme*n*p[0-9]", SUBSYSTEM=="block", ENV{PARTLABEL}=="crypt-*", ACTION=="remove", RUN+="${usbDriveUdevHookPkg}/bin/usb-drive-udev-hook remove"
  '';

  # 3) Install the rules under /lib/udev/rules.d
  usbDriveUdevPkg = pkgs.stdenvNoCC.mkDerivation {
    pname = "usb-drive-udev";
    version = "1.0";
    dontUnpack = true;
    installPhase = ''
      mkdir -p "$out/lib/udev/rules.d"
      cp ${usbDriveRules} "$out/lib/udev/rules.d/99-usb-drive.rules"
    '';
  };
in
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {
    # Repository syncing (formerly a commented-out gitea-sync service here) is
    # nix-desktop's home-manager `services.repo-sync`, fed from the host's
    # config.toml [repoSync.*]. chromium/gopass-jsonapi moved to home-manager
    # (programs.chromium + the shared gopass module).
    environment.systemPackages =
      (with pkgs; [
        alacritty
        blueman
        code-cursor
        # firefox
        gsimplecal
        joplin
        joplin-desktop
        # jq
        libvlc
        nemo
        neovim
        networkmanagerapplet
        # pcmanfm
        thunderbird
        zed-editor
        udiskie
        vlc
        wireguard-tools
        zip
      ])
      ++ [ usbDrivePkg ];

    hardware.bluetooth.enable = true; # enables support for Bluetooth
    hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot

    fonts.packages = with pkgs; [
      font-awesome
      powerline-fonts
      powerline-symbols
      pkgs.nerd-fonts.symbols-only
      pkgs.nerd-fonts.roboto-mono
    ];

    services = {
      udisks2.enable = true;
      udev.packages = [ usbDriveUdevPkg ];
    };

    systemd.services = {
      NetworkManager-wait-online.enable = false;
      NetworkManager-ensure-env-file = {
        description = "Create NetworkManager env file if it does not exist";
        wantedBy = [ "NetworkManager-ensure-profiles.service" ];
        before = [ "NetworkManager-ensure-profiles.service" ];
        serviceConfig.Type = "oneshot";
        script = ''
          if [ ! -d /etc/secrets ]; then
          mkdir -p /etc/secrets
          chmod 600 /etc/secrets
          fi
          if [ ! -f /etc/secrets/network-manager.env ]; then
          touch /etc/secrets/network-manager.env
          chmod 600 /etc/secrets/network-manager.env
          fi
        '';
      };
    };

    networking = {
      wireguard.enable = true;
      firewall.enable = false;
      networkmanager = {
        enable = true;
        # dns = "systemd-resolved";
        ensureProfiles = {
          environmentFiles = [
            config.sops.secrets."network-manager.env".path
          ];
          profiles = {
            "$LoT_SSID" = {
              connection = {
                id = "$LoT_SSID";
                type = "wifi";
              };
              ipv4 = {
                method = "auto";
              };
              ipv6 = {
                addr-gen-mode = "stable-privacy";
                method = "auto";
              };
              wifi = {
                mode = "infrastructure";
                ssid = "$LoT_SSID";
              };
              wifi-security = {
                key-mgmt = "wpa-psk";
                psk = "$LoT_PSK";
              };
            };

            "$BSP_SSID" = {
              connection = {
                id = "$BSP_SSID";
                type = "wifi";
              };
              ipv4 = {
                method = "auto";
              };
              ipv6 = {
                addr-gen-mode = "stable-privacy";
                method = "auto";
              };
              wifi = {
                mode = "infrastructure";
                ssid = "$BSP_SSID";
              };
              wifi-security = {
                key-mgmt = "wpa-psk";
                psk = "$BSP_PSK";
              };
            };
            vpswg = {
              connection = {
                autoconnect = false;
                id = "$VPS_WG";
                interface-name = "vpswg";
                type = "wireguard";
                # secondaries = "32986ce6-f9e4-37c8-96e1-baccfcc38f1a";
              };
              wireguard = {
                mtu = 1380;
                # The env-var NAME carries the host: $VPS_WG_PRIVATE_KEY_MIA etc.
                private-key = ''"''$VPS_WG_PRIVATE_KEY_${lib.toUpper hostname}"'';
                ListenPort = 51823;
              };
              "wireguard-peer.$VPS_WG_PUBLIC_KEY" = {
                allowed-ips = "10.0.0.0/8;::/0;";
                endpoint = "$VPS_WG:51823";
                # preshared-key = "$VPS_WG_PRESHARED_KEY";
                # preshared-key-flags = 0;
              };
              ipv4 = {
                address1 = ''"''${VPS_WG_IPV4_ADDR_${lib.toUpper hostname}}"'';
                # address1 = "$VPS_WG_IPV4_ADDR_MIA";
                dns = "$VPS_WG_IPV4_DNS";
                method = "manual";
              };
              # ipv6 = {
              #   address1 = "$VPS_WG_IPV6_ADDR";
              #   dns = "$VPS_WG_IPV6_DNS";
              #   method = "manual";
              # };
            };
          };
        };
      };
    };
  };
}
