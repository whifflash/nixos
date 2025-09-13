# modules/theming/ui-theme.nix
{
  lib,
  pkgs,
  config,
  options,
  ...
}: let
  cfg = config.ui.theme;

  # Map your semantic tokens -> Base16 attrset (for Stylix or other consumers)
  toBase16 = T: {
    scheme = "TokenScheme";
    author = "repo-tokens";
    base00 = T.bg;
    base01 = T.bgAlt;
    base02 = T.surface;
    base03 = T.surfaceAlt;
    base04 = T.muted;
    base05 = T.fg;
    base06 = T.fg;
    base07 = T.overlay;
    base08 = T.error;
    base09 = T.accent1;
    base0A = T.warning;
    base0B = T.success;
    base0C = T.hint;
    base0D = T.primary;
    base0E = T.secondary;
    base0F = T.accent3;
  };

  hasStylix = lib.hasAttrByPath ["stylix"] options;
in {
  #### Options (host-level) ####################################################
  options.ui.theme = {
    enable = lib.mkEnableOption "centralized UI theming for host + HM";

    palettesDir = lib.mkOption {
      type = lib.types.path;
      description = "Directory with palette .nix files exporting { name; tokens; raw; }";
    };

    scheme = lib.mkOption {
      type = lib.types.str;
      default = "gruvbox-dark";
      description = "Name of a palette file without .nix (e.g. gruvbox-dark).";
    };

    wallpapersDir = lib.mkOption {
      type = lib.types.path;
      description = "Directory with wallpapers.";
    };

    wallpaper = lib.mkOption {
      type = lib.types.str;
      description = "Wallpaper filename relative to wallpapersDir.";
    };

    wallpaperMode = lib.mkOption {
      type = lib.types.enum ["fill" "fit" "stretch" "tile" "center"];
      default = "fill";
      description = "Background mode (used by Sway; also passed to consumers).";
    };

    swaylock.image = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional explicit image for swaylock; falls back to wallpaper if null.";
    };

    # Expose computed tokens to HM (read-only)
    tokens = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {};
      description = "Semantic token set derived from the chosen palette.";
    };

    # Optional: drive Stylix at the **system** level (off by default to avoid mixing)
    stylix.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true and Stylix NixOS module is imported, set Stylix from tokens.";
    };

    qt.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true, also enable Stylix Qt target (system-side) with qtct.";
    };
  };

  #### Implementation ##########################################################
  config = lib.mkIf cfg.enable (let
    palettePath = cfg.palettesDir + "/${cfg.scheme}.nix";

    palette =
      if builtins.pathExists palettePath
      then import palettePath {} # must export { name; tokens; raw; }
      else throw "ui.theme: palette not found: ${toString palettePath}";

    inherit (palette) tokens; #tokens = palette.tokens;

    base16 = toBase16 tokens;

    resolvedSwaylock =
      if cfg.swaylock.image != null
      then cfg.swaylock.image
      else "${cfg.wallpapersDir}/${cfg.wallpaper}";
  in
    lib.mkMerge [
      # Guardrails
      {
        assertions = [
          {
            assertion = builtins.pathExists cfg.palettesDir;
            message = "ui.theme.palettesDir does not exist: ${toString cfg.palettesDir}";
          }
          {
            assertion = builtins.pathExists cfg.wallpapersDir;
            message = "ui.theme.wallpapersDir does not exist: ${toString cfg.wallpapersDir}";
          }
          {
            assertion = builtins.hasAttr cfg.wallpaper (builtins.readDir cfg.wallpapersDir);
            message = "ui.theme.wallpaper ‘${cfg.wallpaper}’ not found in ${toString cfg.wallpapersDir}";
          }
        ];

        # Publish tokens + computed values to HM via osConfig
        ui.theme.tokens = tokens;
        # Also re-publish computed swaylock image (handy for HM consumers)
        ui.theme.swaylock.image = resolvedSwaylock;
      }

      # Optional: drive Stylix at the system level (OFF by default)
      # (lib.mkIf (cfg.stylix.enable && hasStylix) {
      #   stylix = {
      #     enable = true;
      #     base16Scheme = base16;
      #     image = "${cfg.wallpapersDir}/${cfg.wallpaper}";

      #     targets.qt = lib.mkIf cfg.qt.enable {
      #       enable = true;
      #       platform = "qtct";
      #     };
      #   };

      #   environment.systemPackages = lib.mkIf cfg.qt.enable [ pkgs.qt6ct ];
      # })
    ]);
}
