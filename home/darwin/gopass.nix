{
  config,
  pkgs,
  lib,
  ...
}:
let
  home = config.home.homeDirectory;
in
{
  # macOS-only gopass extras. The shared nix-desktop gopass module already
  # provides gopass/gnupg, the CLI wrappers, the browser bridge, the SSH askpass
  # and gpg-agent (pinentry_mac by default on Darwin, PASSWORD_STORE_DIR from
  # [gopass].defaultStore); only the macOS picker scripts remain here.
  home = {
    packages = with pkgs; [
      coreutils
      findutils
    ];

    file = {
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
    activation.reloadGpgAgent = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.gnupg}/bin/gpgconf --kill gpg-agent || true
    '';

    # Kept for scripts that read it explicitly; same value the shared module sets.
    sessionVariables.PASSWORD_STORE_DIR = lib.mkDefault "${home}/.password-store";
  };

  # Long cache TTLs (formerly written to ~/.gnupg/gpg-agent.conf by hand; the
  # HM gpg-agent service owns that file now).
  services.gpg-agent = {
    defaultCacheTtl = 21600;
    maxCacheTtl = 21600;
  };
}
