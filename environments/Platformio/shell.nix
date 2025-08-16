# https://nixos.wiki/wiki/Platformio
{pkgs ? import <nixpkgs> {}}:
(pkgs.buildFHSUserEnvBubblewrap {
  name = "platformio";
  targetPkgs = pkgs:
    with pkgs; [
      platformio
      (python3.withPackages (p:
        with p; [
          pip
          virtualenv
        ]))
      git
    ];
  services.udev.packages = with pkgs; [platformio-core.udev];
}).env
# { pkgs ? import <nixpkgs> {} }:
# let
# in
#   pkgs.mkShell {
#     buildInputs = [
#       pkgs.platformio
#       # optional: needed as a programmer i.e. for esp32
#       # pkgs.avrdude
#     ];
# }

