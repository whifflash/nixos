# Repository guidance

## Architecture

- Put reusable service implementation under `services/`.
- Put service placement and host-specific values under `hosts/<hostname>/`.
- Update `inventory/services.yaml` whenever a service moves.
- Keep persistent-service backup and restore instructions current.
- Do not change `system.stateVersion` during routine upgrades.

## Shared layers (`nix-desktop`, `nix-labs`)

- Desktop, theming, tmux, gopass and repo-sync code lives in the `nix-desktop` flake input, not
  here. Change it there (local checkout `../nix-desktop` is picked up by the Taskfile), run its
  `nix flake check`, push, then `task update-desktop`.
- Lab/dev environments (Zephyr, SDR, logic analyzer, PlatformIO) live in the `nix-labs` flake
  input as devShells, with the lab hardware's udev rules and the `lab` CLI as modules. Same loop:
  `../nix-labs`, its `nix flake check`, push, `task update-labs`. Do not add lab tooling to
  `environment.systemPackages` here — add an environment there instead.
- Per-host knobs for both layers go in `hosts/<host>/config.toml` (schema: nix-desktop
  `docs/CONFIG-TOML.md`, plus `[features] labs`); only nix paths (`ui.theme.wallpapersDir`, …)
  belong in `default.nix`.
- Do not re-add `hm.theme` / `hm.swayTheme` / `desktop_sway` style modules; use the `ui.*` and
  `dynamic.*` options the shared layer exposes.

## Secrets

- Never commit plaintext credentials, passwords, tokens, or private keys.
- Keep secret values out of the Nix store; use SOPS-managed runtime files instead.

## Nix style and validation

- Treat formatter, Statix, Deadnix, and flake-check warnings as failures; do not knowingly
  introduce warnings.
- Format changes with `nix fmt` and run `nix flake check` before committing.
- Build every affected NixOS or nix-darwin configuration before committing.
- Prefer `inherit (source) name;` over `name = source.name;` when the attribute name is
  unchanged.
- Avoid assigning the same parent attribute multiple times in one attribute set. Group related
  values under a single parent, for example `users = { mutableUsers = ...; users.mhr = ...; };`.
- Do not suppress linter findings unless no clear alternative exists; document any suppression
  next to the affected expression.
- When checks cannot be run, state that explicitly and do not describe the change as lint-clean or
  fully validated.
