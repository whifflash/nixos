{pkgs, ...}: {
  # Set a hostname for this Mac
  networking.hostName = "aura";

  system.defaults.smb.NetBIOSName = "aura";

  # Host-specific overrides go here
  environment.systemPackages = with pkgs; [
    # add per-host tools if you like
  ];

  system.defaults.dock.tilesize = 48;

    services.giteaSync = {
    enable = true;
    debug = true;

    baseUrl = "https://git.c4rb0n.cloud";
    # giteaHost = "git.c4rb0n.cloud";

    # pick where you want repos to land
    destDir = "/Users/mhr/git/git.c4rb0n.cloud";

    startIntervalSec = 3600;
    # randomizedDelaySec = 600;
    randomizedDelaySec = 0;

    # token handling depends on your module; see below
    # envFile = "/Users/mhr/.config/secrets/gitea.env";
  };
}
