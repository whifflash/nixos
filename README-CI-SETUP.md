# CI, devShell, and formatting

This repo uses **flake-parts**, **treefmt-nix**, and **git-hooks.nix**.

- `nix develop` — drops you into a shell with `treefmt`, `statix`, `deadnix`, `jq`, etc. Hooks are auto-installed.
- `nix fmt` or `nix run .#treefmt -- --ci` — formats the repo.
- `nix build .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).ci` — run local checks.
- `sudo nixos-rebuild switch --flake .#<host>` — switch a host.
- Hosts are auto-discovered from `./hosts/<name>`; optionally place a `./hosts/<name>/system` file with `x86_64-linux` or `aarch64-linux`.
