# modules/ui/theme.nix
{lib, ...}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  options.ui.theme = {
    scheme = mkOption {
      type = types.str;
      default = "everforest-dark";
      description = "Logical theme name used by the token layer.";
    };

    # Make these nullable so hosts that don't set them won't explode
    wallpapersDir = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Directory containing wallpapers (nullable: host may omit).";
    };

    wallpaper = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Wallpaper filename relative to wallpapersDir (nullable).";
    };

    swaylock.image = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optional explicit swaylock background image.";
    };

    stylix.enable = mkEnableOption "Enable system Stylix integration (image, etc.)";
    qt.enable = mkEnableOption "Enable Qt theming (handled elsewhere if needed)";
  };
}
