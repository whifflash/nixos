# ntfy notification service

This module runs a private ntfy server on Icarus and exposes it through Nginx at
`https://ntfy.c4rb0n.cloud`. Hosts enable it with:

```nix
infra.services.ntfy.enable = true;
```

The implementation uses the native NixOS `services.ntfy-sh` module, the shared
wildcard ACME certificate, and ntfy's native declarative user and topic ACL configuration.
Anonymous access and public account registration are disabled.

## Required secrets

ntfy's declarative `auth-users` setting expects bcrypt password hashes. Create the
passwords locally, keep the plaintext values for the clients that need them, and
store these hashes in `secrets/infrastructure.yaml`:

```yaml
ntfy:
  users:
    alertmanager:
      password: ENC[...] # Existing plaintext used by Alertmanager
      password_hash: ENC[...] # Used by the ntfy server
    mhr:
      password_hash: ENC[...] # Used by the ntfy server
```

The exact SOPS keys consumed by this module are:

```text
ntfy/users/alertmanager/password_hash
ntfy/users/mhr/password_hash
```

The monitoring module separately consumes the existing plaintext publisher
password at:

```text
ntfy/users/alertmanager/password
```

Generate each bcrypt hash interactively without installing ntfy permanently:

```bash
nix shell nixpkgs#ntfy-sh -c ntfy user hash
```

Run the command once for the `alertmanager` password and once for the `mhr`
password, then place the resulting hashes under the corresponding
`password_hash` keys. The phone app uses the original `mhr` plaintext password;
it does not use the hash.

The password hashes are rendered into a root-only SOPS environment file and
passed through the native `services.ntfy-sh.environmentFile` option. They do
not enter the Nix store. The service does not depend on a separately named
SOPS installation unit; `sops-nix` materializes the template through its normal
activation integration before the system reaches the service startup phase.

## Topics and ACLs

The default topics are:

| Topic               | Purpose                                                 |
| ------------------- | ------------------------------------------------------- |
| `icarus-critical`   | Critical alerts concerning the Icarus host              |
| `icarus-warning`    | Warning-level alerts concerning the Icarus host         |
| `icarus-info`       | Informational alerts concerning the Icarus host         |
| `property-critical` | Critical alerts concerning property infrastructure      |
| `property-warning`  | Warning-level alerts concerning property infrastructure |
| `property-info`     | Informational alerts concerning property infrastructure |

A public catalog generated from these same option values is available at:

```text
https://ntfy.c4rb0n.cloud/topics/
```

The catalog links to each topic in the ntfy web application. A machine-readable
JSON representation is available at `https://ntfy.c4rb0n.cloud/topics.json`.
The catalog is informational; ntfy authentication and ACLs remain authoritative.

The default ACLs are:

- `alertmanager`: write-only access to all Icarus and property topics;
- `mhr`: read-only access to all Icarus and property topics;
- `luise`: read-only access to all property topics;
- anonymous clients: no access.

The `luise` account receives `property-critical`, `property-warning`, and
`property-info` without gaining access to Icarus host alerts. Its declarative
ACL is equivalent to:

```nix
infra.services.ntfy.users.luise.access = [
  {
    topic = config.infra.services.ntfy.topics.propertyCritical;
    permission = "read-only";
  }
  {
    topic = config.infra.services.ntfy.topics.propertyWarning;
    permission = "read-only";
  }
  {
    topic = config.infra.services.ntfy.topics.propertyInfo;
    permission = "read-only";
  }
];
```

The `property-*` category is intended for vital physical systems around the
house and grounds. Reasonable future alerts include:

- `WastewaterPumpUnavailable`;
- `HeatPumpTelemetryStale`;
- `HeatPumpFault`;
- `GateOpenTooLong`;
- `WaterLeakDetected`;
- `SumpPumpFailure`;
- `IndoorTemperatureTooLow`;
- `FreezerTemperatureHigh`;
- `MainsPowerFailure`.

The corresponding SOPS key would be `ntfy/users/luise/password_hash`.

## Declarative authentication behavior

The server configuration contains `auth-users` and `auth-access`. ntfy creates
or updates those users and ACLs when `ntfy-sh.service` starts, and removes
previously provisioned entries that are no longer declared. There is no separate
provisioning unit and no administrative CLI lifecycle to coordinate.

The authentication database remains configured as `/var/lib/ntfy-sh/user.db`.
The module otherwise keeps the native NixOS service definition, including its
`StateDirectory` and `DynamicUser` handling. There is no second service touching
the same state directory.

Useful checks:

```bash
systemctl status ntfy-sh.service --no-pager
journalctl -u ntfy-sh.service -n 100 --no-pager
sudo ls -l /var/lib/ntfy-sh/user.db
```

## Phone setup

In the ntfy app:

1. Add `https://ntfy.c4rb0n.cloud` as a custom server.
2. Configure the username `mhr` and the password stored in SOPS.
3. Subscribe to `icarus-critical`, `icarus-warning`, `property-critical`,
   `property-warning`, and optionally the corresponding `*-info` topics.
4. Configure notification behavior per topic in the app.

The server sets `upstream-base-url` to `https://ntfy.sh` for iOS instant push
compatibility. Android clients can connect directly to the self-hosted server.

## Manual test

```bash
curl \
  --user 'alertmanager:REPLACE_WITH_PASSWORD' \
  --header 'Title: Icarus test' \
  --header 'Priority: high' \
  --data 'Self-hosted ntfy delivery works.' \
  https://ntfy.c4rb0n.cloud/icarus-warning
```

Do not place the real password in shell history on a shared system. An
interactive prompt or temporary environment variable is preferable.
