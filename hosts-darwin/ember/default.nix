{ pkgs, ... }:
{
  # Set a hostname for this Mac
  networking.hostName = "ember";

  system.defaults.smb.NetBIOSName = "ember";

  # Host-specific overrides go here
  environment.systemPackages = with pkgs; [
    # add per-host tools if you like
  ];

  # Example Dock tweak (host-only)
  system.defaults.dock.tilesize = 48;
}
