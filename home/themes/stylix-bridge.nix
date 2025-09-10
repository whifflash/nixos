# home/themes/stylix-bridge.nix
{
  lib,
  pkgs,
  config,
  ...
}: let
  enabled = config.hm.theme.enable or false;

  # Pull semantic tokens from your token layer
  T = config.hm.theme.tokens or {};
  get = n: (T.${n} or "#555555");

  stripHash = s:
    if lib.isString s && lib.hasPrefix "#" s
    then lib.substring 1 6 s
    else s;

  # Build a Base16 *attribute set* (not YAML)
  base16 = {
    scheme = "TokenScheme";
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

  # Only form a wallpaper path when the swayTheme module is enabled
  haveSwayWallpaper =
    (config.hm.swayTheme.enable or false)
    && (config.hm.swayTheme ? wallpapersDir)
    && (config.hm.swayTheme ? wallpaper);

  wallpaperPath =
    if haveSwayWallpaper
    then "${toString config.hm.swayTheme.wallpapersDir}/${config.hm.swayTheme.wallpaper}"
    else null;
in {
  config = lib.mkIf enabled (lib.mkMerge [
    {
      stylix = {
        enable = true;

        # Give Stylix an attrset, not a YAML path
        base16Scheme = base16;

        # Enable HM targets that definitely exist in Stylix

        targets = {
          sway.enable = false;
          gtk.enable = true;
          gnome.enable = false;
          kde.enable = false;
          swaylock.enable = false;
        };
        # targets.gtk.enable = true;

        # You can add other HM targets here if you actually use them:
        # targets.fuzzel.enable = true;
        # targets.waybar.enable = true;
      };
    }

    (lib.mkIf (wallpaperPath != null) {
      stylix.image = wallpaperPath;
    })
  ]);
}
