{
  pkgs,
  ...
}: {
  # Set a hostname for this Mac
  networking.hostName = "aura";

  system.defaults.smb.NetBIOSName = "aura";


  # Host-specific overrides go here
  environment.systemPackages = with pkgs; [
    # add per-host tools if you like
  ];

  # Example Dock tweak (host-only)
  system.defaults.dock.tilesize = 48;
}
