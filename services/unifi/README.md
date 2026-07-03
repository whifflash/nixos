# UniFi Network Application

This module runs the UniFi Network Application as a Podman container using the
same application version as the previous Docker Compose deployment:

```text
docker.io/jacobalberty/unifi:v8.0.26
```

Persistent state is stored at `/var/lib/unifi` and mounted at `/unifi` inside
the container. The container uses host networking because UniFi device inform,
STUN, and discovery traffic must reach the controller directly.

The public UI is served through Nginx at `https://unifi.c4rb0n.cloud`. Nginx
proxies to the application's self-signed HTTPS listener on `127.0.0.1:8443`.

## Initial migration

Keep `autoStart = false` while deploying the module for the first time. Start
the service manually, restore the verified `.unf` application backup through
the setup UI, and validate device adoption before enabling automatic startup.

The complete procedure is documented in
[`docs/migrations/unifi.md`](../../docs/migrations/unifi.md).

## Important ports

| Protocol | Port  | Purpose                       |
| -------- | ----- | ----------------------------- |
| TCP      | 8080  | Device inform                 |
| UDP      | 3478  | STUN                          |
| UDP      | 10001 | Layer-3 discovery             |
| TCP      | 8443  | Controller UI, loopback/Nginx |

Ports 80 and 443 are opened for Nginx and ACME. Port 8443 is not opened in the
host firewall because the public UI is accessed through Nginx.

## Backup

Once migration is complete, the coordinated home-automation Restic job stops
UniFi only while `/var/lib/unifi` is copied into local staging. UniFi is started
again before Restic contacts Vela.

## Upgrades

UniFi upgrades can migrate the embedded database. Always create a coordinated
Restic snapshot before changing the image and validate each release step before
continuing. The controller was migrated successfully from `8.0.26` to
`10.0.162` in controlled hops.

List published tags without installing Skopeo on the host:

```bash
sudo podman run --rm \
  quay.io/skopeo/stable:latest \
  list-tags \
  docker://docker.io/jacobalberty/unifi |
  jq -r '.Tags[]' |
  grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' |
  sort -V |
  tail -50
```

The complete upgrade and rollback procedure is documented in
[`docs/migrations/unifi.md`](../../docs/migrations/unifi.md#upgrade-the-controller).
