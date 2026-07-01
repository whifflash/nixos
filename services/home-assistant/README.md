# Home Assistant

Home Assistant runs as the upstream OCI image managed declaratively by NixOS
and Podman. Mosquitto, InfluxDB, Nginx, ACME, and Restic remain native NixOS
services.

The migration image is pinned to `2025.12.3`. After validation, pin the image by
digest as well as by version.

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
