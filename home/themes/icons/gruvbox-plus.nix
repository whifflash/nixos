{pkgs}:
pkgs.stdenv.mkDerivation {
  name = "gruvbox-plus";
  src = pkgs.fetchurl {
    url = "https://github.com/SylEleuth/gruvbox-plus-icon-pack/releases/download/v6.1.1/gruvbox-plus-icon-pack-6.1.1.zip";
    sha256 = "sha256-JsZwrqtyAF5+140U6/6PcKq4SM/4QyiR8da7yKh/CJI=";
  };

  dontUnpack = true;
  installPhase = ''
    mkdir -p $out
    ${pkgs.unzip}/bin/unzip $src -d $out/
  '';
}
# { pkgs }:
# let
#   imgLink = "https://YOURIMAGELINK/image.png";
#   image = pkgs.fetchurl {
#     url = imgLink;
#     sha256 = "sha256-HrcYriKliK2QN02/2vFK/osFjTT1NamhGKik3tozGU0=";
#   };
# in
# pkgs.stdenv.mkDerivation {
#   name = "sddm-theme";
#   src = pkgs.fetchFromGitHub {
#     owner = "MarianArlt";
#     repo = "sddm-sugar-dark";
#     rev = "ceb2c455663429be03ba62d9f898c571650ef7fe";
#     sha256 = "0153z1kylbhc9d12nxy9vpn0spxgrhgy36wy37pk6ysq7akaqlvy";
#   };
#   installPhase = ''
#     mkdir -p $out
#     cp -R ./* $out/
#     cd $out/
#     rm Background.jpg
#     cp -r ${image} $out/Background.jpg
#    '';
# }

