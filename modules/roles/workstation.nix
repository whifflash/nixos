{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  id = "role_workstation";
  cfg = config.${id};

  # Gitea Sync
  gitea_base = "git.c4rb0n.cloud";
  syncUser = "mhr";
  baseUrl = "https://${gitea_base}";
  destDir = "/home/${syncUser}/${gitea_base}";

  giteaSyncScript =
    pkgs.writeShellScript "gitea-sync-user-repos.sh"
    (builtins.readFile ../../scripts/gitea-sync-user-repos.sh);
  envFile = config.sops.templates."gitea.env".path;

  #Util Scripts

  usb-drive = pkgs.writeShellApplication {
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
in {
  imports = [inputs.sops-nix.nixosModules.sops];

  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."gitea/token" = {
      sopsFile = ../../secrets/gitea-token.yaml;
      format = "yaml";
      key = "token";
      owner = syncUser;
      group = "users";
      mode = "0440";
    };

    sops.templates."gitea.env".content = ''
      TOKEN=${config.sops.placeholder."gitea/token"}
    '';

    # Needed for sublime
    nixpkgs.config.permittedInsecurePackages = [
      "openssl-1.1.1w"
    ];

    environment.systemPackages = with pkgs; [
      alacritty
      blueberry
      chromium
      # firefox
      gopass-jsonapi
      gsimplecal
      joplin
      joplin-desktop
      # jq
      libvlc
      nemo
      neovim
      networkmanagerapplet
      # pcmanfm
      sublime4
      thunderbird
      tmux
      udiskie
      vlc
      wireguard-tools
      zip

      usb-drive
    ];

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

      # udev.extraRules = ''
      #   # Auto-open and mount when a USB drive with a PARTLABEL starting with "crypt-" is plugged in
      #   KERNEL=="sd*[0-9]", ENV{ID_BUS}=="usb", ENV{PARTLABEL}=="crypt-*", \
      #     ACTION=="add", RUN+="${pkgs.util-linux}/bin/logger usb-drive: auto-mounting %E{PARTLABEL}", \
      #     RUN+="${pkgs.coreutils}/bin/sleep 1", \
      #     RUN+="${pkgs.usb-drive}/bin/usb-drive mount-luks $env{PARTLABEL#crypt-}"

      #   # Auto-close when removed
      #   KERNEL=="sd*[0-9]", ENV{ID_BUS}=="usb", ENV{PARTLABEL}=="crypt-*", \
      #     ACTION=="remove", RUN+="${pkgs.util-linux}/bin/logger usb-drive: auto-umounting %E{PARTLABEL}", \
      #     RUN+="${pkgs.usb-drive}/bin/usb-drive umount-luks $env{PARTLABEL#crypt-}"
      # '';
    };

    systemd.services = {
      NetworkManager-wait-online.enable = false;
      NetworkManager-ensure-env-file = {
        description = "Create NetworkManager env file if it does not exist";
        wantedBy = ["NetworkManager-ensure-profiles.service"];
        before = ["NetworkManager-ensure-profiles.service"];
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
      gitea-sync = {
        description = "Sync Gitea repos (SSH) visible to PAT";
        after = ["network-online.target"];
        wants = ["network-online.target"];

        preStart = ''
          install -m 700 -d %S/gitea-sync
          ssh-keyscan -T 5 "${gitea_base}" >> %S/gitea-sync/known_hosts 2>/dev/null || true
        '';
        environment = {
          BASE_URL = baseUrl;
          DEST_DIR = destDir;
          LOG_LEVEL = "INFO"; # set to DEBUG for verbose
        };

        serviceConfig = {
          Type = "oneshot";
          User = syncUser;
          Group = "users";
          SyslogIdentifier = "gitea-sync";

          # persistent state dir for known_hosts, counters, etc.
          StateDirectory = "gitea-sync";
          StateDirectoryMode = "0700";

          EnvironmentFile = envFile;
          ExecStart = "${giteaSyncScript}";
          WorkingDirectory = destDir;

          Restart = "on-failure";
          RestartSec = 30;

          # sandboxing
          PrivateTmp = true;
          NoNewPrivileges = true;
          LockPersonality = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          CapabilityBoundingSet = "";
          ProtectSystem = "strict";
          ProtectHome = "read-only";
          ReadWritePaths = [destDir "/var/lib/gitea-sync"];
        };

        # ensure PATH has what we need at unit runtime
        path = [pkgs.git pkgs.jq pkgs.curl pkgs.openssh pkgs.coreutils pkgs.systemd];
      };
    };

    systemd.timers.gitea-sync = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "1h";
        RandomizedDelaySec = "10m";
        Persistent = true;
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
                private-key = ''"''$VPS_WG_PRIVATE_KEY_''${lib.toUpper specialArgs.hostname}"'';
                ListenPort = 51823;
              };
              "wireguard-peer.$VPS_WG_PUBLIC_KEY" = {
                allowed-ips = "10.0.0.0/8;::/0;";
                endpoint = "$VPS_WG:51823";
                # preshared-key = "$VPS_WG_PRESHARED_KEY";
                # preshared-key-flags = 0;
              };
              ipv4 = {
                address1 = ''"''${VPS_WG_IPV4_ADDR_''${lib.toUpper specialArgs.hostname}}"'';
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
