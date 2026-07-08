# modules/darwin/aerospace.nix
{config, ...}: let
  user = config.system.primaryUser;
  home = "/Users/${user}";
in {
  homebrew = {
    enable = true;
    taps = ["nikitabobko/tap"];
    casks = ["nikitabobko/tap/aerospace"];
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "zap";
    };
  };

  # `start-at-login` is handled by AeroSpace after its first successful start.
  # Launch it once per graphical login so a fresh declarative installation also
  # activates the configured global hotkeys.
  launchd.user.agents.aerospace = {
    serviceConfig = {
      ProgramArguments = [
        "/usr/bin/open"
        "-a"
        "AeroSpace"
      ];
      RunAtLoad = true;
      StandardOutPath = "${home}/Library/Logs/aerospace-launch.log";
      StandardErrorPath = "${home}/Library/Logs/aerospace-launch.err.log";
    };
  };
}
