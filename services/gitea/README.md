# Gitea

Native NixOS deployment for `git.<infra.domain>`. The service is currently enabled on
`mia` and is the authoritative Gitea instance.

## Components

The module in `services/gitea/default.nix` provides:

- Gitea with SQLite state under `/var/lib/gitea`
- Git LFS storage managed by Gitea
- Nginx TLS termination
- DNS-01 ACME certificates through the shared infrastructure ACME module
- Gitea's built-in SSH server on TCP port `2222`
- local application dumps under `/var/backup/gitea`
- encrypted off-host Restic backups to `vela`

Host placement is controlled with:

```nix
infra.services.gitea.enable = true;
```

## Endpoints

| Purpose           | Endpoint                                                   |
| ----------------- | ---------------------------------------------------------- |
| Web and HTTPS Git | `https://git.c4rb0n.cloud`                                 |
| SSH Git           | `ssh://git@git.c4rb0n.cloud:2222/<owner>/<repository>.git` |
| Restic repository | `rest:https://restic.c4rb0n.cloud/restic-gitea`            |

The `restic.c4rb0n.cloud` name resolves internally to `vela`. TLS terminates at the
`nginx-proxy` stack on `vela`, which forwards requests to `rest-server` over its Docker
`proxy` network.

## Persistent state

The complete native Gitea state is stored below:

```text
/var/lib/gitea
```

This includes the SQLite database, repositories, LFS objects, attachments, avatars,
application data, generated configuration, and persistent service secrets.

Do not copy only the repository directory when recovering the service. A complete
recovery restores all of `/var/lib/gitea` from the same snapshot.

## Backup layers

Two complementary backup mechanisms are enabled:

1. `gitea-dump.timer` creates an application-native archive under
   `/var/backup/gitea` at `03:15`.
2. `restic-backups-gitea.timer` creates an encrypted off-host snapshot on `vela` at
   `04:00`, with up to 15 minutes of randomized delay.

The Restic job stops `gitea.service` before reading `/var/lib/gitea` and starts it again
in its cleanup phase. This produces a transactionally consistent SQLite backup. The
Restic snapshot is the primary disaster-recovery backup; the local Gitea dump is a
secondary application-native recovery format.

The retention policy keeps:

- 7 daily snapshots
- 5 weekly snapshots
- 12 monthly snapshots
- 3 yearly snapshots

Snapshots are grouped by host and path.

## Secrets

The Gitea backup uses two independent credentials:

- the REST HTTP username and password used to authenticate to `rest-server`
- the Restic repository password used to encrypt and decrypt backup data

They are stored in `secrets/infrastructure.yaml` through SOPS:

```yaml
restic:
  gitea:
    repository_password: <repository-encryption-password>
    environment: |
      RESTIC_REST_USERNAME=restic-gitea
      RESTIC_REST_PASSWORD=<rest-server-http-password>
```

The repository password must not be stored on `vela`. Losing it makes the Restic
repository unrecoverable.

## Operations

The backup and recovery commands are documented in
[`docs/runbooks/gitea-backup-restore.md`](../../docs/runbooks/gitea-backup-restore.md).
