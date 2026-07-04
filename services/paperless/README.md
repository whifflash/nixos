# Paperless-ngx

Paperless-ngx runs natively on Icarus with local PostgreSQL, Redis, OCR, and document storage. It is available at `https://paperless.c4rb0n.cloud` and is linked from the infrastructure hub.

Backups are intentionally not part of this first deployment. A later change will add Restic backups to Vela for the database, media, data, and document export.

## Initial setup

After the first deployment, create the administrator account:

```console
sudo paperless-manage createsuperuser
```

Create normal accounts for Hannes, Antonia, Luise, and Dietmar. Use a separate administrator account for administration rather than daily document work. Create groups and assign document permissions according to the household's preferred sharing model.

## Scanner ingestion

The Brother ADS-1800W connects to Icarus over SFTP. The restricted account cannot open a shell or use SSH forwarding.

Use the SFTP username configured by the service and the password stored in SOPS. Do not place the plaintext password in this repository or in service documentation.

```text
Protocol: SFTP
Host: icarus
Port: 22
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
journalctl -u paperless-consumer -f
sudo paperless-manage createsuperuser
```

## SOPS secret

Add the scanner account password hash to `secrets/infrastructure.yaml` with this structure:

```yaml
paperless:
  sftp:
    password_hash: <sha-512-password-hash>
```

Generate the hash interactively and store it without writing the plaintext password to disk or shell history:

```console
HASH="$(nix shell nixpkgs#mkpasswd -c mkpasswd -m sha-512)"
sops set secrets/infrastructure.yaml '["paperless"]["sftp"]["password_hash"]' "\"$HASH\""
unset HASH
```

Verify that the encrypted key exists before deploying:

```console
sops --decrypt secrets/infrastructure.yaml \
  | yq '.paperless.sftp.password_hash'
```
