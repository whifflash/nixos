{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf;
  cfg = config.hm.theme;

  # Theme registry — extend with more themes
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

  # ── Compatibility layer ────────────────────────────────────────────────────
  compat = {
    dark0 = tokens.bg;
    dark1 = tokens.bgAlt;
    dark2 = tokens.surface;
    dark3 = tokens.surfaceAlt;
    dark4 = tokens.overlay;

    light0 = tokens.fg;
    light1 = tokens.fg;
    light2 = tokens.muted;
    light3 = tokens.muted;
    light4 = tokens.borderMuted;

    neutral_red = tokens.error;
    neutral_green = tokens.success;
    neutral_yellow = tokens.warning;
    neutral_blue = tokens.primary;
    neutral_purple = tokens.secondary;
    neutral_aqua = tokens.hint;
    neutral_orange = tokens.accent1;

    gray = tokens.borderMuted;
    accent = tokens.accent1;

    # Bright aliases → sensible mappings
    bright_blue = tokens.primary;
    bright_red = tokens.error;
    bright_yellow = tokens.warning;
    bright_green = tokens.success;
    bright_purple = tokens.secondary;
    bright_aqua = tokens.hint;
    bright_orange = tokens.accent1;
  };

  mergedColors = tokens // compat;

  # ── Writers ────────────────────────────────────────────────────────────────
  gtkPalette = ''
    /* Generated: theme tokens → GTK @define-color for Waybar/Wofi */

    @define-color bg           ${tokens.bg};
    @define-color bg0          ${tokens.bg};
    @define-color bg1          ${tokens.bgAlt};
    @define-color bg2          ${tokens.surface};
    @define-color bg3          ${tokens.surfaceAlt};
    @define-color bgc          ${tokens.overlay};

    @define-color font         ${tokens.fg};
    @define-color light        ${tokens.fg};
    @define-color font_faded   ${tokens.muted};
    @define-color font_darker  ${tokens.bg};

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

    tokens = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      internal = true;
      description = "Canonical theme tokens (bg, fg, primary, accent1..3, etc.).";
    };

    colors = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      internal = true;
      description = "Resolved theme colors (tokens + compatibility names).";
    };
  };

  config = mkIf cfg.enable {
    hm.theme.tokens = tokens;
    hm.theme.colors = mergedColors;

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
