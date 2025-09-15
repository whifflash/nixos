# home/themes/tokens.nix
{
  lib,
  config,
  osConfig,
  ...
}: let
  cfg = config.hm.theme;

  # Palettes live in home/themes/palettes/*.nix
  palettesDir = let
    p = ./palettes;
  in
    if builtins.pathExists p
    then p
    else throw "hm.theme: palettes directory '${toString p}' does not exist";

  paletteFiles = builtins.readDir palettesDir;
  onlyRegular = lib.filterAttrs (_: v: v == "regular") paletteFiles;
  allNames = builtins.attrNames onlyRegular;
  nixFiles = builtins.filter (n: lib.hasSuffix ".nix" n) allNames;

  importOne = n: import (palettesDir + "/${n}") {};
  imported = lib.listToAttrs (map (n: {
      name = lib.removeSuffix ".nix" n;
      value = importOne n;
    })
    nixFiles);

  validate = name: value:
    if (value ? name) && (value ? tokens) && (value ? raw)
    then value
    else throw "Palette '${name}.nix' must export { name; tokens; raw; }";

  normalized = lib.mapAttrs validate imported;

  # Optional host-level choice: ui.theme.scheme
  hostScheme =
    if (osConfig ? ui) && (osConfig.ui ? theme) && (osConfig.ui.theme ? scheme)
    then osConfig.ui.theme.scheme
    else null;

  chosenName =
    if cfg.scheme != null
    then cfg.scheme
    else if hostScheme != null
    then hostScheme
    else "gruvbox-dark";

  available = builtins.attrNames normalized;

  chosenPalette =
    if builtins.hasAttr chosenName normalized
    then normalized.${chosenName}
    else throw "hm.theme: palette '${chosenName}' not found. Available: ${lib.concatStringsSep ", " available}";

  T = chosenPalette.tokens;

  # ---- Writers --------------------------------------------------------------

  # Waybar & Wofi use GTK CSS -> @define-color entries
  mkGtkPalette = tokens: let
    names = lib.sort (a: b: a < b) (builtins.attrNames tokens);
    lines = map (k: "@define-color ${k} ${tokens.${k}};") names;
  in
    lib.concatStringsSep "\n" lines + "\n";

  # ~/.config/theme/env -> THEME_* exports
  mkEnv = tokens: let
    names = lib.sort (a: b: a < b) (builtins.attrNames tokens);
    lines = map (k: "export THEME_${lib.toUpper k}=${tokens.${k}}") names;
  in
    lib.concatStringsSep "\n" lines + "\n";

  waybarCss = mkGtkPalette T;
  wofiCss = mkGtkPalette T;
  envTxt = mkEnv T;
in {
  #### Options ###############################################################
  options.hm.theme = {
    enable = lib.mkEnableOption "Home-Manager token theming";

    # Palette name (no .nix). If null, uses host ui.theme.scheme or gruvbox-dark.
    scheme = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Palette name to use from home/themes/palettes (without .nix).";
    };

    writeWaybarPalette = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Write ~/.config/waybar/palette.css with @define-color entries.";
    };

    writeWofiPalette = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Write ~/.config/wofi/palette.css with @define-color entries.";
    };

    writeZshEnv = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Write ~/.config/theme/env with THEME_* variables.";
    };

    # Read-only, filled once in config below.
    tokens = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      description = "Resolved semantic tokens from the chosen palette.";
    };

    raw = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      description = "Raw palette colors as provided by the palette file.";
    };
  };

  #### Implementation ########################################################
  config = lib.mkIf cfg.enable {
    # Publish tokens/raw exactly once (works with readOnly).
    hm.theme.tokens = T;
    hm.theme.raw = chosenPalette.raw;

    # Define home.file ONCE; extend with optional attrs so we don't collide.
    home.file =
      {
        ".config/theme/active-scheme".text = "${chosenPalette.name}\n";
        ".config/theme/available-schemes".text =
          lib.concatStringsSep "\n" available + "\n";
      }
      // lib.optionalAttrs cfg.writeWaybarPalette {
        ".config/waybar/palette.css".text = waybarCss;
      }
      // lib.optionalAttrs cfg.writeWofiPalette {
        ".config/wofi/palette.css".text = wofiCss;
      }
      // lib.optionalAttrs cfg.writeZshEnv {
        ".config/theme/env".text = envTxt;
      };
  };
}
