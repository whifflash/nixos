# home/themes/sway-colors.nix
{
  lib,
  config,
  ...
}: let
  T = config.hm.theme.tokens or {};
in {
  wayland.windowManager.sway.config.colors = lib.mkForce {
    focused = {
      border = T.primary or "#5f87ff";
      background = T.surfaceAlt or "#444444";
      text = T.fg or "#ffffff";
      indicator = T.primary or "#5f87ff";
      childBorder = T.primary or "#5f87ff";
    };
    focusedInactive = {
      border = T.border or "#666666";
      background = T.bgAlt or "#333333";
      text = T.muted or "#cccccc";
      indicator = T.borderMuted or "#555555";
      childBorder = T.border or "#666666";
    };
    unfocused = {
      border = T.borderMuted or "#555555";
      background = T.bg or "#222222";
      text = T.muted or "#aaaaaa";
      indicator = T.borderMuted or "#555555";
      childBorder = T.borderMuted or "#555555";
    };
    urgent = {
      border = T.error or "#ff5f5f";
      background = T.error or "#ff5f5f";
      text = T.bg or "#111111";
      indicator = T.error or "#ff5f5f";
      childBorder = T.error or "#ff5f5f";
    };
    placeholder = {
      border = T.borderMuted or "#555555";
      background = T.surface or "#2a2a2a";
      text = T.fg or "#dddddd";
      indicator = T.borderMuted or "#555555";
      childBorder = T.borderMuted or "#555555";
    };
  };
}
