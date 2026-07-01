# Home automation backup

This module remains separate because it coordinates one consistency boundary
across three services:

- Home Assistant OCI state
- native Mosquitto persistence
- native InfluxDB logical backup

The job stops Home Assistant and Mosquitto, stages their cold state, creates an
InfluxDB logical backup, restarts the services, and then uploads the staging
directory to Vela with Restic. Network transfer time therefore does not extend
Home Assistant downtime.

Enable it only after migration validation and after Home Assistant automatic
startup is enabled.

Expected SOPS keys:

```yaml
restic:
  home_automation:
    repository_password: "..."
    environment: |
      RESTIC_REST_USERNAME=restic-home-automation
      RESTIC_REST_PASSWORD=...
```

Create the matching `restic-home-automation` account in Vela's `rest-server`
before enabling the module.
