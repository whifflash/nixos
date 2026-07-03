# Repository guidance

## Architecture

- Put reusable service implementation under `services/`.
- Put service placement and host-specific values under `hosts/<hostname>/`.
- Update `inventory/services.yaml` whenever a service moves.
- Keep persistent-service backup and restore instructions current.
- Do not change `system.stateVersion` during routine upgrades.

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
