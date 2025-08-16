{
  lib,
  config,
  ...
}: let
  id = "role_tailscale-node";
  cfg = config.${id};
in {
  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {
    services.tailscale.enable = true;

    # environment.systemPackages = with pkgs; [
    # tailscale
    # ];
  };
}
