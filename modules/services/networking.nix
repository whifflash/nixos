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
    networking = {
      firewall = {
        logReversePathDrops = true;
        # Do not block NetworkManager WireGuard via reverse path filter
        # https://nixos.wiki/wiki/WireGuard
        extraCommands = ''
        ip46tables -t mangle -I nixos-fw-rpfilter -p udp -m udp --sport 51820 -j RETURN
        ip46tables -t mangle -I nixos-fw-rpfilter -p udp -m udp --dport 51820 -j RETURN
        '';
        extraStopCommands = ''
        ip46tables -t mangle -D nixos-fw-rpfilter -p udp -m udp --sport 51820 -j RETURN || true
        ip46tables -t mangle -D nixos-fw-rpfilter -p udp -m udp --dport 51820 -j RETURN || true
        '';
      };
      networkmanager = {
        enable = true;
        ensureProfiles = {
          environmentFiles = [
          "/run/secrets/network-manager.env"
          "/etc/secrets/network-manager.env"
          ];
          profiles = {
            Argon = {
              connection = {
                id = "Argon";
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
                ssid = "Argon";
              };
              wifi-security = {
                key-mgmt = "sae";
                psk = "$PSK_ARGON";
              };
            };
            # Helium = {
            #   connection = {
            #     id = "Helium";
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
            #     ssid = "Helium";
            #   };
            #   wifi-security = {
            #     key-mgmt = "sae";
            #     psk = "$PSK_HELIUM";
            #   };
            # };
            # Aurum5 = {
            #   connection = {
            #     id = "Aurum5";
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
            #     ssid = "Aurum5";
            #   };
            #   wifi-security = {
            #     key-mgmt = "wpa-psk";
            #     psk = "$PSK_AURUM5";
            #   };
            # };
            # FRITZNEA7580 = {
            #   connection = {
            #     id = "FRITZNEA7580";
            #     type = "wifi";
            #   };
            #   ipv4 = {
            #     method = "auto";
            #   };
            #   ipv6 = {
            #     addr-gen-mode = "default";
            #     method = "auto";
            #   };
            #   wifi = {
            #     mode = "infrastructure";
            #     ssid = "FRITZNEA7580";
            #   };
            #   wifi-security = {
            #     key-mgmt = "wpa-psk";
            #     psk = "$PSK_FRITZNEA7580";
            #   };
            };
            # Troopers = {
            #   connection = {
            #     id = "Troopers";
            #     type = "wifi";
            #   };
            #   ipv4 = {
            #     method = "auto";
            #   };
            #   ipv6 = {
            #     addr-gen-mode = "default";
            #     method = "auto";
            #   };
            #   wifi = {
            #     mode = "infrastructure";
            #     ssid = "Troopers";
            #   };
            #   wifi-security = {
            #     key-mgmt = "wpa-psk";
            #     psk = "$PSK_ERNW_TROOPERS";
            #   };
            # };
            # "vpn-hdg.ernw.de" = {
            #   connection = {
            #     autoconnect = false;
            #     id = "vpn-hdg.ernw.de";
            #     interface-name = "vpn-hdg.ernw.de";
            #     type = "wireguard";
            #     secondaries = "32986ce6-f9e4-37c8-96e1-baccfcc38f1a";
            #   };
            #   wireguard = {
            #     mtu = 1280;
            #     private-key = "$ERNW_VPN_WG_PRIVATE_KEY";
            #   };
            #   "wireguard-peer.9bOFjTd2a4dGqHtkqKEEbVKvZ54EMH4Fwi3TWYj+U1A=" = {
            #     allowed-ips = "0.0.0.0/0;::/0;";
            #     endpoint = "vpn-hdg.ernw.de:51820";
            #     preshared-key = "$ERNW_VPN_WG_PRESHARED_KEY";
            #     preshared-key-flags = 0;
            #   };
            #   ipv4 = {
            #     address1 = "172.18.18.10/32";
            #     dns = "185.144.93.67;185.144.93.91;";
            #     method = "manual";
            #   };
            #   ipv6 = {
            #     address1 = "2a03:a920:1000:1007::a/128";
            #     dns = "2a03:a920:1000:100a:cc8f:4ff:fef5:a0d7;2a03:a920:1000:100a:8072:7fff:fe5e:fb2f;";
            #     method = "manual";
            #   };
            # };
            # "vpn2.ernw.de" = {
            #   connection = {
            #     id = "vpn2.ernw.de";
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
            #     cert = "/etc/secrets/20240618_mortmann.p12";
            #     cert-pass-flags = "0";
            #     cipher = "AES-256-GCM";
            #     connect-timeout = "1";
            #     connection-type = "tls";
            #     dev = "tun";
            #     key = "/etc/secrets/20240618_mortmann.p12";
            #     remote = "vpn2.ernw.de:1194:udp, vpn2.ernw.de:443:tcp";
            #     remote-cert-tls = "server";
            #     service-type = "org.freedesktop.NetworkManager.openvpn";
            #     tls-crypt = "/etc/secrets/ERNW_TLS_AUTH_SECRET_2024";
            #   };
            #   vpn-secrets = {
            #     cert-pass = "$ERNW_VPN2_CERT_PW";
            #   };
            # };
            # hdg-guest = {
            #   connection = {
            #     id = "hdg-guest";
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
            #     ssid = "hdg-guest";
            #   };
            #   wifi-security = {
            #     key-mgmt = "sae";
            #     psk = "$PSK_ERNW_HDG_GUEST";
            #   };
            # };
          };
        };
      };
    };
  }
