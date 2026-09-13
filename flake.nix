{
  description = "NixOS + nix-darwin configurations (flake-parts layout)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Darwin hosts use the darwin branch of the same release
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
      # inputs.nixpkgs.follows = "nixpkgs-darwin"; # follow your Darwin nixpkgs
    };
    aerospace-scratchpad = {
      url = "github:cristianoliveira/aerospace-scratchpad";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # Herdr is not in nixpkgs 26.05 yet. Keep it pinned as its own
    # release flake instead of moving the whole system to unstable.
    herdr.url = "github:ogulcancelik/herdr/v0.7.3";

    # Core helper for structuring flakes
    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager-unstable.url = "github:nix-community/home-manager";
    home-manager-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Optional but handy on real machines; import per-host as needed
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix-unstable.url = "github:Mic92/sops-nix";
    sops-nix-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Tooling
    treefmt-nix.url = "github:numtide/treefmt-nix";
    git-hooks.url = "github:cachix/git-hooks.nix";

    stylix.url = "github:nix-community/stylix/release-26.05";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    stylix-unstable.url = "github:nix-community/stylix";
    stylix-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    disko-unstable.url = "github:nix-community/disko";
    disko-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # Jovian tracks nixos-unstable (no stable branch) — hence luna stays on
    # unstable while every other host is on 26.05 (see flake-modules/nixos).
    jovian.url = "github:Jovian-Experiments/Jovian-NixOS/development";
    jovian.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # nix-darwin (macOS management)
    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    home-manager-darwin = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # Shared desktop layer (sway/niri/waybar/swaync, token theming + runtime
    # switcher, gopass switcher/bridge/SSH-askpass, tmux persistence, repo-sync,
    # config.toml feeds) — the same code the work config uses. Public repo. The
    # Taskfile overrides it to a local checkout (./nix-desktop or ../nix-desktop)
    # when present; `task update-desktop` re-pins to the pushed revision. Its own
    # inputs are only used by its checks; follow ours where the names overlap.
    nix-desktop = {
      url = "github:whifflash/nix-desktop";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-unstable.follows = "nixpkgs-unstable";
        home-manager.follows = "home-manager";
        home-manager-unstable.follows = "home-manager-unstable";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    # Shared lab/dev environments (Zephyr per chip family, SDR/LimeSDR, Sipeed
    # logic analyzer, PlatformIO) as devShells, plus the udev rules for that
    # hardware and the `lab` CLI — the same code the work config uses. Public
    # repo; the Taskfile overrides it to a local checkout when present and
    # `task update-labs` re-pins. Enabling `labs` adds only udev rules, device
    # groups and the `labs` registry entry — the environments stay out of the
    # system closure.
    nix-labs = {
      url = "github:whifflash/nix-labs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      imports = [
        ./flake-modules/dev # devShell, task app, formatter, pre-commit, checks
        ./flake-modules/nixos # nixosConfigurations (auto-discovered from hosts/)
        ./flake-modules/darwin # darwinConfigurations (auto-discovered from hosts-darwin/)
      ];
    };
}
