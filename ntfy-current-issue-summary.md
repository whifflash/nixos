# NixOS ntfy Integration — Current Issue Summary

## Goal

Add a self-hosted `ntfy` service to the NixOS repository and connect the existing Prometheus Alertmanager notification bridge to it.

Desired setup:

- Public endpoint: `https://ntfy.c4rb0n.cloud`
- Self-hosted `ntfy`
- Anonymous access disabled
- User registration disabled
- Three topics:
  - `icarus-critical`
  - `icarus-warning`
  - `icarus-info`
- Users:
  - `alertmanager`: write-only access to all three topics
  - `mhr`: read-only access to all three topics
- Password authentication for now
- Future users such as `luise` should be easy to add with limited topic access
- Secrets stored through `sops-nix`
- Configuration should be declarative and linter-friendly

## Relevant SOPS keys

The intended secrets are:

```text
ntfy/users/alertmanager/password
ntfy/users/alertmanager/password_hash
ntfy/users/mhr/password_hash
```

Purpose:

- `ntfy/users/alertmanager/password`
  - Plaintext password
  - Used by the Alertmanager-to-ntfy forwarding service when publishing notifications

- `ntfy/users/alertmanager/password_hash`
  - bcrypt hash of the same password
  - Used by the ntfy server to define the `alertmanager` account

- `ntfy/users/mhr/password_hash`
  - bcrypt hash of the phone-app password
  - Used by the ntfy server to define the `mhr` account

Hashes were generated interactively with:

```bash
nix shell nixpkgs#ntfy-sh -c ntfy user hash
```

## What was implemented initially

A custom `infra.services.ntfy` module was added with:

- `services.ntfy-sh`
- nginx reverse proxy
- ACME integration
- an imperative provisioning service:
  - `infra-ntfy-provision.service`
- CLI-based user creation and ACL setup
- integration with the monitoring service and Alertmanager webhook adapter

## Problems encountered

### 1. Incorrect ntfy CLI flags

The provisioning service initially used:

```bash
ntfy user add --config /etc/ntfy/server.yml
```

Then:

```bash
ntfy --config /etc/ntfy/server.yml user add
```

Then:

```bash
ntfy --auth-file /var/lib/ntfy-sh/user.db user add
```

All were wrong for ntfy `2.23.0`.

Observed errors:

```text
flag provided but not defined: -config
```

and:

```text
flag provided but not defined: -auth-file
```

The server configuration options `config` and `auth-file` are not accepted as general CLI flags in this version.

### 2. Provisioning raced the ntfy server

The provisioning service attempted to modify the auth database before ntfy had created it.

Observed error:

```text
auth-file does not exist; please start the server at least once to create it
```

### 3. Static user and DynamicUser conflict

The custom module changed the service between:

```text
DynamicUser=false
```

and the native NixOS module default:

```text
DynamicUser=true
```

This caused systemd to migrate state between:

```text
/var/lib/ntfy-sh
```

and:

```text
/var/lib/private/ntfy-sh
```

Observed failure:

```text
Found pre-existing public StateDirectory= directory /var/lib/ntfy-sh,
migrating to /var/lib/private/ntfy-sh

Failed to set up mount namespacing:
/var/lib/private/ntfy-sh: No such file or directory
```

The stale empty `/var/lib/ntfy-sh` directory was manually removed.

### 4. Invalid SOPS systemd dependency

A later module version added:

```nix
after = [ "sops-install-secrets.service" ];
requires = [ "sops-install-secrets.service" ];
```

But this system does not have a persistent unit named:

```text
sops-install-secrets.service
```

Observed error:

```text
Failed to start ntfy-sh.service:
Unit sops-install-secrets.service not found.
```

This dependency must not be used.

### 5. Missing SOPS declaration in monitoring module

The ntfy patch temporarily removed the SOPS declaration for:

```text
ntfy/users/alertmanager/password
```

while the monitoring service still referenced:

```nix
config.sops.secrets.${cfg.alerting.ntfyPasswordSecret}.path
```

Observed evaluation error:

```text
attribute '"ntfy/users/alertmanager/password"' missing
```

That plaintext password secret must remain declared by the monitoring module when alerting is enabled.

### 6. Missing `services.ntfy-sh.settings.base-url`

A custom SOPS-rendered `server.yml` was introduced while the native NixOS module still evaluated its own settings.

Observed error:

```text
The option `services.ntfy-sh.settings.base-url'
was accessed but has no value defined.
```

The native NixOS module expects:

```nix
services.ntfy-sh.settings.base-url
```

to be defined.

### 7. Patches repeatedly failed to apply

Several patches were generated against assumed intermediate repository states rather than the exact current working tree.

Typical error:

```text
patch failed: services/ntfy/default.nix:1
services/ntfy/default.nix: patch does not apply
```

The next attempt must use the newly uploaded repository archive as the sole source of truth and verify the patch against a fresh extraction of that exact archive.

## Current architectural conclusion

The imperative provisioning service is the wrong design and should be removed completely.

Do not keep:

```text
infra-ntfy-provision.service
```

Do not run ntfy administrative CLI commands during activation.

Do not override:

```text
ExecStart
User
Group
DynamicUser
StateDirectory
```

unless absolutely required.

Do not generate a complete secret `server.yml` manually.

Do not depend on:

```text
sops-install-secrets.service
```

## Preferred implementation

Use the pinned NixOS ntfy module natively:

```nix
services.ntfy-sh = {
  enable = true;

  environmentFile =
    config.sops.templates."ntfy/environment".path;

  settings = {
    base-url = "https://ntfy.c4rb0n.cloud";
    listen-http = "127.0.0.1:<configured-port>";
    behind-proxy = true;

    auth-file = "/var/lib/ntfy-sh/user.db";
    auth-default-access = "deny-all";

    enable-login = true;
    enable-signup = false;
  };
};
```

Use a SOPS-rendered environment file containing:

```text
NTFY_AUTH_USERS=...
NTFY_AUTH_ACCESS=...
```

Conceptually:

```text
NTFY_AUTH_USERS=alertmanager:<bcrypt-hash>:user,mhr:<bcrypt-hash>:user
```

```text
NTFY_AUTH_ACCESS=alertmanager:icarus-critical:write-only,alertmanager:icarus-warning:write-only,alertmanager:icarus-info:write-only,mhr:icarus-critical:read-only,mhr:icarus-warning:read-only,mhr:icarus-info:read-only
```

The exact quoting and template syntax must be checked carefully so bcrypt `$` characters and comma-separated values are preserved correctly.

## Monitoring integration requirement

The existing Alertmanager-to-ntfy bridge still needs the plaintext publisher password.

The monitoring module must continue declaring:

```nix
sops.secrets.${cfg.alerting.ntfyPasswordSecret}
```

where the default secret name is:

```text
ntfy/users/alertmanager/password
```

The forwarding service should load it with a systemd credential or another existing repository pattern.

## Files likely involved

At minimum:

```text
services/ntfy/default.nix
services/ntfy/README.md
services/monitoring/default.nix
services/monitoring/scripts/alertmanager_ntfy.py
services/default.nix
hosts/icarus/default.nix
```

The exact current state must be inspected from the latest uploaded `repo.zip`.

## Required validation before returning a patch

The next implementation should not be returned until all of the following are done:

```bash
git apply --check <patch>
git diff --check
```

The checks must be run against a fresh extraction of the exact latest uploaded archive.

Also inspect the resulting module to confirm it contains:

```text
services.ntfy-sh.settings.base-url
services.ntfy-sh.environmentFile
NTFY_AUTH_USERS
NTFY_AUTH_ACCESS
```

and does not contain:

```text
infra-ntfy-provision
sops-install-secrets.service
custom ntfy ExecStart
DynamicUser = false
custom users.users.ntfy-sh
custom users.groups.ntfy-sh
```

If Nix is available in the environment, also run an evaluation or build. If Nix is not available, state that clearly and do not claim build validation.

## Immediate task for the new chat

Using the latest attached repository archive only:

1. Inspect the exact current `services/ntfy/default.nix`.
2. Inspect the pinned NixOS `services.ntfy-sh` option interface.
3. Replace the brittle custom implementation with the native module plus SOPS `environmentFile`.
4. Preserve the monitoring plaintext password secret declaration.
5. Update documentation.
6. Generate one patch against that exact archive.
7. Verify patch applicability against a fresh extraction of the same archive.
