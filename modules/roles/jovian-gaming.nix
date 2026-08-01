{
  config,
  inputs,
  lib,
  ...
}: let
  id = "role_jovian_gaming";
  cfg = config.${id};
in {
  imports = [inputs.jovian.nixosModules.default];

  options.${id} = {
    enable = lib.mkEnableOption "Jovian Steam Gaming Mode";

    user = lib.mkOption {
      type = lib.types.str;
      default = "mhr";
      description = "Local user that runs the Jovian Steam session.";
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Boot directly into the Jovian Steam Gaming Mode session.";
    };

    desktopSession = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "sway";
      description = "Display-manager session used by Steam's Switch to Desktop action.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.hasAttr cfg.user config.users.users;
        message = "${id}: user '${cfg.user}' must exist in users.users.";
      }
      {
        assertion = config.networking.networkmanager.enable;
        message = "${id}: Gaming Mode requires networking.networkmanager.enable.";
      }
      {
        assertion = !cfg.autoStart || !config.desktop_sddm.enable;
        message = "${id}: disable desktop_sddm when Jovian autostart owns SDDM.";
      }
      {
        assertion = !cfg.autoStart || cfg.desktopSession != "sway" || config.programs.sway.enable;
        message = "${id}: programs.sway.enable must be true when desktopSession is 'sway'.";
      }
    ];

    jovian.steam =
      {
        enable = true;
        inherit (cfg) autoStart user;
      }
      // lib.optionalAttrs cfg.autoStart {
        inherit (cfg) desktopSession;
      };
  };
}
