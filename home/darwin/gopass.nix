{
  config,
  pkgs,
  lib,
  ...
}: let
  home = config.home.homeDirectory;
in {
  home = {
    packages = with pkgs; [
      gopass
      gnupg
      pinentry_mac
      coreutils
      findutils
    ];

    # Default env for gopass; launcher still auto-picks first store
    sessionVariables = {
      PASSWORD_STORE_DIR = "${home}/.password-store";
    };

    file = {
      # macOS GUI pinentry
      ".gnupg/gpg-agent.conf".text = "pinentry-program ${pkgs.pinentry_mac}/bin/pinentry-mac\n";

      # Install the scripts from the nearby "scripts" folder
      ".local/bin/gopass-switcher" = {
        source = ./scripts/gopass-switcher.sh;
        executable = true;
      };
      ".local/bin/gopass-launcher" = {
        source = ./scripts/gopass-launcher.sh;
        executable = true;
      };
    };

    # Reload agent after switches
    activation.reloadGpgAgent = lib.hm.dag.entryAfter ["writeBoundary"] ''
      ${pkgs.gnupg}/bin/gpgconf --kill gpg-agent || true
    '';
  };
}
