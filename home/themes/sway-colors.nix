# home/themes/sway-colors.nix
{
  lib,
  config,
  ...
}: let
  enabled =
    (config.wayland.windowManager.sway.enable or false)
    && (config.hm.theme.enable or false);
  T = config.hm.theme.tokens;

  # helper with fallbacks
  get = name: T.${name} or "#555555";
in {
  config = lib.mkIf enabled {
    wayland.windowManager.sway.config.colors = {
      focused = {
        border = get "primary";
        background = get "surfaceAlt";
        text = get "fg";
        indicator = get "accent2";
        childBorder = get "primary";
      };
      focusedInactive = {
        border = get "border";
        background = get "surface";
        text = get "muted";
        indicator = get "borderMuted";
        childBorder = get "border";
      };
      unfocused = {
        border = get "borderMuted";
        background = get "bg";
        text = get "muted";
        indicator = get "borderMuted";
        childBorder = get "borderMuted";
      };
      urgent = {
        border = get "error";
        background = get "error";
        text = get "bg";
        indicator = get "error";
        childBorder = get "error";
      };
      placeholder = {
        border = get "borderMuted";
        background = get "surface";
        text = get "fg";
        indicator = get "borderMuted";
        childBorder = get "borderMuted";
      };
    };
  };
}
