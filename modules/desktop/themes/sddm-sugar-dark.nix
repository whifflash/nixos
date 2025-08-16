{pkgs}: let
  image = pkgs.copyPathToStore ./login-background.jpg;
in
  pkgs.stdenv.mkDerivation {
    name = "sddm-sugar-dark-theme";
    src = pkgs.fetchFromGitHub {
      owner = "MarianArlt";
      repo = "sddm-sugar-dark";
      rev = "ceb2c455663429be03ba62d9f898c571650ef7fe";
      sha256 = "0153z1kylbhc9d12nxy9vpn0spxgrhgy36wy37pk6ysq7akaqlvy";
    };
    installPhase = ''
      mkdir -p $out
      cp -R ./* $out/
      cd $out/
      sed -i "s/^Locale=.*/Locale=en/g" $out/theme.conf
      sed -i "s/^HeaderText=Welcome!/HeaderText=/g" $out/theme.conf
      sed -i "169s/Font.Capitalize/Font.MixedCase/" $out/Components/Input.qml
      rm Background.jpg
      cp -r ${image} $out/Background.jpg
    '';
  }
