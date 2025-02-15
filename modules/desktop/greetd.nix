{ inputs, lib, config, pkgs, ... }:
let 
id = "desktop_greetd";
cfg = config.${id};
in 
{

  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {
    # Enable Display Manager
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --time-format '%I:%M %p | %a • %h | %F' --cmd sway";
          user = "greeter";
        };
      };
    };

    environment.systemPackages = with pkgs; [
    greetd.tuigreet
    ];
  };

}