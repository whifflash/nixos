# Gitea bootstrap on Mia

## Before the first build

The shared Cloudflare secret was renamed from `secrets/clio.yaml` to
`secrets/infrastructure.yaml`. Its SOPS policy now includes both the primary and Clio age
recipients, but the encrypted file metadata must be refreshed from a machine that can decrypt
the existing file:

```sh
sops updatekeys secrets/infrastructure.yaml
```

Verify that Mia's configured age key can decrypt it:

```sh
sops -d secrets/infrastructure.yaml >/dev/null
```

The decrypted `cloudflare.env` value must use environment names understood by the NixOS ACME
client's Cloudflare provider. Prefer a scoped token exposed as `CF_DNS_API_TOKEN=...`.

Keep network-wide LAN DNS pointed at the existing production instance during rehearsal. On a
single test client, temporarily override `git.c4rb0n.cloud` to Mia's LAN address (for example in
`/etc/hosts`). DNS-01 certificate issuance does not require the service hostname to point at Mia.

## Build and activate

```sh
nix build .#nixosConfigurations.mia.config.system.build.toplevel
sudo nixos-rebuild test --flake .#mia
```

Inspect the services before switching permanently:

```sh
systemctl status gitea nginx acme-git.c4rb0n.cloud.service
journalctl -u gitea -u nginx -u acme-git.c4rb0n.cloud.service
```

After validation:

```sh
sudo nixos-rebuild switch --flake .#mia
```

The bootstrap instance uses SQLite, has LFS disabled, temporarily permits account
registration for bootstrap testing, listens on HTTPS through Nginx, and exposes Gitea's
built-in SSH server on TCP port 2222. Daily application dumps are written to
`/var/backup/gitea`; Restic-to-Unraid remains a separate follow-up because the Unraid endpoint
and credentials are not yet defined.

Before restoring production data, confirm the supported upgrade path from the existing Gitea
version to the Gitea version packaged by the pinned Nixpkgs revision. Do not combine an
unsupported major-version jump with the host migration.

No production data migration is performed by this change.
