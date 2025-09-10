{
  pkgs,
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
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Image to use for swaylock. If null, falls back to the main wallpaper.";
    };

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

      # tokens -> hex helpers
      T = config.hm.theme.tokens or {};
      get = n: (T.${n} or "#555555");
      strip = s:
        if lib.isString s && lib.hasPrefix "#" s
        then lib.substring 1 6 s
        else s;
      withA = hex: alpha: (strip hex) + alpha;
      C = name: withA (get name) "ff"; # rrggbbaa for swaylock
      # image path to use
      lockImage =
        if cfg.swaylock.image != null
        then cfg.swaylock.image
        else cfg.wallpapersDir + "/${cfg.wallpaper}";
    in {
      assertions = [
        {
          assertion = builtins.pathExists cfg.wallpapersDir;
          message = "sway-theme: wallpapersDir does not exist: ${toString cfg.wallpapersDir}";
        }
        {
          assertion =
            (cfg.perOutput != {})
            || ((builtins.pathExists cfg.wallpapersDir)
              && (builtins.hasAttr cfg.wallpaper (builtins.readDir cfg.wallpapersDir)));
          message = "sway-theme: wallpaper ‘‘${cfg.wallpaper}’’ not found in ${toString cfg.wallpapersDir}";
        }
        {
          assertion = lib.all (o:
            (builtins.pathExists cfg.wallpapersDir)
            && (builtins.hasAttr o.wallpaper (builtins.readDir cfg.wallpapersDir)))
          (lib.attrValues cfg.perOutput);
          message = "sway-theme: one or more perOutput wallpapers were not found in ${toString cfg.wallpapersDir}";
        }
      ];

      # Optional convenience symlink
      home.file = lib.mkIf cfg.linkToPictures {
        "Pictures/wallpapers".source = cfg.wallpapersDir;
      };

      programs.swaylock = {
        enable = lib.mkDefault true;
        package = pkgs.swaylock; # or pkgs.swaylock-effects
        settings = {
          image = toString lockImage;
          scaling = cfg.wallpaperMode; # fill | fit | stretch | tile | center

          # Show indicator and style it with tokens
          # indicator = true;
          indicator-caps-lock = true;

          # Inside (background of the ring)
          inside-color = C "bgAlt";
          inside-ver-color = C "warning";
          inside-wrong-color = C "error";

          # Ring
          ring-color = C "primary";
          ring-ver-color = C "warning";
          ring-wrong-color = C "error";

          # Line + text
          line-color = C "border";
          text-color = C "fg";
          key-hl-color = C "accent1";
          separator-color = C "borderMuted";

          # Optional niceties (uncomment to taste):
          # indicator-radius = 120;
          # indicator-thickness = 10;
          # font = "Sans 12";
          # show-failed-attempts = true;
        };
      };

      # Apply background(s) to Sway outputs
      wayland.windowManager.sway.config.output = outputs;
    }
  ); # end of config
}
