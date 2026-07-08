{
  inputs,
  lib,
  pkgs,
  ...
}: let
  herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  zsh = lib.getExe pkgs.zsh;
  zDotDir =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "$HOME"
    else "$HOME/.config/zsh";
  herdrZsh = pkgs.writeShellScriptBin "herdr-zsh" ''
    export ZDOTDIR="${zDotDir}"
    export SHELL="${zsh}"
    exec "${zsh}" -i "$@"
  '';
in {
  home.packages = [
    herdr
    herdrZsh
  ];

  xdg = {
    enable = true;

    configFile."herdr/config.toml".text = ''
      onboarding = false

      [terminal]
      default_shell = "${lib.getExe herdrZsh}"
      shell_mode = "non_login"
      new_cwd = "follow"

      [keys]
      prefix = "ctrl+a"
      detach = "prefix+q"
      new_tab = "prefix+c"
      close_pane = "prefix+x"
      focus_pane_left = "prefix+h"
      focus_pane_down = "prefix+j"
      focus_pane_up = "prefix+k"
      focus_pane_right = "prefix+l"
      split_vertical = "prefix+minus"
      zoom = "prefix+z"

      [advanced]
      scrollback_limit_bytes = 104857600

      [session]
      resume_agents_on_restore = true
    '';
  };
}
