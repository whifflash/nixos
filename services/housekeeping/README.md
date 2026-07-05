# Infrastructure housekeeping

This module limits storage growth caused by obsolete NixOS generations, unreachable
Nix store paths, and Podman images that are no longer used by any container.

The reusable implementation lives in `services/housekeeping`. Hosts opt in through
`infra.services.housekeeping.enable`.

## Enablement

```nix
infra.services.housekeeping.enable = true;
```

The default policy is deliberately conservative:

- Nix housekeeping runs weekly on Sunday at 05:30;
- Podman housekeeping runs weekly on Sunday at 06:15;
- both timers have up to 30 minutes of randomized delay;
- missed runs execute after the next boot because the timers are persistent;
- NixOS generations younger than 30 days remain available;
- systemd-boot displays at most five NixOS generations;
- Podman removes only images that are unused by every existing container;
- Podman volumes are never pruned.

The schedules follow the nightly Gitea and home-automation backups, which run at
04:00 and 04:30 respectively. The two cleanup jobs are separated to reduce I/O
contention and make failures easier to diagnose.

## Nix housekeeping

The `infra-nix-housekeeping.service` unit performs two operations:

1. `nix-collect-garbage --delete-older-than 30d` removes old profile generations
   and store paths that are no longer reachable;
2. `nix-store --optimise` deduplicates identical store files using hard links.

The age-based retention policy is intentional. Keeping exactly five profile
entries could represent only a few days during active development or many months
on a quiet host. A 30-day window provides predictable rollback coverage, while
`boot.loader.systemd-boot.configurationLimit = 5` keeps the boot menu concise.

Configuration example:

```nix
infra.services.housekeeping = {
  enable = true;

  nix = {
    retentionAge = "30d";
    configurationLimit = 5;
    schedule = "Sun *-*-* 05:30:00";
  };
};
```

## Podman housekeeping

The `infra-podman-housekeeping.service` unit runs:

```sh
podman image prune --all --force
```

This removes images not referenced by any existing container. Images used by the
Home Assistant and UniFi containers remain intact. The unit does not run
`podman system prune`, does not pass `--volumes`, and therefore does not delete
persistent container data.

Configuration example:

```nix
infra.services.housekeeping = {
  enable = true;

  podman.schedule = "Sun *-*-* 06:15:00";
};
```

## Manual operation and validation

Inspect the schedules after switching the host:

```sh
systemctl list-timers 'infra-*-housekeeping.timer'
systemctl status infra-nix-housekeeping.timer --no-pager
systemctl status infra-podman-housekeeping.timer --no-pager
```

Run either task manually:

```sh
sudo systemctl start infra-nix-housekeeping.service
sudo systemctl start infra-podman-housekeeping.service
```

Inspect results:

```sh
systemctl status infra-nix-housekeeping.service --no-pager
systemctl status infra-podman-housekeeping.service --no-pager
journalctl -u infra-nix-housekeeping.service --no-pager
journalctl -u infra-podman-housekeeping.service --no-pager
```

Before the first automatic Podman cleanup, the candidates can be reviewed with:

```sh
sudo podman image prune --all
```

Answer `n` to leave the images unchanged.

## Operational considerations

Garbage collection makes generations outside the retention window unavailable
for rollback. A generation still referenced by another profile or GC root remains
reachable and is not collected.

Pruned container images may need to be downloaded again during a future rollback
or container recreation. Persistent service state must live in declared bind
mounts or volumes and is not affected by this module.

The cleanup services use reduced CPU priority and idle I/O scheduling. They are
not ordered directly after backup units because the backups are daily while
housekeeping is weekly; the separated calendar times provide the intended order.

## Monitoring roadmap

The monitoring module should observe this declared policy in the next step. Add:

- Nix store size and path count;
- system-generation count and oldest retained generation age;
- timestamp, result, duration, and reclaimed bytes for Nix housekeeping;
- Podman image count, total size, and reclaimable size;
- timestamp, result, duration, and reclaimed bytes for Podman housekeeping;
- alerts for stale or repeatedly failed cleanup jobs;
- growth alerts based on sustained store or image accumulation rather than a
  single absolute-size threshold.

Metrics should be added only after the cleanup jobs have been deployed and their
output has been observed on Icarus.
