# Mosquitto

Native NixOS MQTT broker for the home-automation stack.

The module provides:

- TCP listener on port `1883`
- anonymous access disabled
- one SOPS-managed user with full topic access
- persistent retained messages and sessions under `/var/lib/mosquitto`

Expected SOPS key:

```yaml
mosquitto:
  users:
    mosquitto:
      password_hash: "$7$..."
```

Store only the hash portion from the old `mosquitto.passwd`, without the
`mosquitto:` username prefix.

The old Compose stack published port `9001`, but its configuration did not
create a WebSocket listener. The native service therefore exposes only `1883`.
