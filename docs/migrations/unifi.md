# UniFi migration to Icarus

This migration restores the latest verified UniFi application backup into a
fresh controller running the same application version as the previous Docker
Compose deployment. The old MongoDB directory is retained as a fallback but is
not required for the normal migration.

## Source backup

The selected application backup is:

```text
/var/tmp/icarus-docker-compose-restore/docker-compose/data/unifi-backup/autobackup/autobackup_8.0.26_20260601_0030_1780273800005.unf
```

It was produced by UniFi Network Application 8.0.26. No relevant topology,
user, or configuration changes occurred after this backup.

## 1. Duplicate the backup

Never use the only extracted copy as the working import file.

```bash
sudo install -d -m 0700 /var/backups/unifi-import

sudo install \
  -o root \
  -g root \
  -m 0600 \
  /var/tmp/icarus-docker-compose-restore/docker-compose/data/unifi-backup/autobackup/autobackup_8.0.26_20260601_0030_1780273800005.unf \
  /var/backups/unifi-import/autobackup_8.0.26_20260601_0030_1780273800005.unf
```

Verify that the source and duplicate are identical:

```bash
sudo sha256sum \
  /var/tmp/icarus-docker-compose-restore/docker-compose/data/unifi-backup/autobackup/autobackup_8.0.26_20260601_0030_1780273800005.unf \
  /var/backups/unifi-import/autobackup_8.0.26_20260601_0030_1780273800005.unf
```

The hashes must match.

Copy the duplicate to the machine running the browser:

```bash
scp \
  mhr@icarus:/var/backups/unifi-import/autobackup_8.0.26_20260601_0030_1780273800005.unf \
  ./
```

## 2. Deploy without automatic startup

The initial host configuration should be:

```nix
infra.services = {
  unifi = {
    enable = true;
    autoStart = false;
  };

  homeAutomationBackup.enable = false;
};
```

Build and switch:

```bash
nix fmt
nix flake check
nix build .#nixosConfigurations.icarus.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#icarus
```

Confirm that the unit exists but remains stopped:

```bash
systemctl status podman-unifi.service --no-pager
```

## 3. Start the controller manually

```bash
sudo systemctl start podman-unifi.service
sudo journalctl -fu podman-unifi.service
```

In another terminal:

```bash
sudo podman ps --filter name=unifi
sudo podman logs --tail 200 unifi
sudo ss -lntup | grep -E ':(8080|8443|3478|10001)\b'
```

Open:

```text
https://unifi.c4rb0n.cloud
```

During first-run setup, choose the restore-from-backup path and upload:

```text
autobackup_8.0.26_20260601_0030_1780273800005.unf
```

Do not create and configure a new empty site before restoring the backup.

## 4. Validate the restore

Confirm all of the following:

- the expected site exists;
- switches and access points are listed;
- networks and WLANs match the previous deployment;
- controller users are present;
- devices reconnect and become online;
- device inform traffic reaches Icarus on TCP port 8080;
- the public UI works through `https://unifi.c4rb0n.cloud`.

Inspect recent logs when a device does not reconnect:

```bash
sudo journalctl \
  -u podman-unifi.service \
  --since "15 minutes ago" \
  --no-pager
```

The restored controller keeps its previous inform host configuration. When a
device still points to a stale address, use the device SSH interface to set the
inform URL to:

```text
http://10.20.31.41:8080/inform
```

Run `set-inform` a second time after the controller adopts the device when the
device requires it.

## 5. Enable automatic startup and backup

After the controller has been validated, update the host configuration:

```nix
infra.services = {
  unifi = {
    enable = true;
    autoStart = true;
  };

  homeAutomationBackup.enable = true;
};
```

Deploy again:

```bash
sudo nixos-rebuild switch --flake .#icarus
```

Run the first coordinated backup manually:

```bash
sudo systemctl start restic-backups-home-automation.service
sudo journalctl -fu restic-backups-home-automation.service
```

Confirm that UniFi returns to the running state after local staging:

```bash
systemctl status \
  podman-unifi.service \
  restic-backups-home-automation.service \
  --no-pager
```

## Rollback material

Do not delete these until the migrated controller has completed at least one
successful off-host backup and has operated normally for several days:

- the original `icarus-docker-compose.tar.zst` archive;
- the extracted `unifi-data` directory;
- the original `.unf` autobackup directory;
- `/var/backups/unifi-import/`.
