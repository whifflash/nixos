{
  lib,
  config,
  pkgs,
  ...
}:
let
  id = "role_hardware-development";
  cfg = config.${id};
in
{
  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  # Off on every host. The SDR side of this role now lives in the shared lab
  # layer as on-demand devShells — `lab sdr` (gqrx, SDR++, LimeSuite, SoapySDR,
  # urh, inspectrum) and `lab sdr-full` (GNU Radio, SDRangel, SatDump) — with the
  # matching udev rules coming from [features].labs, so nothing SDR needs to sit
  # in the system closure. What is left here is the EDA/RC bench, which has no
  # lab-environment equivalent yet.
  config = lib.mkIf cfg.enable {
    # hardware.hackrf = {
    #   enable = true;
    # };

    environment.systemPackages = with pkgs; [
      kicad
      betaflight-configurator
    ];
  };
}
