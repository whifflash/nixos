{
  config,
  pkgs,
  lib,
  ...
}:
let
  user = config.system.primaryUser;

  home =
    let
      h = (config.users.users.${user}.home or null);
    in
    if h == null then "/Users/${user}" else h;

  skhdrc = pkgs.writeText "skhdrc" ''
    cmd - p : /bin/zsh -lc "$HOME/.local/bin/gopass-launcher"
    shift + cmd - p : /bin/zsh -lc "$HOME/.local/bin/gopass-switcher"
  '';

  skhdBin = "/run/current-system/sw/bin/skhd";
in
{
  # Prevent nix-darwin from generating its own org.nixos.skhd service from services.skhd
  services.skhd = {
    enable = lib.mkForce false;
    skhdConfig = lib.mkForce "";
  };

  environment.systemPackages = [
    pkgs.skhd
  ];

  launchd.user.agents.skhd = {
    serviceConfig = {
      ProgramArguments = [
        skhdBin
        "-c"
        (toString skhdrc)
      ];

      RunAtLoad = true;
      KeepAlive = true;

      StandardOutPath = "${home}/Library/Logs/skhd.log";
      StandardErrorPath = "${home}/Library/Logs/skhd.err.log";
    };

    path = [
      pkgs.coreutils
      pkgs.skhd
    ];
  };
}
