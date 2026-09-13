{ inputs, ... }:
{
  imports = [
    inputs.treefmt-nix.flakeModule
    inputs.git-hooks.flakeModule
  ];

  perSystem =
    {
      pkgs,
      config,
      system,
      ...
    }:
    {
      ##### Developer UX #####
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          git
          jq
          nixfmt
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
          # Install/refresh the git hooks; git-hooks.nix generates the
          # (gitignored) .pre-commit-config.yaml from `pre-commit.settings`.
          ${config.pre-commit.installationScript}

          # --- oh-my-zsh-in-devshell setup (isolated, no dotfiles touched) ---
          export NIX_DEV_ZDOTDIR="$PWD/.nix-dev-zsh"
          mkdir -p "$NIX_DEV_ZDOTDIR"

          cat >"$NIX_DEV_ZDOTDIR/.zshrc" <<'EOF_ZSHRC'
          # ---- nix devshell zshrc (generated) ----
          export ZSH="${pkgs.oh-my-zsh}/share/oh-my-zsh"
          ZSH_THEME="robbyrussell"
          plugins=(git)   # <- enables ga, gco, gst, etc.

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
        # adds a flake check so `nix flake check` runs the hooks
        check.enable = true;

        settings.hooks = {
          # Use treefmt as the single formatter (covers Nix/Shell/Prettier, etc.)
          treefmt = {
            enable = true;
            package = config.treefmt.build.wrapper;
          };

          # Keep linters:
          statix.enable = true;
          deadnix.enable = true;

          # Avoid double-formatting (treefmt already runs nixfmt/shfmt/prettier)
          shfmt.enable = false;
          prettier.enable = false;
        };
      };

      # `nix fmt` will run this formatter;
      formatter = config.treefmt.build.wrapper;

      # treefmt settings (format Nix/Shell/JSON/YAML/Markdown)
      treefmt = {
        projectRootFile = "flake.nix";
        programs = {
          # nixfmt (RFC 166): the same formatter as nix-desktop and the work
          # repo, so shared code never churns on style.
          nixfmt.enable = true; # Nix
          shfmt.enable = true; # Shell
          prettier.enable = true; # JSON/MD/YAML/etc.
        };
      };

      # Lightweight “all-in-one” check you can call in CI:
      #   nix build .#checks.<system>.ci
      # Formatting is checked by treefmt-nix's own `checks.treefmt`. The shared
      # desktop layer's checks (statix/deadnix/eval-smoke on both channels) are
      # re-exported so a contract break in nix-desktop surfaces here too.
      checks = {
        lint = pkgs.runCommand "lint-check" { } ''
          ${pkgs.statix}/bin/statix check ${inputs.self}
          ${pkgs.deadnix}/bin/deadnix ${inputs.self}
          touch $out
        '';

        ci = pkgs.runCommand "ci-checks" { src = ./../..; } ''
          set -e
          cd "$src"
          ${config.treefmt.build.wrapper}/bin/treefmt --ci
          ${pkgs.statix}/bin/statix check .
          ${pkgs.deadnix}/bin/deadnix .
          touch $out
        '';
      }
      // pkgs.lib.mapAttrs' (n: v: pkgs.lib.nameValuePair "nix-desktop-${n}" v) (
        inputs.nix-desktop.checks.${system} or { }
      )
      // pkgs.lib.mapAttrs' (n: v: pkgs.lib.nameValuePair "nix-labs-${n}" v) (
        inputs.nix-labs.checks.${system} or { }
      );
    };
}
