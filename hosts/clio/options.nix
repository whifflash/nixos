# hosts/clio/options.nix
{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  options.clio = {
    # VM toggle (false by default)
    isVM = mkEnableOption "Build is for Clio's NixOS VM variant";

    # Whether Disko-managed disks are enabled (true for real host)
    enableDisko = mkEnableOption "Enable Disko-managed disks on Clio";
  };
}
