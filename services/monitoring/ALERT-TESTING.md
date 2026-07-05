# Alert-delivery testing

The monitoring module provides an optional, deterministic test facility for the
complete delivery path:

```text
textfile metric -> Node Exporter -> Prometheus rule -> Alertmanager -> ntfy bridge -> ntfy
```

It does not stop or damage a production service. The test facility is disabled
by default so synthetic alert rules and the control command are absent unless
explicitly requested.

## Enable the facility

On Icarus, add:

```nix
infra.services.monitoring.alerting.testAlerts.enable = true;
```

Build and switch the host once. Subsequent test alerts do not require another
rebuild.

## Fire and resolve a test

Commands must run as root because they write to the Node Exporter textfile
collector directory.

```bash
sudo infra-monitoring-test-alert fire critical phone
```

The metric is visible on the next Node Exporter scrape. The
`MonitoringTestAlert` rule remains pending for 30 seconds before firing. Allow
for the Prometheus scrape/evaluation interval and Alertmanager's 30-second group
wait before expecting the notification.

Resolve the alert by removing its metric:

```bash
sudo infra-monitoring-test-alert resolve critical phone
```

Alertmanager has `send_resolved` enabled, so a resolved notification should
arrive after Prometheus observes the metric disappearing.

Use the same procedure for the other severity routes after subscribing to their
ntfy topics:

```bash
sudo infra-monitoring-test-alert fire warning phone
sudo infra-monitoring-test-alert resolve warning phone
sudo infra-monitoring-test-alert fire info phone
sudo infra-monitoring-test-alert resolve info phone
```

Current routing is:

| Severity | ntfy topic        | Firing priority |
| -------- | ----------------- | --------------- |
| critical | `icarus-critical` | urgent          |
| warning  | `icarus-warning`  | high            |
| info     | `icarus-info`     | low             |

Resolved notifications use the same topic with normal priority.

## Inspect test state

```bash
sudo infra-monitoring-test-alert status
curl --fail --silent --show-error \
  'http://127.0.0.1:9090/api/v1/query?query=infra_monitoring_test_alert'
curl --fail --silent --show-error \
  'http://127.0.0.1:9090/api/v1/alerts'
```

Useful service logs are:

```bash
journalctl -u prometheus -u prometheus-alertmanager \
  -u infra-alertmanager-ntfy -u ntfy-sh -n 200 --no-pager
```

## Grouping test

Fire two alerts of the same severity before the first group is sent:

```bash
sudo infra-monitoring-test-alert fire critical group-a
sudo infra-monitoring-test-alert fire critical group-b
```

The Alertmanager route groups by `alertname` and `severity`, so both instances
should appear in one notification. Resolve both afterward:

```bash
sudo infra-monitoring-test-alert resolve critical group-a
sudo infra-monitoring-test-alert resolve critical group-b
```

## Repeat notifications

The current repeat interval is four hours. A repeat test therefore requires
leaving one synthetic alert active for at least four hours. Do not shorten the
production route merely to make this test faster; routing-policy changes belong
in the later policy stage.

## Cleanup

Always resolve every synthetic alert after testing. List active test metrics
with:

```bash
sudo infra-monitoring-test-alert status
```

The files are not persistent across accidental deletion, and no secret values
are written to the metric files, logs, or Nix store.

## Scheduled delivery canary

Icarus also runs a passive delivery canary at 10:00 local time every Wednesday
and Sunday. It is an ordinary end-to-end test notification; no acknowledgement
or action is expected. Seeing it on the phone is the confirmation that remote
notification delivery still works.

The default configuration is:

```nix
infra.services.monitoring.alerting.testAlerts.canary = {
  enable = true;
  schedule = [
    "Wed *-*-* 10:00:00"
    "Sun *-*-* 10:00:00"
  ];
  severity = "critical";
  topic = config.infra.services.ntfy.topics.critical;
  activeDuration = "2m";
};
```

The timer is persistent, so a missed occurrence runs after Icarus next starts.
The synthetic metric is removed automatically after two minutes. Alertmanager
uses a canary-specific receiver with resolved notifications disabled, so the
phone receives one notification rather than a firing/resolved pair.

Inspect the schedule and recent execution with:

```bash
systemctl list-timers infra-monitoring-alert-canary.timer
systemctl status infra-monitoring-alert-canary.timer
journalctl -u infra-monitoring-alert-canary.service -n 50 --no-pager
curl --fail --silent --show-error http://127.0.0.1:9095/metrics
```

The `infra_alertmanager_ntfy_last_canary_success_timestamp_seconds` metric is
updated only after the bridge receives a canary notification from Alertmanager
and ntfy accepts the publish request. Prometheus alerts if that timestamp is
older than 84 hours.
