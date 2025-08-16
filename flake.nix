{
  description = "NixOS configuration (flake-parts layout)";

  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-stable";
    nixpkgs = {url = "github:nixos/nixpkgs/nixos-25.05";};
    # unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };

    # Core helper for structuring flakes
    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Optional but handy on real machines; import per-host as needed
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Tooling
    treefmt-nix.url = "github:numtide/treefmt-nix";
    git-hooks.url = "github:cachix/git-hooks.nix";

    # firefox-addons.url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
    # firefox-addons.inputs.nixpkgs.follows = "nixpkgs";

    # impermanence.url = "github:nix-community/impermanence";
    # microvm = {
    #   url = "github:astro/microvm.nix";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # nur.url = "github:nix-community/NUR";

    # stylix.url = "github:danth/stylix/release-24.11";
    # stylix.inputs.nixpkgs.follows = "nixpkgs";
    # disko.url = "github:nix-community/disko";
    # disko.inputs.nixpkgs.follows = "nixpkgs";
    # nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-24.11";
    # nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    # self,
    nixpkgs,
    flake-parts,
    home-manager,
    # nixos-hardware,
    treefmt-nix,
    git-hooks,
    # sops-nix,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;}
    {
      # Add more if you build for Darwin/etc.
      systems = ["x86_64-linux" "aarch64-linux"];

      # Bring in ready-made modules
      imports = [
        treefmt-nix.flakeModule
        git-hooks.flakeModule
      ];

      perSystem = {
        pkgs,
        config,
        # system,
        # lib,
        ...
      }: {
        ##### Developer UX #####
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.jq
            pkgs.alejandra
            pkgs.shfmt
            pkgs.nodePackages.prettier
            pkgs.statix
            pkgs.deadnix
            pkgs.pre-commit
            config.treefmt.build.wrapper # provides `treefmt`
          ];
          # Install pre-commit hooks automatically when you `nix develop`
          shellHook = ''
            ${pkgs.bash}/bin/bash ./scripts/install-precommit-delegator.sh
          '';
        };

        # `nix fmt` will run this formatter;
        formatter = config.treefmt.build.wrapper;

        # treefmt settings (format Nix/Shell/JSON/YAML/Markdown)
        treefmt = {
          projectRootFile = "flake.nix";
          # flakeCheck = false;
          programs = {
            alejandra.enable = true; # Nix
            shfmt.enable = true; # Shell
            prettier.enable = true; # JSON/MD/YAML/etc.
          };
        };

        # Lightweight “all-in-one” check you can call in CI:
        #   nix build .#checks.<system>.ci
        checks.ci = pkgs.runCommand "ci-checks" {src = ./.;} ''
          set -e
          cd "$src"
          ${config.treefmt.build.wrapper}/bin/treefmt --ci
          ${pkgs.statix}/bin/statix check .
          ${pkgs.deadnix}/bin/deadnix .
          touch $out
        '';
      };

      ##### System-wide (cross-system) outputs #####

      flake = {
        # Auto-discover hosts from ./hosts
        nixosConfigurations = let
          inherit (nixpkgs) lib;
          # lib = nixpkgs.lib;
          hostsDir = ./hosts;
          # dir = builtins.readDir hostsDir;
          dir =
            if builtins.pathExists hostsDir
            then builtins.readDir hostsDir
            else {};
          hostNames =
            builtins.attrNames (lib.filterAttrs (_: v: v == "directory") dir);

          systemFor = name: let
            path = hostsDir + "/${name}/system";
          in
            if builtins.pathExists path
            then lib.strings.trim (builtins.readFile path)
            else "x86_64-linux";

          mkHost = name:
            lib.nixosSystem {
              system = systemFor name;
              modules = [
                # Either a directory with default.nix or a single file — both work
                (hostsDir + "/${name}")
                home-manager.nixosModules.home-manager
                {
                  # Keep HM pkgs in sync with the system’s pkgs
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                }
              ];
              # Pass flake inputs to modules (useful inside your modules)
              specialArgs = {inherit inputs;};
            };
        in
          lib.genAttrs hostNames mkHost;

        # (Optional) expose a `treefmt` app explicitly for `nix run .#treefmt`
        # apps = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: let
        #   pkgs = import nixpkgs { inherit system; };
        #   # Note: the real wrapper lives under perSystem; this is a convenience shim
        # in {
        #   treefmt = {
        #     type = "app";
        #     program = "${(import ./. { inherit system; }).formatter}/bin/treefmt";
        #   };
        # });
      };
    };
}
# nixosConfigurations.nixbox = nixpkgs.lib.nixosSystem {
#   specialArgs = {
#     inherit inputs;
#     hostname = "nixbox";
#     wm = "sway";
#     user = "mhr";
#   };
#   system = "x86_64-linux";
#   modules = [
#   ./hosts/decafbad-vm/configuration.nix
#   ./modules/modules.nix
#   sops-nix.nixosModules.sops
#   ];
# };
# nixosConfigurations.mia = nixpkgs.lib.nixosSystem {
#   specialArgs = {
#     inherit inputs;
#     hostname = "mia";
#     wm = "sway";
#     user = "mhr";
#   };
#   system = "x86_64-linux";
#   modules = [
#   ./hosts/mia/configuration.nix
#   ./modules/modules.nix
#   inputs.sops-nix.nixosModules.sops
#   inputs.home-manager.nixosModules.home-manager
#   {
#         home-manager.useGlobalPkgs = true;
#         home-manager.useUserPackages = true;
#         home-manager.users.mhr = import ./home/home.nix;
#         home-manager.extraSpecialArgs = {
#         inherit inputs;
#         };
#   }
#   ];
# };
# nixosConfigurations.nixboxmia = nixpkgs.lib.nixosSystem {
#   specialArgs = {
#     inherit inputs;
#     hostname = "mianixbox";
#     wm = "sway";
#     user = "mhr";
#   };
#   system = "x86_64-linux";
#   modules = [
#   ./hosts/mia-nixbox/configuration.nix
#   ./modules/modules.nix
#   inputs.home-manager.nixosModules.default
#   ];
# };
# nixosConfigurations.luna = nixpkgs.lib.nixosSystem {
#   specialArgs = {
#     inherit inputs;
#     hostname = "luna";
#     wm = "sway";
#     user = "mhr";
#   };
#   system = "x86_64-linux";
#   modules = [
#   ./hosts/luna/configuration.nix
#   ./modules/modules.nix
#   inputs.sops-nix.nixosModules.sops
#   inputs.home-manager.nixosModules.home-manager
#   {
#         home-manager.useGlobalPkgs = true;
#         home-manager.useUserPackages = true;
#         home-manager.users.mhr = import ./home/home.nix;
#         home-manager.extraSpecialArgs = {
#         inherit inputs;
#         };
#   }
#   ];
# };

