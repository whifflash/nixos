{
  description = "NixOS configuration (flake-parts layout)";

  inputs = {
    nixpkgs = {url = "github:nixos/nixpkgs/nixos-26.05";};
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Darwin hosts use the darwin branch of the same release
    nixpkgs-darwin = {url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";};
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

    # flake-utils.url = "github:numtide/flake-utils";

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

    # firefox-addons.url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
    # firefox-addons.inputs.nixpkgs.follows = "nixpkgs";

    # impermanence.url = "github:nix-community/impermanence";
    # microvm = {
    #   url = "github:astro/microvm.nix";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # nur.url = "github:nix-community/NUR";

    stylix.url = "github:nix-community/stylix/release-26.05";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    stylix-unstable.url = "github:nix-community/stylix";
    stylix-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    disko-unstable.url = "github:nix-community/disko";
    disko-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";

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
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-parts,
    # home-manager,
    # nixos-hardware,
    treefmt-nix,
    git-hooks,
    # sops-nix,
    # disko,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;}
    {
      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];

      imports = [
        treefmt-nix.flakeModule
        git-hooks.flakeModule
      ];

      perSystem = {
        pkgs,
        config,
        ...
      }: {
        ##### Developer UX #####
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            git
            jq
            alejandra
            shfmt
            prettier
            statix
            deadnix
            pre-commit
            config.treefmt.build.wrapper
            ripgrep
            go-task
            nix-output-monitor
            direnv
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

            # Automatically load and unload project environments inside
            # interactive dev-shell zsh sessions, including Herdr panes.
            if command -v direnv >/dev/null 2>&1; then
              eval "$(direnv hook zsh)"
            fi
            # ---- end generated ----
            EOF_ZSHRC

                  # Point zsh to our isolated config
                  export ZDOTDIR="$NIX_DEV_ZDOTDIR"

                  # If this shell was entered through `nix develop`, hop into the
                  # managed zsh. Do not use a TTY/interactivity check here: Herdr
                  # panes do not always expose stdout as a traditional TTY to this
                  # hook, and nix runs shellHook through bash before handing over to
                  # the final interactive shell.
                  #
                  # nix-direnv evaluates dev shells from .envrc; in that path we
                  # must not replace the evaluator with zsh.
                  if [ -z "''${DIRENV_IN_ENVRC:-}" ] && [ -z "''${IN_NIX_DEV_ZSH:-}" ]; then
                    export IN_NIX_DEV_ZSH=1
                    export SHELL=${pkgs.zsh}/bin/zsh
                    exec ${pkgs.zsh}/bin/zsh -i
                  fi
          '';
        };

        # Project-local task runner. This allows commands such as
        # `nix run .#task -- switch` without globally installing Task or nom.
        apps.task = {
          type = "app";

          meta.description = "Run this repository's Taskfile with Go Task and nix-output-monitor.";

          program = "${
            pkgs.writeShellApplication {
              name = "nixos-task";
              runtimeInputs = with pkgs; [
                go-task
                nix-output-monitor
              ];
              text = ''
                exec task "$@"
              '';
            }
          }/bin/nixos-task";
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
        # Auto-discover linux hosts from ./hosts
        nixosConfigurations = let
          inherit (nixpkgs) lib;
          hostsDir = ./hosts;
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

          mkHost = name: let
            useUnstable = name == "luna";
            hostNixpkgs =
              if useUnstable
              then inputs.nixpkgs-unstable
              else inputs.nixpkgs;
            hostInputs =
              inputs
              // {
                nixpkgs = hostNixpkgs;
                disko =
                  if useUnstable
                  then inputs.disko-unstable
                  else inputs.disko;
                home-manager =
                  if useUnstable
                  then inputs.home-manager-unstable
                  else inputs.home-manager;
                sops-nix =
                  if useUnstable
                  then inputs.sops-nix-unstable
                  else inputs.sops-nix;
                stylix =
                  if useUnstable
                  then inputs.stylix-unstable
                  else inputs.stylix;
              };
          in
            hostNixpkgs.lib.nixosSystem {
              system = systemFor name;
              modules = [
                # Your host
                (hostsDir + "/${name}")

                hostInputs.disko.nixosModules.disko
                hostInputs.home-manager.nixosModules.home-manager
                ({config, ...}: {
                  nixpkgs.overlays = [(import ./overlays/disable-tests.nix)];
                  home-manager = {
                    useGlobalPkgs = true;
                    useUserPackages = true;
                    extraSpecialArgs = {
                      inputs = hostInputs;
                      osConfig = config;
                    };
                  };
                })

                # Match the Stylix module to each host's Nixpkgs branch.
                hostInputs.stylix.nixosModules.stylix
              ];
              specialArgs = {
                inputs = hostInputs;
                hostname = name;
              };
            };
        in
          lib.genAttrs hostNames mkHost;

        # macOS hosts (auto-discovered like NixOS, but from ./hosts-darwin)
        darwinConfigurations = let
          inherit (nixpkgs) lib;
          darwin = inputs.nix-darwin;
          hostsDir = ./hosts-darwin;
          dir =
            if builtins.pathExists hostsDir
            then builtins.readDir hostsDir
            else {};
          hostNames = builtins.attrNames (lib.filterAttrs (_: v: v == "directory") dir);

          systemFor = name: let
            path = hostsDir + "/${name}/system";
          in
            if builtins.pathExists path
            then lib.strings.trim (builtins.readFile path)
            else "aarch64-darwin";

          mkHost = name:
            darwin.lib.darwinSystem {
              system = systemFor name;
              modules = [
                (hostsDir + "/${name}") # the host's ./default.nix
                ./modules/darwin/common.nix # shared macOS settings
                ./modules/darwin/aerospace.nix
                ./modules/darwin/devtools.nix
                ./modules/darwin/gopass-picker.nix
                ./modules/darwin/brews/sublime.nix
                ./modules/darwin/gitea-sync.nix

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
                ./modules/darwin/homebrew.nix

                inputs.home-manager-darwin.darwinModules.home-manager
                ({config, ...}: {
                  home-manager = {
                    useGlobalPkgs = true;
                    useUserPackages = true;
                    extraSpecialArgs = {
                      inherit inputs;
                      osConfig = config;
                    };
                    users."mhr" = import ./home/darwin/darwin.nix; # adjust username if needed
                  };
                })
              ];
              # Pass full flake inputs to modules (like you do for NixOS)
              specialArgs = {inherit inputs;};
            };
        in
          lib.genAttrs hostNames mkHost;
      };
    };
}
