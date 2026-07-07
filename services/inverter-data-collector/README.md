# Inverter data collector

`inverter-data-collector` is a native systemd service that reads the SMA roof inverter over
SunSpec Modbus TCP and publishes measurements plus Home Assistant MQTT discovery documents.

The service is stateless. Its implementation and configuration live in Git, while MQTT
credentials are supplied through SOPS. It therefore does not require backup integration.

## Runtime

- Inverter: `10.20.80.101:502`, SunSpec unit ID `126`
- Poll interval: 5 seconds
- MQTT broker: local Mosquitto on `127.0.0.1:1883`
- MQTT user: `inverter-data-collector`
- State topic: `house/pv/sma/stp20_50/state`
- Availability topic: `house/pv/sma/stp20_50/availability`
- Discovery prefix: `homeassistant`

The dedicated MQTT account may only publish the collector state, availability, and Home
Assistant discovery topics. The Mosquitto user is declared through Nix; no manual broker user
creation is required.

## Secrets

Two SOPS values represent the same generated password in different forms:

```yaml
mosquitto:
  users:
    inverter-data-collector:
      password_hash: "$7$..."

inverter-data-collector:
  mqtt_password: "plaintext password used by the client"
```

- `password_hash` is consumed by Mosquitto.
- `mqtt_password` is delivered to the collector through a systemd credential.

Generate a strong password and its Mosquitto hash without adding the password to Git:

```bash
password_file="$(mktemp)"
trap 'rm -f "$password_file"' EXIT

nix shell nixpkgs#mosquitto -c \
  mosquitto_passwd -c "$password_file" inverter-data-collector

cat "$password_file"
```

Enter the same plaintext password under `inverter-data-collector/mqtt_password` and copy only
the hash after the username into `mosquitto/users/inverter-data-collector/password_hash`:

```bash
sops secrets/infrastructure.yaml
```

Delete the temporary password file after editing SOPS. The collector never receives the
plaintext password through its command line or ordinary environment.

## Operations

```bash
systemctl status inverter-data-collector.service --no-pager
journalctl -fu inverter-data-collector.service
```

Inspect the retained availability value and live state:

```bash
nix shell nixpkgs#mosquitto -c \
  mosquitto_sub \
  -h 127.0.0.1 \
  -u inverter-data-collector \
  -P 'MQTT_PASSWORD' \
  -t 'house/pv/sma/stp20_50/#' \
  -v
```

Prefer reading the Home Assistant entities or service journal over placing the password in shell
history during routine checks.

## State payload

The retained state topic publishes one JSON object per inverter poll. Fields
currently used by monitoring are:

| Field                | Meaning                                    |
| -------------------- | ------------------------------------------ |
| `ts`                 | collector timestamp in UTC                 |
| `ac_power_w`         | current AC power in watts                  |
| `dc_power_w`         | current DC power in watts when available   |
| `ac_energy_total_wh` | lifetime AC energy counter in watt-hours   |
| `status`             | raw SunSpec operating-state code           |
| `status_text`        | mapped operating state such as `producing` |
| `events`             | raw SunSpec event bitmask when available   |

The collector does not currently publish a daily energy counter or a decoded
fault code. Monitoring therefore starts with explicit `fault` status, payload
freshness, and lifetime-counter sanity checks.

## Failure behavior

The process reconnects and republishes Home Assistant discovery after MQTT reconnects. Inverter
or MQTT failures are logged and retried every 15 seconds. SIGTERM publishes retained `offline`
availability before shutdown where the broker remains reachable.

## Future extension

The current implementation deliberately targets one SMA SunSpec inverter. When a replacement
inverter or additional self-built meter is introduced, add a second implementation or generalize
the collector based on the actual protocol rather than introducing an unused plugin framework
now.
