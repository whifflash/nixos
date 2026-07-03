# Home automation backup

This module owns the consistency boundary across the home-automation stack:

- Home Assistant OCI state
- native Mosquitto persistence
- native InfluxDB logical backups

The generated Restic job performs the following sequence:

1. stop Home Assistant and Mosquitto;
2. copy their cold state into `/var/backup/home-automation/current`;
3. create an InfluxDB logical backup in the same staging tree;
4. restart Home Assistant and Mosquitto;
5. upload the staging tree to Vela with Restic;
6. apply the configured retention policy.

Home Assistant and Mosquitto are restarted before the network upload begins, so
their downtime is limited to local staging time. A shell trap restarts both
services if staging fails.

## Required SOPS values

Add the following values to `secrets/infrastructure.yaml`:

```yaml
restic:
  home_automation:
    repository_password: "..."
    environment: |
      RESTIC_REST_USERNAME=restic-home-automation
      RESTIC_REST_PASSWORD=...
```

`repository_password` encrypts the Restic repository. `RESTIC_REST_PASSWORD`
authenticates the `restic-home-automation` HTTP user at Vela's `rest-server`.
Use different random values for these credentials.

Create the matching private repository account on Vela before enabling the
module. On the current Vela deployment, the running `rest-server` container
bind-mounts `/config/rest-server` from the host to `/config` in the container,
and reads `/config/.htpasswd`. Therefore, the active password file is:

```text
/config/rest-server/.htpasswd
```

Append the `restic-home-automation` account to that file; do not overwrite the
existing `restic-gitea` entry. See the runbook for the exact commands and
verification steps.

The default repository URL is:

```text
rest:https://restic.c4rb0n.cloud/restic-home-automation
```

## Schedule and retention

The default timer runs daily at `04:30`, with a persistent timer and up to 15
minutes of randomized delay. A persistent timer runs a missed invocation after
the host returns, but it does not automatically retry a failed backup.

A single invocation is limited to two hours. Home Assistant and Mosquitto are
restarted before the Restic upload starts, so an unavailable Vela server does
not leave either service stopped while the network operation waits or fails.
The next automatic attempt is the following timer invocation unless the service
is started manually.

Retention is:

- 7 daily snapshots
- 5 weekly snapshots
- 12 monthly snapshots
- 3 yearly snapshots

See `docs/runbooks/home-automation-backup-restore.md` for setup, validation,
manual execution, and complete restore procedures.
