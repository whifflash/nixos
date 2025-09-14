# home/themes/stylix-hm-bridge.nix
{
  lib,
  config,
  osConfig,
  pkgs,
  options,
  ...
}: let
  enabled = config.hm.theme.enable or false;

  # Tokens from your token layer -> Base16 for Stylix HM module
  T = config.hm.theme.tokens or {};
  get = n: (T.${n} or "#555555");

  base16 = {
    scheme = "TokenScheme (HM)";
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

  # Host-level toggle for Qt target
  wantQt = osConfig.ui.theme.qt.enable or false;

  # These targets must exist in the Stylix HM module for this to be set.
  hasGtk = lib.hasAttrByPath ["stylix" "targets" "gtk"] options;
  hasQt = lib.hasAttrByPath ["stylix" "targets" "qt"] options;
in {
  config = lib.mkIf enabled (lib.mkMerge [
    {
      stylix = {
        # HM also sees the same scheme (no harm duplicating)
        base16Scheme = base16;

        targets = {
          # GTK is definitely an HM target
          gtk.enable = true;

          # We do NOT let Stylix touch sway/swaylock here—your custom modules handle it.
          sway.enable = false;
          swaylock.enable = false;
        };
      };
    }

    # (lib.mkIf (hasQt && wantQt) {
    #   stylix.targets.qt = {
    #     enable = true;
    #     platform = "qtct";  # Qt control via qt6ct
    #   };

    #   # In case your environment doesn't already export it:
    #   home.sessionVariables.QT_QPA_PLATFORMTHEME = lib.mkDefault "qt6ct";
    #   home.packages = [ pkgs.qt6ct ];
    # })
  ]);
}
