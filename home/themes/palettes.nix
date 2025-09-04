{
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf types;
  palettes = import ../lib/palettes.nix;
in {
  options.hm.theme = {
    enable = mkEnableOption "Repo-wide theme palette";

    scheme = mkOption {
      type = types.enum ["gruvbox-dark" "gruvbox-light"];
      default = "gruvbox-dark";
      description = "Pick a palette preset.";
    };

    colors = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      # default = {};
      description = "Computed color map for the selected scheme.";
    };

    writeWaybarPalette = mkOption {
      type = types.bool;
      default = true;
      description = "Write ~/.config/waybar/palette.css with CSS variables.";
    };

    writeWofiPalette = mkOption {
      type = types.bool;
      default = true;
      description = "Write ~/.config/wofi/palette.css with CSS variables.";
    };
  };

  config = mkIf config.hm.theme.enable (
    let
      colors =
        if config.hm.theme.scheme == "gruvbox-dark"
        then palettes.gruvbox.dark
        else palettes.gruvbox.light;
    in {
      hm.theme.colors = colors;

      # Generate :root CSS vars for Waybar (safe: your style.css can @import it)
      xdg.configFile."waybar/palette.css" = lib.mkIf config.hm.theme.writeWaybarPalette {
        text = lib.concatStringsSep "\n" (
          map (name: "@define-color ${name} ${colors.${name}};")
          (builtins.attrNames colors)
        );
      };

      xdg.configFile."wofi/palette.css" = lib.mkIf config.hm.theme.writeWofiPalette {
        text = lib.concatStringsSep "\n" (
          map (name: "@define-color ${name} ${colors.${name}};")
          (builtins.attrNames colors)
        );
      };
    }
  );
}
