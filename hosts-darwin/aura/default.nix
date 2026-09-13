{ pkgs, ... }:
{
  # Set a hostname for this Mac
  networking.hostName = "aura";

  system.defaults.smb.NetBIOSName = "aura";

  # Host-specific overrides go here
  environment.systemPackages = with pkgs; [
    # add per-host tools if you like
  ];

  system.defaults.dock.tilesize = 48;

  # Repository sync (formerly services.giteaSync) is now nix-desktop's
  # repo-sync, configured in ./config.toml [repoSync.gitea]; the token comes
  # from home/apps/repo-sync-token.nix (sops).
}
