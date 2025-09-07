{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf concatStringsSep;

  cfg = config.hm.theme;

  # ---- Theme registry --------------------------------------------------------
  palettes = {
    "gruvbox-dark" = import ./palettes/gruvbox-dark.nix {inherit lib;};
    "solarized-dark" = import ./palettes/solarized-dark.nix {inherit lib;};
  };

  # pick palette by name (fallback to gruvbox-dark)
  selected =
    if palettes ? ${cfg.scheme or "gruvbox-dark"}
    then palettes.${cfg.scheme}
    else throw "hm.theme.scheme '${cfg.scheme}' not found. Available: ${concatStringsSep ", " (builtins.attrNames palettes)}";

  tokens = selected.tokens or (throw "Theme '${cfg.scheme}' missing 'tokens' attr.");

  # ---- Helpers ---------------------------------------------------------------
  addAlpha = color: alpha: let
    sane = (builtins.match "#[0-9a-fA-F]{6}" color) != null;
    a = lib.toUpper alpha;
  in
    if !sane
    then throw "addAlpha: expected #RRGGBB, got '${color}'"
    else if (builtins.match "[0-9A-F]{2}" a) == null
    then throw "addAlpha: expected AA hex for alpha, got '${alpha}'"
    else "${color}${a}";

  # GTK palette for Waybar & Wofi (@define-color), derived from tokens
  gtkPalette = ''
    /* Generated from theme tokens → GTK @define-color for Waybar/Wofi */

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

  # Swaylock config generated from tokens; swaylock wants literal hex (with alpha)
  swaylockConfig = let
    inherit (tokens) bg;
    inherit (tokens) fg;
    inherit (tokens) border;
    inherit (tokens) borderMuted;
    inherit (tokens) overlay;

    inherit (tokens) success;
    inherit (tokens) warning;
    inherit (tokens) error;
    inherit (tokens) primary;
    inherit (tokens) accent1;

    aDD = "DD"; # ~87%
    aAA = "AA"; # ~67%
    a99 = "99"; # ~60%
    a55 = "55"; # ~33%
    a11 = "11"; # ~7%
  in ''
    # Generated from theme tokens

    image=${cfg.swaylock.imageTargetPath}

    effect-blur=${toString cfg.swaylock.blur}x${toString cfg.swaylock.blurSigma}
    scaling=${cfg.swaylock.scaling}
    ${lib.optionalString cfg.swaylock.ignoreEmptyPassword "ignore-empty-password"}

    indicator
    indicator-radius=${toString cfg.swaylock.indicatorRadius}
    indicator-thickness=${toString cfg.swaylock.indicatorThickness}
    ${lib.optionalString cfg.swaylock.showCapsLock "indicator-caps-lock"}
    ${lib.optionalString cfg.swaylock.showClock "clock"}
    timestr=${cfg.swaylock.timestr}
    datestr=${cfg.swaylock.datestr}

    text-color=${fg}
    font=${cfg.swaylock.font}
    font-size=${toString cfg.swaylock.fontSize}

    layout-bg-color=${bg}
    layout-border-color=${border}
    layout-text-color=${fg}

    # Neutral state
    ring-color=${addAlpha overlay aDD}
    line-color=${addAlpha borderMuted a99}
    inside-color=${addAlpha bg a11}
    separator-color=${addAlpha borderMuted a99}

    # Verification (password OK)
    ring-ver-color=${addAlpha success aDD}
    line-ver-color=${addAlpha success a99}
    inside-ver-color=${addAlpha bg a11}
    text-ver-color=${fg}

    # Clear state (e.g., after backspace)
    ring-clear-color=${addAlpha accent1 aDD}
    line-clear-color=${addAlpha accent1 aAA}
    inside-clear-color=${addAlpha bg a11}
    text-clear-color=${fg}

    # Wrong password
    ring-wrong-color=${addAlpha error aDD}
    line-wrong-color=${addAlpha error a55}
    inside-wrong-color=${addAlpha bg a11}
    text-wrong-color=${fg}

    # Caps lock
    ring-caps-lock-color=${addAlpha primary aDD}
    line-caps-lock-color=${addAlpha primary a99}
    inside-caps-lock-color=${addAlpha bg a11}
    text-caps-lock-color=${fg}

    # Highlights
    key-hl-color=${fg}
    bs-hl-color=${warning}
    caps-lock-key-hl-color=${error}
    caps-lock-bs-hl-color=${warning}
  '';

  # Decide which image to use (prefer the one from hm.swayTheme.swaylock.image if present)
  # This lets you set it once in your sway theme module.
  swayThemeImage =
    if lib.hasAttrByPath ["hm" "swayTheme" "swaylock" "image"] config
    then config.hm.swayTheme.swaylock.image
    else null;

  chosenImage =
    if swayThemeImage != null
    then swayThemeImage
    else cfg.swaylock.image;

  # normalize to a source usable by Home Manager:
  # - if it's a Nix path (inside the repo or store), use it directly
  # - if it's an absolute string like "/home/...", make an out-of-store symlink
  # - otherwise, treat it as a relative path (Nix path) as-is
  isAbsStr = s: builtins.isString s && lib.hasPrefix "/" s;

  imageSource =
    if builtins.isPath chosenImage
    then chosenImage
    else if isAbsStr chosenImage
    then config.lib.file.mkOutOfStoreSymlink (toString chosenImage)
    else
      # relative string path evaluated from the module location is uncommon; keep for flexibility
      chosenImage;
in {
  options.hm.theme = {
    enable = mkEnableOption "theme tokens and writers";

    scheme = mkOption {
      type = types.str;
      default = "gruvbox-dark";
      description = "Theme name from the registry (e.g., gruvbox-dark, solarized-dark).";
    };

    # Writers
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

    # Tokens only (no compat)
    tokens = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      internal = true;
      description = "Canonical theme tokens (bg, fg, primary, accent1..3, etc.).";
    };

    # Swaylock sub-options (can be overridden; image defaults to hm.swayTheme.swaylock.image if set)
    swaylock = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Generate ~/.config/swaylock/config and background from tokens.";
      };

      # May be a store path (types.path) or a string. Absolute strings are symlinked out-of-store.
      image = mkOption {
        type = types.oneOf [types.path types.str];
        default = "${config.home.homeDirectory}/nixos/media/wallpapers/village.jpg";
        description = "Image file to use as swaylock background (copied/symlinked).";
      };

      imageTargetPath = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/.config/swaylock/background";
        readOnly = true;
        internal = true;
        description = "Target path referenced by the generated swaylock config.";
      };

      # Cosmetics
      blur = mkOption {
        type = types.int;
        default = 3;
        description = "Gaussian blur radius.";
      };
      blurSigma = mkOption {
        type = types.int;
        default = 5;
        description = "Gaussian blur sigma.";
      };
      scaling = mkOption {
        type = types.str;
        default = "fill";
        description = "Image scaling mode for swaylock.";
      };
      ignoreEmptyPassword = mkOption {
        type = types.bool;
        default = true;
        description = "Ignore empty password.";
      };

      # Indicator & text
      indicatorRadius = mkOption {
        type = types.int;
        default = 120;
      };
      indicatorThickness = mkOption {
        type = types.int;
        default = 20;
      };
      showCapsLock = mkOption {
        type = types.bool;
        default = true;
      };
      showClock = mkOption {
        type = types.bool;
        default = true;
      };
      timestr = mkOption {
        type = types.str;
        default = "%I:%M %p";
      };
      datestr = mkOption {
        type = types.str;
        default = "%B, %d";
      };
      font = mkOption {
        type = types.str;
        default = "RobotoMono Nerd Font";
      };
      fontSize = mkOption {
        type = types.int;
        default = 12;
      };
    };
  };

  config = mkIf cfg.enable {
    # Publish tokens
    hm.theme.tokens = tokens;

    # Write palettes for Waybar and Wofi
    xdg.configFile = lib.mkMerge [
      (mkIf cfg.writeWaybarPalette {"waybar/palette.css".text = gtkPalette;})
      (mkIf cfg.writeWofiPalette {"wofi/palette.css".text = gtkPalette;})
      (mkIf cfg.writeZshEnv {
        "theme/env".text = ''
          # Generated theme tokens for shell / prompts
          export THEME_BG='${tokens.bg}'
          export THEME_BG_ALT='${tokens.bgAlt}'
          export THEME_SURFACE='${tokens.surface}'
          export THEME_SURFACE_ALT='${tokens.surfaceAlt}'
          export THEME_OVERLAY='${tokens.overlay}'

          export THEME_FG='${tokens.fg}'
          export THEME_MUTED='${tokens.muted}'

          export THEME_BORDER="${tokens.border}"
          export THEME_BORDER_MUTED="${tokens.borderMuted}"

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
      })
      # Swaylock: write config + place the image
      (mkIf cfg.swaylock.enable {
        "swaylock/config".text = swaylockConfig;
        "swaylock/background".source = imageSource;
      })
    ];
  };
}
