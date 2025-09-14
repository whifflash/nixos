# modules/ui/stylix-bridge.nix
{
  lib,
  config,
  ...
}: let
  cfg = config.ui.theme;

  # Load palette from your repo
  palettesDir = ../../home/themes/palettes;
  available = builtins.readDir palettesDir;
  nixFiles = builtins.filter (n: lib.hasSuffix ".nix" n) (builtins.attrNames available);
  names = map (n: lib.removeSuffix ".nix" n) nixFiles;

  fileFor = name: let
    p = "${palettesDir}/${name}.nix";
  in
    if builtins.pathExists p
    then p
    else throw "ui.stylix-bridge: palette '${name}' not found. Available: ${lib.concatStringsSep ", " names}";

  palette = import (fileFor cfg.scheme) {};
  T = palette.tokens or {};
  get = n: (T.${n} or "#555555");

  base16 = {
    scheme = palette.name or cfg.scheme;
    author = "whifflash";
    base00 = get "bg";
    base01 = get "bgAlt";
    base02 = get "surface";
    base03 = get "surfaceAlt";
    base04 = get "muted";
    base05 = get "fg";
    base06 = get "fg";
    base07 = get "overlay";
    base08 = get "error";
    base09 = get "accent1";
    base0A = get "warning";
    base0B = get "success";
    base0C = get "hint";
    base0D = get "primary";
    base0E = get "secondary";
    base0F = get "accent3";
  };

  wallpaperPath = "${cfg.wallpapersDir}/${cfg.wallpaper}";
in {
  # System Stylix is the only Stylix we use: feed it scheme + wallpaper.
  config = lib.mkIf (cfg.stylix.enable or true) {
    stylix = {
      enable = true;
      base16Scheme = base16;
      image = wallpaperPath;
    };
  };
}
