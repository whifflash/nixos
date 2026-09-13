{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  # Auto-discover linux hosts from ./hosts
  hostsDir = ../../hosts;
  dir = if builtins.pathExists hostsDir then builtins.readDir hostsDir else { };
  hostNames = builtins.attrNames (lib.filterAttrs (_: v: v == "directory") dir);

  systemFor =
    name:
    let
      path = hostsDir + "/${name}/system";
    in
    if builtins.pathExists path then lib.strings.trim (builtins.readFile path) else "x86_64-linux";

  # Per-host knobs: hosts/<name>/config.toml, normalised by nix-desktop's shared
  # schema (features, theme, desktop, waybar, gopass, repoSync). A host without
  # a config.toml gets the inert defaults — no WM, no desktop shell, no repo-sync
  # — which is exactly right for headless machines like icarus.
  hostConfigFor =
    name:
    let
      f = hostsDir + "/${name}/config.toml";
    in
    inputs.nix-desktop.lib.mkHostConfig {
      raw = if builtins.pathExists f then builtins.fromTOML (builtins.readFile f) else { };
    };

  mkHost =
    name:
    let
      # Jovian (Steam gaming mode) follows nixos-unstable and has no stable
      # branch, so luna stays on unstable; everything else is nixos-26.05.
      useUnstable = name == "luna";
      hostNixpkgs = if useUnstable then inputs.nixpkgs-unstable else inputs.nixpkgs;
      hostInputs = inputs // {
        nixpkgs = hostNixpkgs;
        disko = if useUnstable then inputs.disko-unstable else inputs.disko;
        home-manager = if useUnstable then inputs.home-manager-unstable else inputs.home-manager;
        sops-nix = if useUnstable then inputs.sops-nix-unstable else inputs.sops-nix;
        stylix = if useUnstable then inputs.stylix-unstable else inputs.stylix;
      };
      hostConfig = hostConfigFor name;
    in
    hostNixpkgs.lib.nixosSystem {
      system = systemFor name;
      modules = [
        # The host
        (hostsDir + "/${name}")

        hostInputs.disko.nixosModules.disko
        hostInputs.home-manager.nixosModules.home-manager
        # Match the Stylix module to each host's Nixpkgs branch.
        hostInputs.stylix.nixosModules.stylix

        # Shared desktop layer: ui.* option interface, sway/niri/wayland-common
        # (self-gating on programs.<wm>.enable) and the config.toml → options feed.
        inputs.nix-desktop.nixosModules.default
        inputs.nix-desktop.nixosModules.hostcfg-feed

        (
          { config, ... }:
          {
            nixpkgs.overlays = [ (import ../../overlays/disable-tests.nix) ];
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = {
                inputs = hostInputs;
                osConfig = config;
                inherit hostConfig;
              };
              # Themes + runtime switcher, sway/niri/waybar/swaync shell, tmux,
              # gopass, repo-sync — and their config.toml → dynamic.* feed.
              sharedModules = [
                inputs.nix-desktop.homeManagerModules.default
                inputs.nix-desktop.homeManagerModules.hostcfg-feed
              ];
            };
          }
        )
      ];
      specialArgs = {
        inputs = hostInputs;
        hostname = name;
        inherit hostConfig;
      };
    };
in
{
  flake.nixosConfigurations = lib.genAttrs hostNames mkHost;
}
