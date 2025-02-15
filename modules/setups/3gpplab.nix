{ pkgs, ... }:
{
  virtualisation.docker.enable = true;
  users.users.mhr.extraGroups = [ "docker" ];
  # environment.systemPackages = with pkgs; [
  #   docker
  # ];

}