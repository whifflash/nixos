# Infrastructure layout

The repository separates **what runs** from **where it runs**:

- `services/` contains reusable NixOS service modules.
- `hosts/` selects services and contains hardware- or machine-specific configuration.
- `inventory/` records current and intended service placement.
- `docs/` contains architecture notes, migrations, and runbooks.

Gitea remains in production on `icarus`, is temporarily enabled on `mia` for bootstrap testing,
and is intended to move to `clio`.
