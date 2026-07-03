# Infrastructure hub

The hub is a static landing page served by Nginx at `hub.<infra.domain>`.
It contains links to the web-facing infrastructure services and has no
persistent runtime state.

## Enablement

```nix
infra.services.hub.enable = true;
```

The module:

- enables Nginx;
- serves the files from `services/hub/assets`;
- obtains the shared wildcard ACME certificate;
- redirects unmatched HTTPS virtual hosts to the hub;
- opens TCP ports 80 and 443.

Only one production host should enable the hub for the public DNS record.
The current production host is Icarus.

## Validation

After switching the host configuration:

```bash
systemctl status nginx --no-pager
curl --fail --silent --show-error --head https://hub.c4rb0n.cloud
```

Open `https://hub.c4rb0n.cloud` and verify that all service links resolve.

## Backup

No backup is required. The page and Nginx configuration are fully declared in
this repository and contain no mutable service state.
