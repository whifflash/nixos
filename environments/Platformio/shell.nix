# https://nixos.wiki/wiki/Platformio
{ pkgs ? import <nixpkgs> {} }:
(pkgs.buildFHSUserEnvBubblewrap {  
  name = "platformio";
  targetPkgs = (pkgs: with pkgs; [  
    (python3.withPackages (p: with p; [  
        pip  
        virtualenv
      ]))
    git
  ]);  
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
