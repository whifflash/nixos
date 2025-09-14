# modules/ui/theme.nix
{lib, ...}: let
  inherit (lib) mkEnableOption mkIf mkOption types;
in {
  options.ui.theme = {
    scheme = mkOption {
      type = types.str;
      default = "everforest-dark";
      description = "Logical theme name used by the token layer.";
    };

    wallpapersDir = mkOption {
      type = types.path;
      description = "Directory containing wallpapers.";
    };

    wallpaper = mkOption {
      type = types.str;
      description = "Wallpaper filename (relative to wallpapersDir).";
    };

    swaylock.image = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optional explicit swaylock background image.";
    };

    stylix.enable = mkEnableOption "Enable system Stylix integration (image, etc.)";
    qt.enable = mkEnableOption "Enable Qt theming (handled at HM level; leave off unless you add qt6ct/Kvantum)";
  };

  # NOTE: No ui.theme.base16 is defined or assigned here on purpose.
  # Base16 is provided by HM’s token->Stylix bridge.
}
