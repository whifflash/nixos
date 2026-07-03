# Home Assistant

Home Assistant runs as the upstream OCI image managed declaratively by NixOS
and Podman. Mosquitto, InfluxDB, Nginx, ACME, and Restic remain native NixOS
services.

The migration started on `2025.12.3` and was upgraded successfully through
monthly release trains to `2026.7.0`. Keep the configured image pinned to an
explicit version, and consider adding a digest after validation.

Follow [`docs/runbooks/home-assistant-upgrade.md`](../../docs/runbooks/home-assistant-upgrade.md)
for version discovery, staged upgrades, validation, and rollback.

## Persistent state

The complete Home Assistant `/config` tree is stored at:

```text
/var/lib/home-assistant
```

The module mounts a SOPS-managed `secrets.yaml` over the copied runtime file.
Expected SOPS content:

```yaml
home_assistant:
  secrets_yaml: |
    influxdb_token: "..."
    # Preserve every other !secret key used by configuration.yaml.
```

Do not commit the plaintext `secrets.yaml` copied from Icarus.

## Zigbee coordinator

The coordinator is a **Silicon Labs Sonoff Zigbee 3.0 USB Dongle Plus** using
the CP210x UART bridge:

```text
USB vendor/product: 10c4:ea60
ID_SERIAL: Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001
Stable host path: /dev/serial/by-id/usb-Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001-if00-port0
Container path: /dev/ttyZIGBEE
```

The stable host path is intentionally mapped to the old container path. With
the complete `.storage` directory and the same physical coordinator, ZHA should
retain the existing Zigbee network and device registry.
