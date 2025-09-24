{ inputs, lib, pkgs, ... }:
{
  imports = [
    ../../modules/nixos/common.nix
  ];

  networking.hostName = "clio";

  # (Optional) any server-specific bits you want here…
  # services.openssh.enable = true;
  # time.timeZone = "Europe/Berlin";
}
