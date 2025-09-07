{
  config,
  lib,
  ...
}: let
  cfg = config.hm.swayTheme;

  existsIn = dir: file:
    (builtins.pathExists dir)
    && (builtins.hasAttr file (builtins.readDir dir));
in {
  options.hm.swayTheme = {
    enable = lib.mkEnableOption "Sway theming (wallpaper + mode)";

    wallpapersDir = lib.mkOption {
      type = lib.types.path;
      description = ''
        Directory containing wallpapers (e.g., your repo's media/wallpapers).
      '';
    };

    wallpaper = lib.mkOption {
      type = lib.types.str;
      description = "Wallpaper filename (relative to wallpapersDir).";
    };

    wallpaperMode = lib.mkOption {
      type = lib.types.enum ["fill" "fit" "stretch" "tile" "center"];
      default = "fill";
      description = "Sway background mode.";
    };

    swaylock.image = lib.mkOption {
      type = lib.types.str;
      description = "Background image yto se for swaylock";
    };

    # Optional per-output overrides
    perOutput = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule (_: {
        options = {
          wallpaper = lib.mkOption {
            type = lib.types.str;
            description = "Filename (relative to wallpapersDir) for this output.";
          };
          mode = lib.mkOption {
            type = lib.types.enum ["fill" "fit" "stretch" "tile" "center"];
            default = cfg.wallpaperMode;
            description = "Mode for this output (defaults to global wallpaperMode).";
          };
        };
      }));
      default = {};
      description = "Map of output-name -> { wallpaper, mode }.";
    };

    # Convenience: expose wallpapers under ~/Pictures/wallpapers
    linkToPictures = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Symlink wallpapersDir to ~/Pictures/wallpapers.";
    };
  };

  config = lib.mkIf (cfg.enable && config.wayland.windowManager.sway.enable) (
    let
      baseBg = "${cfg.wallpapersDir}/${cfg.wallpaper} ${cfg.wallpaperMode}";

      perOut =
        lib.mapAttrs (_name: o: {
          bg = "${cfg.wallpapersDir}/${o.wallpaper} ${o.mode}";
        })
        cfg.perOutput;

      outputs =
        if cfg.perOutput != {}
        then perOut
        else {"*" = {bg = baseBg;};};
    in {
      assertions = [
        {
          assertion = builtins.pathExists cfg.wallpapersDir;
          message = "sway-theme: wallpapersDir does not exist: ${toString cfg.wallpapersDir}";
        }
        {
          assertion =
            (cfg.perOutput != {})
            || existsIn cfg.wallpapersDir cfg.wallpaper;
          message = "sway-theme: wallpaper ‘‘${cfg.wallpaper}’’ not found in ${toString cfg.wallpapersDir}";
        }
        {
          assertion =
            lib.all (o: existsIn cfg.wallpapersDir o.wallpaper)
            (lib.attrValues cfg.perOutput);
          message = "sway-theme: one or more perOutput wallpapers were not found in ${toString cfg.wallpapersDir}";
        }
      ];

      # Optional convenience symlink
      home.file = lib.mkIf cfg.linkToPictures {
        "Pictures/wallpapers".source = cfg.wallpapersDir;
      };

      # Apply background(s)
      wayland.windowManager.sway.config.output = outputs;
    }
  );
}
