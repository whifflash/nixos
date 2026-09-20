{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
  darwin = inputs.nix-darwin;

  # macOS hosts (auto-discovered like NixOS, but from ./hosts-darwin)
  hostsDir = ../../hosts-darwin;
  dir = if builtins.pathExists hostsDir then builtins.readDir hostsDir else { };
  hostNames = builtins.attrNames (lib.filterAttrs (_: v: v == "directory") dir);

  systemFor =
    name:
    let
      path = hostsDir + "/${name}/system";
    in
    if builtins.pathExists path then lib.strings.trim (builtins.readFile path) else "aarch64-darwin";

  # Per-host knobs (hosts-darwin/<name>/config.toml) — on macOS the shared layer
  # contributes gopass (CLI wrappers, bridge, SSH askpass), tmux and repo-sync;
  # the Wayland desktop shell is inert there.
  hostConfigFor =
    name:
    let
      f = hostsDir + "/${name}/config.toml";
    in
    inputs.nix-desktop.lib.mkHostConfig {
      raw = if builtins.pathExists f then builtins.fromTOML (builtins.readFile f) else { };
      # nix-labs: on macOS this only adds the `labs` flake-registry entry (no udev).
      extraDefaults.features.labs = false;
    };

  mkHost =
    name:
    let
      hostConfig = hostConfigFor name;
    in
    darwin.lib.darwinSystem {
      system = systemFor name;
      modules = [
        (hostsDir + "/${name}") # the host's ./default.nix

        # nix-labs' overlay first (darwin test fixes for the lab stack —
        # manifold under hardened libc++), then this repo's own disables.
        {
          nixpkgs.overlays = [
            inputs.nix-labs.overlays.default
            (import ../../overlays/disable-tests.nix)
          ];
        }

        ../../modules/darwin/common.nix # shared macOS settings
        ../../modules/darwin/aerospace.nix
        ../../modules/darwin/devtools.nix
        ../../modules/darwin/gopass-picker.nix
        ../../modules/darwin/brews/zed.nix

        # bootstrap Homebrew itself declaratively
        inputs.nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            user = "mhr";
            autoMigrate = true;
          };
        }

        # only try to install brews once CLT exists
        ../../modules/darwin/homebrew.nix

        # Shared lab layer: the `labs` registry entry, so `lab <env>` /
        # `nix develop labs#<env>` resolve to the pinned revision here too.
        inputs.nix-labs.darwinModules.default
        {
          labs = {
            enable = hostConfig.features.labs;
            registry.flake = inputs.nix-labs;
          };
        }

        inputs.home-manager-darwin.darwinModules.home-manager
        (
          { config, ... }:
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = {
                inherit inputs hostConfig;
                osConfig = config;
              };
              sharedModules = [
                inputs.nix-desktop.homeManagerModules.default
                inputs.nix-desktop.homeManagerModules.hostcfg-feed
                # `lab` CLI (list / enter / init / vm) + direnv.
                inputs.nix-labs.homeManagerModules.default
              ];
              users."mhr" = import ../../home/darwin/darwin.nix;
            };
          }
        )
      ];
      # Pass full flake inputs to modules (like we do for NixOS)
      specialArgs = { inherit inputs hostConfig; };
    };
in
{
  flake.darwinConfigurations = lib.genAttrs hostNames mkHost;
}
