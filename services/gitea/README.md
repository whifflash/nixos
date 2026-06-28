# Gitea

Reusable native NixOS deployment for `git.<infra.domain>`.

The module provides:

- SQLite for the bootstrap and initial migration
- Nginx TLS termination with DNS-01 ACME
- Gitea's built-in SSH server on TCP port 2222
- daily local `gitea dump` archives under `/var/backup/gitea`
- LFS disabled until there is a concrete need

Host placement is controlled with `infra.services.gitea.enable`. Off-host Restic backup to
Unraid is intentionally not enabled until the repository URL and credentials are defined.
