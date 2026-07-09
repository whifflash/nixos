{
  lib,
  config,
  ...
}: let
  id = "role_workstation";
  cfg = config.${id};
in {
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
          };
        };
      };
    };
  };
}
