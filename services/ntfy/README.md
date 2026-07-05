# ntfy notification service

This module runs a private ntfy server on Icarus and exposes it through Nginx at
`https://ntfy.c4rb0n.cloud`. Hosts enable it with:

```nix
infra.services.ntfy.enable = true;
```

The implementation uses the native NixOS `services.ntfy-sh` module, the shared
wildcard ACME certificate, and declarative user and topic ACL provisioning.
Anonymous access and public account registration are disabled.

## Required secrets

Create these plaintext password values in `secrets/infrastructure.yaml` before
building or switching:

```yaml
ntfy:
  users:
    alertmanager:
      password: ENC[...]
    mhr:
      password: ENC[...]
```

The exact SOPS keys are:

```text
ntfy/users/alertmanager/password
ntfy/users/mhr/password
```

`alertmanager` is a write-only integration account. `mhr` is a read-only phone
subscriber. Passwords are passed to the provisioning unit through systemd
credentials and do not enter the Nix store.

## Topics and ACLs

The default topics are:

| Topic             | Purpose                                       |
| ----------------- | --------------------------------------------- |
| `icarus-critical` | Critical infrastructure alerts                |
| `icarus-warning`  | Warning-level infrastructure alerts           |
| `icarus-info`     | Informational alerts and low-priority notices |

The default ACLs are:

- `alertmanager`: write-only access to all three topics;
- `mhr`: read-only access to all three topics;
- anonymous clients: no access.

Users and ACLs are extensible. For example, a future `luise` account can receive
only PV-related topics without gaining access to unrelated infrastructure alerts:

```nix
infra.services.ntfy.users.luise = {
  passwordSecret = "ntfy/users/luise/password";
  access = [
    {
      topic = "pv-critical";
      permission = "read-only";
    }
    {
      topic = "pv-warning";
      permission = "read-only";
    }
  ];
};
```

The corresponding SOPS key would be `ntfy/users/luise/password`.

## Provisioning behavior

`infra-ntfy-provision.service` runs before `ntfy-sh.service`. It creates missing
users, updates existing passwords and roles, and applies the declared ACLs. This
makes password rotation and repeated deployments safe.

Useful checks:

```bash
systemctl status infra-ntfy-provision.service ntfy-sh.service --no-pager
journalctl -u infra-ntfy-provision.service -u ntfy-sh.service -n 100 --no-pager
sudo -u ntfy-sh ntfy user list --config /etc/ntfy/server.yml
sudo -u ntfy-sh ntfy access --config /etc/ntfy/server.yml
```

## Phone setup

In the ntfy app:

1. Add `https://ntfy.c4rb0n.cloud` as a custom server.
2. Configure the username `mhr` and the password stored in SOPS.
3. Subscribe to `icarus-critical`, `icarus-warning`, and optionally
   `icarus-info`.
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
