# Paperless-ngx

Paperless-ngx runs natively on Icarus with local PostgreSQL, Redis, OCR, and document storage. It is available at `https://paperless.c4rb0n.cloud` and is linked from the infrastructure hub.

Backups are intentionally not part of this first deployment. A later change will add Restic backups to Vela for the database, media, data, and document export.

## Accounts

Paperless accounts are reconciled declaratively after the database migrations complete. The service creates or updates these users:

- `paperless-admin`, a dedicated administrator account
- `hannes`
- `antonia`
- `luise`
- `dietmar`

The four personal accounts are members of the shared `familie` group. Passwords come from SOPS and are reapplied when `paperless-provision-accounts.service` runs. Changing a password in SOPS and redeploying therefore rotates the corresponding Paperless password without a manual web-interface step.

The `familie` group permissions are also reconciled declaratively. They cover the Paperless web UI and routine, non-destructive document management. User and group administration, workflow management, mail configuration, application configuration, and global delete permissions remain administrator-only. Because reconciliation uses the declared permission set as the source of truth, permission changes made manually to the `familie` group are overwritten on the next deployment or service restart.

Do not use `paperless-admin` for routine document work. The administrator can see all documents regardless of object-level permissions.

## Declarative metadata

The provisioning service also reconciles the initial document types, nested tags, and storage paths. Declared names, colours, nesting, inbox status, and path templates are authoritative and overwrite manual changes to those objects. Additional metadata objects created later in the Paperless UI are left untouched. Correspondents remain entirely user-managed.

Document types:

```text
Bescheid
Bestätigung
Kontoauszug
Mahnung
Nachweis
Police
Rechnung
Schreiben
Vertrag
Einladung
Sonstiges Schreiben
```

Tags:

```text
Person
├── Hannes
├── Antonia
├── Luise
└── Dietmar

Bereich
├── Arbeit
├── Auto
├── Bank
├── Gesundheit
├── Haus
├── Schule
├── Finanzen
│   └── Steuer
└── Versicherung

Status
├── Eingang
├── Prüfen
├── Offen
├── Bezahlen
└── Erledigt
```

`Status/Eingang` is the Paperless inbox tag. Year tags are intentionally omitted because document dates already provide reliable year filtering and a static declaration would need annual maintenance.

Storage paths:

| Name      | Template                                                                         |
| --------- | -------------------------------------------------------------------------------- |
| `Hannes`  | `hannes/{{ created_year }}/{{ correspondent }}/{{ title }}`                      |
| `Antonia` | `antonia/{{ created_year }}/{{ correspondent }}/{{ title }}`                     |
| `Luise`   | `luise/{{ created_year }}/{{ correspondent }}/{{ title }}`                       |
| `Dietmar` | `dietmar/{{ created_year }}/{{ correspondent }}/{{ title }}`                     |
| `Familie` | `familie/{{ created_year }}/{{ document_type }}/{{ correspondent }}/{{ title }}` |
| `Eingang` | `eingang/{{ added_year }}/{{ added_month }}/{{ original_name }}`                 |

Storage paths control the managed on-disk filename layout. They do not create browser-style folders or assign themselves to documents; the scanner workflows should assign the matching storage path.

## Scanner ingestion

The Brother ADS-1800W connects to a dedicated scanner-only SFTP daemon on Icarus. It is separate from the primary SSH daemon, disables PAM, accepts only the restricted scanner account, and cannot open a shell or use SSH forwarding.

Use the SFTP username configured by the service and the password stored in SOPS. Do not place the plaintext password in this repository or in service documentation.

```text
Protocol: SFTP
Host: icarus
Port: 2223
Username: paperless-ingest
Remote folders:
  /hannes
  /antonia
  /luise
  /dietmar
  /familie
  /eingang
```

The scanner account password is represented by the encrypted `paperless/sftp/password_hash` key in `secrets/infrastructure.yaml`. The value must be a SHA-512 password hash suitable for `users.users.<name>.hashedPasswordFile`.

Create one scanner shortcut for each remote folder. All shortcuts may use the same SFTP account. Recommended scan settings are PDF, 300 dpi, automatic colour, duplex scanning, and blank-page removal. Paperless performs OCR, so scanner-side searchable PDF generation is unnecessary.

The directories are queues, not permanent storage. Paperless removes successfully consumed source files after importing them into its managed media directory.

## Workflows

Create six `Consumption Started` workflows in the Paperless web interface:

- `hannes`
- `antonia`
- `luise`
- `dietmar`
- `familie`
- `eingang`

Match each workflow against its corresponding consumption path. The personal workflows should assign the relevant owner and permissions. The `familie` workflow should grant the shared family group access. The `eingang` workflow is the safe general inbox: assign it to Hannes, add an `eingang` tag, and avoid broad permissions until the document has been reviewed.

Use scanner routing only to decide initial ownership and visibility. Let Paperless OCR, tags, correspondents, document types, and later matching rules classify the document content.

## Operations

Useful commands:

```console
systemctl status paperless-web paperless-consumer paperless-task-queue
systemctl status paperless-sftp-sshd.service
systemctl status paperless-provision-accounts.service
journalctl -u paperless-consumer -f
journalctl -u paperless-sftp-sshd.service
journalctl -u paperless-provision-accounts.service
```

## SOPS secrets

Add the scanner account password hash and the Paperless account passwords to `secrets/infrastructure.yaml` with this structure:

```yaml
paperless:
  sftp:
    password_hash: <sha-512-password-hash>
  users:
    paperless-admin:
      password: <administrator-password>
    hannes:
      password: <hannes-password>
    antonia:
      password: <antonia-password>
    luise:
      password: <luise-password>
    dietmar:
      password: <dietmar-password>
```

The SFTP value is a Unix SHA-512 password hash because NixOS consumes it through `hashedPasswordFile`. The Paperless user values are plaintext only inside the encrypted SOPS document; Django hashes them for storage in the Paperless database.

Generate the SFTP hash interactively:

```console
nix shell nixpkgs#mkpasswd -c mkpasswd -m sha-512
```

Edit the encrypted file without placing credentials in repository documentation or shell arguments:

```console
sops secrets/infrastructure.yaml
```

After deployment, account reconciliation can be rerun with:

```console
sudo systemctl restart paperless-provision-accounts.service
```
