{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf;
  cfg = config.hm.theme;

  # Theme registry — extend with more themes as you add them
  palettes = {
    "gruvbox-dark" = import ./palettes/gruvbox-dark.nix {inherit lib;};
    "solarized-dark" = import ./palettes/solarized-dark.nix {inherit lib;};
  };

  # Select palette by name (fallback to gruvbox-dark)
  selected =
    if palettes ? ${cfg.scheme or "gruvbox-dark"}
    then palettes.${cfg.scheme}
    else throw "hm.theme.scheme '${cfg.scheme}' not found. Available: ${lib.concatStringsSep ", " (builtins.attrNames palettes)}";

  tokens = selected.tokens or (throw "Theme '${cfg.scheme}' missing 'tokens' attr.");

  # ── Writers (GTK-friendly) ────────────────────────────────────────────────
  # We generate @define-color names for Waybar/Wofi, derived from tokens.
  gtkPalette = ''
    /* Generated from theme tokens → GTK @define-color for Waybar/Wofi */

    @define-color bg           ${tokens.bg};
    @define-color bg0          ${tokens.bg};        /* alias */
    @define-color bg1          ${tokens.bgAlt};
    @define-color bg2          ${tokens.surface};
    @define-color bg3          ${tokens.surfaceAlt};
    @define-color bgc          ${tokens.overlay};

    @define-color font         ${tokens.fg};
    @define-color light        ${tokens.fg};        /* alias */
    @define-color font_faded   ${tokens.muted};
    @define-color font_darker  ${tokens.bg};        /* for contrast on warning backgrounds */

    @define-color border       ${tokens.border};
    @define-color border_muted ${tokens.borderMuted};

    @define-color primary      ${tokens.primary};
    @define-color secondary    ${tokens.secondary};

    @define-color success      ${tokens.success};
    @define-color warning      ${tokens.warning};
    @define-color critical     ${tokens.error};
    @define-color hint         ${tokens.hint};

    @define-color accent1      ${tokens.accent1};
    @define-color accent2      ${tokens.accent2};
    @define-color accent3      ${tokens.accent3};

    /* convenience alias */
    @define-color bluetint     ${tokens.primary};
  '';

  zshEnv = ''
    # Generated theme tokens for shell / prompts
    export THEME_BG='${tokens.bg}'
    export THEME_BG_ALT='${tokens.bgAlt}'
    export THEME_SURFACE='${tokens.surface}'
    export THEME_SURFACE_ALT='${tokens.surfaceAlt}'
    export THEME_OVERLAY='${tokens.overlay}'

    export THEME_FG='${tokens.fg}'
    export THEME_MUTED='${tokens.muted}'

    export THEME_BORDER='${tokens.border}'
    export THEME_BORDER_MUTED='${tokens.borderMuted}'

    export THEME_PRIMARY='${tokens.primary}'
    export THEME_SECONDARY='${tokens.secondary}'

    export THEME_SUCCESS='${tokens.success}'
    export THEME_WARNING='${tokens.warning}'
    export THEME_ERROR='${tokens.error}'
    export THEME_HINT='${tokens.hint}'

    export THEME_ACCENT1='${tokens.accent1}'
    export THEME_ACCENT2='${tokens.accent2}'
    export THEME_ACCENT3='${tokens.accent3}'
  '';
in {
  options.hm.theme = {
    enable = mkEnableOption "theme tokens and writers";

    scheme = mkOption {
      type = types.str;
      default = "gruvbox-dark";
      description = "Theme name from the registry (e.g., gruvbox-dark, solarized-dark).";
    };

    # Writer toggles
    writeWaybarPalette = mkOption {
      type = types.bool;
      default = true;
      description = "Write ~/.config/waybar/palette.css with GTK @define-color variables.";
    };
    writeWofiPalette = mkOption {
      type = types.bool;
      default = true;
      description = "Write ~/.config/wofi/palette.css with GTK @define-color variables.";
    };
    writeZshEnv = mkOption {
      type = types.bool;
      default = true;
      description = "Write ~/.config/theme/env exporting THEME_* variables.";
    };

    # Only tokens are exported now (no compat layer).
    tokens = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      internal = true;
      description = "Canonical theme tokens (bg, fg, primary, accent1..3, etc.).";
    };

    # Keep 'colors' as an alias to tokens to prevent accidental breakage
    # while you finish migrating; you can remove this option later if you want.
    colors = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      internal = true;
      description = "Alias to hm.theme.tokens for legacy references.";
    };
  };

  config = mkIf cfg.enable {
    hm.theme.tokens = tokens;
    hm.theme.colors = tokens; # alias; no compat names anymore

    xdg.configFile = lib.mkMerge [
      (mkIf cfg.writeWaybarPalette {
        "waybar/palette.css".text = gtkPalette;
      })
      (mkIf cfg.writeWofiPalette {
        "wofi/palette.css".text = gtkPalette;
      })
      (mkIf cfg.writeZshEnv {
        "theme/env".text = zshEnv;
      })
    ];
  };
}
