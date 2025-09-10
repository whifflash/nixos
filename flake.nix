{
  description = "NixOS configuration (flake-parts layout)";

  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-stable";
    nixpkgs = {url = "github:nixos/nixpkgs/nixos-25.05";};
    # unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };

    # Core helper for structuring flakes
    flake-parts.url = "github:hercules-ci/flake-parts";

    # flake-utils.url = "github:numtide/flake-utils";

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

    stylix.url = "github:danth/stylix/release-24.11";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    # disko.url = "github:nix-community/disko";
    # disko.inputs.nixpkgs.follows = "nixpkgs";
    # nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-24.11";
    # nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    # flake-utils,
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
          packages = with pkgs; [
            git
            jq
            alejandra
            shfmt
            nodePackages.prettier
            statix
            deadnix
            pre-commit
            config.treefmt.build.wrapper
            zsh
            oh-my-zsh
            zsh-autosuggestions
            zsh-syntax-highlighting
          ];
          shellHook = ''
                        # Install/refresh the hook every time you enter the shell
                        pre-commit install --install-hooks --overwrite

                         # --- oh-my-zsh-in-devshell setup (isolated, no dotfiles touched) ---
                  export NIX_DEV_ZDOTDIR="$PWD/.nix-dev-zsh"
                  mkdir -p "$NIX_DEV_ZDOTDIR"

                  cat >"$NIX_DEV_ZDOTDIR/.zshrc" <<'EOF_ZSHRC'
            # ---- nix devshell zshrc (generated) ----
            export ZSH="${pkgs.oh-my-zsh}/share/oh-my-zsh"
            ZSH_THEME="robbyrussell"
            plugins=(git)   # <- enables ga, gco, gst, etc.

            # Make sure the dev shell's tools are first on PATH
            # (Nix already sets PATH, this is just a friendly reminder spot.)
            # export PATH="$PATH"

            # Don’t let omz auto-update in ephemeral shells
            DISABLE_AUTO_UPDATE="true"
            DISABLE_UPDATE_PROMPT="true"

            source "$ZSH/oh-my-zsh.sh"
            # ---- end generated ----
            EOF_ZSHRC

                  # Point zsh to our isolated config
                  export ZDOTDIR="$NIX_DEV_ZDOTDIR"

                  # If we're interactive and not already in zsh, hop into it
                  if [ -t 1 ] && [ -z "$IN_NIX_DEV_ZSH" ] ; then
                    export IN_NIX_DEV_ZSH=1
                    exec ${pkgs.zsh}/bin/zsh -i
                  fi
          '';
        };

        pre-commit = {
          # optional: adds a flake check so `nix flake check` runs the hooks
          check.enable = true;

          # this is the correct nesting:
          settings.hooks = {
            # Use treefmt as the single formatter (covers Nix/Shell/Prettier, etc.)
            treefmt = {
              enable = true;
              package = config.treefmt.build.wrapper;
            };

            # Keep linters:
            statix.enable = true;
            deadnix.enable = true;

            # Avoid double-formatting (treefmt already runs Prettier/Shfmt/Alejandra)
            alejandra.enable = false;
            shfmt.enable = false;
            prettier.enable = false;
          };
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
        checks = {
          format = pkgs.runCommand "fmt-check" {} ''
            ${pkgs.alejandra}/bin/alejandra --check ${self}
            touch $out
          '';

          lint = pkgs.runCommand "lint-check" {} ''
            ${pkgs.statix}/bin/statix check ${self}
            ${pkgs.deadnix}/bin/deadnix ${self}
            touch $out
          '';

          ci = pkgs.runCommand "ci-checks" {src = ./.;} ''
            set -e
            cd "$src"
            ${config.treefmt
            .build.wrapper}/bin/treefmt --ci
            ${pkgs.statix}/bin/statix check .
            ${pkgs.deadnix}/bin/deadnix .
            touch $out
          '';
        };
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
                (hostsDir + "/${name}")

                inputs.home-manager.nixosModules.home-manager
                ({config, ...}: {
                  nixpkgs.overlays = [(import ./overlays/disable-tests.nix)];
                  home-manager = {
                    useGlobalPkgs = true;
                    useUserPackages = true;

                    sharedModules = [inputs.stylix.homeManagerModules.stylix];
                    extraSpecialArgs = {
                      inherit inputs;
                      osConfig = config;
                    };
                  };
                })

                # inputs.stylix.nixosModules.stylix
              ];
              # Pass flake inputs to modules
              specialArgs = {inherit inputs;};
            };
        in
          lib.genAttrs hostNames mkHost;
      };
    };
}
