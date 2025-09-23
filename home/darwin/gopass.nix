{ config, pkgs, lib, ... }:

let
  home = config.home.homeDirectory;
in
{
  # Tools the scripts rely on
  home.packages = with pkgs; [
    gopass
    gnupg
    pinentry_mac
    coreutils
    findutils
  ];

  # Default env for gopass; launcher still auto-picks first store
  home.sessionVariables = {
    PASSWORD_STORE_DIR = "${home}/.password-store";
  };

  # macOS GUI pinentry
  home.file.".gnupg/gpg-agent.conf".text =
    "pinentry-program ${pkgs.pinentry_mac}/bin/pinentry-mac\n";

  # Reload agent after switches
  home.activation.reloadGpgAgent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.gnupg}/bin/gpgconf --kill gpg-agent || true
  '';

  # Install the scripts from the nearby "scripts" folder
  home.file.".local/bin/gopass-switcher" = {
    source = ./scripts/gopass-switcher.sh;
    executable = true;
  };
  home.file.".local/bin/gopass-launcher" = {
    source = ./scripts/gopass-launcher.sh;
    executable = true;
  };
}
