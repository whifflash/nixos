{ inputs, lib, config, pkgs, ... }:
let 
id = "role_workstation";
cfg = config.${id};
in 
{

  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {

    # Needed for sublime
    nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1w"
    ];

    environment.systemPackages = with pkgs; [
    sublime4
    neovim
    thunderbird
    joplin
    joplin-desktop
    tmux
    alacritty
    firefox
    chromium
    blueberry
    wireguard-tools
    networkmanagerapplet
    ];

    environment.sessionVariables.GTK_THEME = "Adwaita:dark";

    hardware.bluetooth.enable = true; # enables support for Bluetooth
    hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot

    fonts.packages = with pkgs; [
    font-awesome
    powerline-fonts
    powerline-symbols
    (nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
    ];

    programs.gnupg.agent = {
      enable = true;
      pinentryPackage = with pkgs; pinentry-gnome3;
      enableSSHSupport = true;
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
    # firewall = {
    #   logReversePathDrops = true;
    #   # Do not block NetworkManager WireGuard via reverse path filter
    #   # https://nixos.wiki/wiki/WireGuard
    #   extraCommands = ''
    #     ip46tables -t mangle -I nixos-fw-rpfilter -p udp -m udp --sport 51820 -j RETURN
    #     ip46tables -t mangle -I nixos-fw-rpfilter -p udp -m udp --dport 51820 -j RETURN
    #   '';
    #   extraStopCommands = ''
    #     ip46tables -t mangle -D nixos-fw-rpfilter -p udp -m udp --sport 51820 -j RETURN || true
    #     ip46tables -t mangle -D nixos-fw-rpfilter -p udp -m udp --dport 51820 -j RETURN || true
    #   '';
    # };
    # hostName = "mia";
    networkmanager = {
      enable = true;
      ensureProfiles = {
        environmentFiles = [
          # "/run/secrets/network-manager.env"
          # ${config.sops.secrets."network-manager.env".path}
          # "/home/mhr/nm.env"
          config.sops.secrets."network-manager.env".path
          # "/etc/secrets/network-manager.env"
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
          # "$WORK_WG" = {
          #   connection = {
          #     autoconnect = false;
          #     id = "$WORK_WG";
          #     interface-name = "$WORK_WG";
          #     type = "wireguard";
          #     secondaries = "32986ce6-f9e4-37c8-96e1-baccfcc38f1a";
          #   };
          #   wireguard = {
          #     mtu = 1280;
          #     private-key = "$WORK_WG_PRIVATE_KEY";
          #   };
          #   "wireguard-peer.$WORK_WG_PUBLIC_KEY" = {
          #     allowed-ips = "0.0.0.0/0;::/0;";
          #     endpoint = "$WORK_WG:51820";
          #     preshared-key = "$WORK_WG_PRESHARED_KEY";
          #     preshared-key-flags = 0;
          #   };
          #   ipv4 = {
          #     address1 = "$WORK_WG_IPV4_ADDR";
          #     dns = "$WORK_WG_IPV4_DNS";
          #     method = "manual";
          #   };
          #   ipv6 = {
          #     address1 = "$WORK_WG_IPV6_ADDR";
          #     dns = "$WORK_WG_IPV6_DNS";
          #     method = "manual";
          #   };
          # };
          # "$WORK_VPN" = {
          #   connection = {
          #     id = "$WORK_VPN";
          #     type = "vpn";
          #     uuid = "32986ce6-f9e4-37c8-96e1-baccfcc38f1a";
          #   };
          #   ipv4 = {
          #     method = "auto";
          #     never-default = "true";
          #   };
          #   ipv6 = {
          #     addr-gen-mode = "stable-privacy";
          #     method = "auto";
          #     never-default = "true";
          #   };
          #   vpn = {
          #     auth = "SHA512";
          #     ca = "/etc/secrets/bundle.pem";
          #     cert = "/etc/secrets/secret.p12";
          #     cert-pass-flags = "0";
          #     cipher = "AES-256-GCM";
          #     connect-timeout = "1";
          #     connection-type = "tls";
          #     dev = "tun";
          #     key = "/etc/secrets/secret.p12";
          #     remote = "$WORK_CPN:1194:udp, $WOR_VPN:443:tcp";
          #     remote-cert-tls = "server";
          #     service-type = "org.freedesktop.NetworkManager.openvpn";
          #     tls-crypt = "/etc/secrets/WORK_TLS_AUTH_SECRET_2024";
          #   };
          #   vpn-secrets = {
          #     cert-pass = "$WORK_VPN_CERT_PW";
          #   };
          # };
          # "$WORK_GUESTWIFI_SSID" = {
          #   connection = {
          #     id = "$WORK_GUESTWIFI_SSID";
          #     type = "wifi";
          #   };
          #   ipv4 = {
          #     method = "auto";
          #   };
          #   ipv6 = {
          #     addr-gen-mode = "stable-privacy";
          #     method = "auto";
          #   };
          #   wifi = {
          #     mode = "infrastructure";
          #     ssid = "$WORK_GUESTWIFI_SSID";
          #   };
          #   wifi-security = {
          #     key-mgmt = "sae";
          #     psk = "$WORK_GUESTWIFI_PSK";
          #   };
          # };
        };
      };
    };
  };


  };

}
