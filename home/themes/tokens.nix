# home/themes/tokens.nix
{
  config,
  lib,
  ...
}: let
  cfg = config.hm.theme;
  palettesDir = ./palettes;
  filesRaw = builtins.readDir palettesDir;

  isPalette = n:
    filesRaw.${n}
    == "regular"
    && (lib.hasSuffix ".nix" n || lib.hasSuffix ".json" n);

  fileNames = builtins.filter isPalette (builtins.attrNames filesRaw);

  loadOne = name: let
    path = palettesDir + ("/" + name);
    base = lib.removeSuffix ".nix" (lib.removeSuffix ".json" name);

    rawVal =
      if lib.hasSuffix ".nix" name
      then import path
      else builtins.fromJSON (builtins.readFile path);

    value =
      if lib.hasSuffix ".nix" name && builtins.isFunction rawVal
      then rawVal {}
      else rawVal;

    normalized =
      if (value ? name) && (value ? tokens) && (value ? raw)
      then value
      else throw "Palette '${name}' must export { name; tokens; raw; }";
  in {inherit base normalized;};

  loaded = map loadOne fileNames;
  palettes = lib.listToAttrs (map (p: {
      name = p.base;
      value = p.normalized;
    })
    loaded);

  has = n: lib.hasAttr n palettes;

  picked =
    if has cfg.scheme
    then palettes.${cfg.scheme}
    else
      throw "hm.theme.scheme='${cfg.scheme}' not found in ${toString palettesDir}. Available: ${
        lib.concatStringsSep ", " (builtins.attrNames palettes)
      }";

  TOK = picked.tokens; # ergonomic aliases
  RAW = picked.raw;
in {
  options.hm.theme = {
    enable = lib.mkEnableOption "Theming tokens";

    scheme = lib.mkOption {
      type = lib.types.str;
      default = "gruvbox-dark";
      description = ''
        Palette basename from ${toString palettesDir} (without extension).
        Available: ${lib.concatStringsSep ", " (builtins.attrNames palettes)}
      '';
    };

    writeWaybarPalette = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    writeWofiPalette = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    writeZshEnv = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    # New: expose tokens + raw
    tokens = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      description = "Semantic token colors for the active scheme.";
    };
    raw = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      description = "Low-level palette (raw colors) for the active scheme.";
    };

    # Back-compat alias if you still reference hm.theme.colors elsewhere:
    colors = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      description = "Alias of hm.theme.tokens (deprecated).";
    };
  };

  config = lib.mkIf cfg.enable {
    # publish
    hm.theme = {
      tokens = TOK;
      raw = RAW;
      colors = TOK; # alias
    };

    xdg.configFile = {
      "waybar/palette.css" = lib.mkIf cfg.writeWaybarPalette {
        text =
          lib.concatStringsSep "\n"
          (map (k: "@define-color ${k} ${TOK.${k}};") (builtins.attrNames TOK));
      };

      "wofi/palette.css" = lib.mkIf cfg.writeWofiPalette {
        text =
          lib.concatStringsSep "\n"
          (map (k: "@define-color ${k} ${TOK.${k}};") (builtins.attrNames TOK));
      };

      # Shell: export COLOR_<TOKEN>=#hex
      "theme/env" = lib.mkIf cfg.writeZshEnv {
        text =
          lib.concatStringsSep "\n"
          (map (k: ''export COLOR_${lib.toUpper k}="${TOK.${k}}"'')
            (builtins.attrNames TOK));
      };
    };
  };
}
