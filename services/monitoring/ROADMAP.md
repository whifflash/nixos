# Icarus monitoring roadmap

This document tracks the remaining monitoring work for Icarus. It is ordered by
operational dependency rather than by subsystem: first prove alert delivery,
then monitor the monitoring path, normalize alert policy, and only then expand
MQTT, inverter, and photovoltaic coverage.

The implementation should remain declarative, use native NixOS module
interfaces where practical, and keep each change independently reviewable.
Documentation, validation, and rollback notes belong in every work package
rather than being deferred until the end.

## Current baseline

The repository already provides:

- Prometheus and Alertmanager;
- Grafana with a provisioned Icarus dashboard;
- node exporter and blackbox exporter;
- host, service, storage, backup, and housekeeping monitoring;
- authenticated MQTT round-trip and topic-freshness probes;
- an Alertmanager-to-ntfy bridge;
- severity-specific ntfy topics and phone notifications.

Alert delivery is deployed and has been validated end to end. Manual and
scheduled synthetic critical alerts reached the `icarus-critical` topic and the
phone client, including while the phone was away from the home network. The
remaining work starts with baseline inventory and monitoring the notification
path itself.

## Stage 0 — Capture and validate the baseline

### Goal

Make the deployed monitoring configuration auditable before changing its alert
semantics.

### Work

- inventory every Prometheus alert rule, scrape target, blackbox target,
  monitored systemd unit, backup, housekeeping job, and MQTT topic;
- record each alert's expression, `for` duration, severity, labels,
  annotations, and intended remediation;
- record the effective Alertmanager route tree, grouping labels, timing values,
  inhibition rules, and `send_resolved` behavior;
- add static validation for Prometheus configuration and rule files;
- ensure the checked-in repository matches the configuration deployed on
  Icarus.

### Completion criteria

- every alert and target is accounted for;
- the current notification policy is documented;
- repository checks reject invalid Prometheus rules or configuration;
- the repository is the authoritative description of the deployed state.

## Stage 1 — Validate end-to-end alert delivery

**Status: completed on 2026-07-05.**

### Goal

Prove that alerts travel reliably from Prometheus through Alertmanager and the
bridge to the correct ntfy topic and phone client.

### Implemented design

The repository provides a controlled textfile-collector test metric and matching
Prometheus alert rule. Tests can be fired and resolved without disrupting a
production service or rebuilding Icarus.

The scheduled canary runs at 10:00 local time on Wednesday and Sunday. It sends
a passive critical notification and requires no acknowledgement or response.
The schedule deliberately covers a time when the phone is commonly away from
the home network.

A direct Alertmanager webhook payload remains useful for isolating the bridge,
but it does not test Prometheus rule evaluation and is not the primary
end-to-end test.

### Validation completed

- the synthetic metric was exposed by node exporter;
- Prometheus scraped the metric and evaluated `MonitoringTestAlert`;
- Alertmanager received the firing alert and selected the ntfy receiver;
- the bridge published the alert to `icarus-critical`;
- manual critical alerts reached the phone;
- scheduled critical alerts reached the phone;
- scheduled alerts reached the phone while it was away from the home network;
- test state could be inspected and removed with the supplied command.

During validation, a mismatch between the bridge's plaintext ntfy password and
ntfy's stored bcrypt hash caused `401 Unauthorized` responses. Alertmanager
retries then triggered ntfy's authentication-failure rate limit and produced
`429 Too Many Requests`. Regenerating the hash from the same password and
redeploying restored delivery. This failure mode should be covered by the
notification-path monitoring and runbook work.

### Remaining policy checks

The delivery path itself is proven. The following policy details are deferred to
Stages 3 and 4, where the complete alert set and routing model will be reviewed
together:

- warning and info topic routing;
- resolved-notification policy;
- grouping readability;
- repeat intervals;
- missing or unknown severity behavior;
- bridge error handling and concise logging for upstream HTTP failures.

### Completion criteria

- [x] tests do not require breaking a production service;
- [x] a manual synthetic critical alert reaches `icarus-critical`;
- [x] a scheduled synthetic critical alert reaches `icarus-critical`;
- [x] the phone receives the scheduled alert outside the home network;
- [x] test state can be inspected and cleanly removed;
- [x] the principal credential failure mode is understood and documented.

## Stage 2 — Monitor the notification path

**Status: completed on 2026-07-05.**

### Goal

Prevent the monitoring and notification system from failing silently.

### Work

Monitor:

- [x] Prometheus self-scrape and rule-evaluation failures;
- [x] Alertmanager availability;
- [x] Alertmanager-to-ntfy bridge scrape health and ntfy publish failures;
- [x] the Alertmanager-to-ntfy bridge service and restart behavior;
- [x] the ntfy systemd service and HTTP endpoint;
- [x] nginx service health and the ntfy HTTPS endpoint;
- [x] the age of the last successful automated alert-path canary.

Use two distinct checks:

1. an automated server-path canary that proves acceptance through Prometheus,
   Alertmanager, the bridge, and ntfy;
2. a periodic human test that confirms actual phone reception.

An ntfy outage cannot be reported through ntfy itself. The failure must remain
visible through local Prometheus, Alertmanager, Grafana, and systemd diagnostics.
A second independent notification channel is intentionally out of scope while
ntfy remains the only notification channel.

### Implemented design

Prometheus now scrapes itself, Alertmanager, and the local
Alertmanager-to-ntfy bridge. The bridge exposes a small Prometheus endpoint with
notification counters, failed ntfy publish attempts, the last successful publish
timestamp, and the last successful scheduled canary publish timestamp.

The node exporter systemd collector includes the monitoring and notification
units, so existing failed-unit alerting covers Prometheus, Alertmanager, the
bridge, ntfy, nginx, exporters, and the monitoring timers. Blackbox probing
continues to cover the public ntfy HTTPS endpoint and therefore exercises nginx,
TLS, and the ntfy HTTP service from the host.

The scheduled canary remains the automated server-path check. A successful
canary timestamp means Prometheus fired the canary alert, Alertmanager delivered
it to the bridge, and ntfy accepted the publish request. Phone reception is
still validated by the separate human observation test described in
`ALERT-TESTING.md`.

### Completion criteria

- [x] failures in Prometheus, Alertmanager, the bridge, nginx, or ntfy are visible
      locally;
- [x] rule-evaluation failures are surfaced;
- [x] the last successful canary time is visible;
- [x] a fallback diagnostic procedure exists for an ntfy outage;
- [x] deployed canary observation confirms the success timestamp updates.

## Stage 3 — Review and normalize alert rules

**Status: completed on 2026-07-05.**

### Goal

Make every alert actionable, consistently labelled, and understandable on a
phone.

### Severity policy

#### Critical

Use only when there is active or imminent meaningful impact, prompt intervention
is required, and waiting until normal maintenance would be unacceptable.

#### Warning

Use for real degradation or developing risk that requires intervention but does
not demand immediate action.

#### Info

Use sparingly. Events with no useful action generally belong in a dashboard,
log, or periodic report instead of Alertmanager.

### Labels

Standardize only labels that support routing, grouping, inhibition, filtering,
or diagnosis:

```text
severity
host
service
component
category
```

Do not add an `owner` label unless responsibility is genuinely shared between
multiple people or teams.

Suggested categories include:

```text
availability
backup
storage
network
mqtt
home-automation
energy
security
maintenance
notification
```

### Annotations

Where useful, alerts should provide:

```text
summary
description
runbook_url
dashboard_url
```

Summaries must be concise enough for phone notifications. Descriptions should
state the condition, duration, impact, and useful context rather than merely
repeat raw metric output.

### Work

- review every existing alert against the severity policy;
- reconsider alerts that classify every target or first failure as critical;
- distinguish transient failures from prolonged outages;
- remove redundant and non-actionable alerts;
- add remediation guidance for every critical alert;
- add rule tests for thresholds, `for` durations, recovery, and missing-series
  behavior where relevant.

### Alert inventory for severity review

This table records the selected severities. `MonitoringTestAlert` inherits the
severity passed to the test command; `MonitoringDeliveryCanary` uses the
configured canary severity.

| Alert                              | Severity   | Duration | Category / area | Condition summary                                         | Notes     |
| ---------------------------------- | ---------- | -------: | --------------- | --------------------------------------------------------- | --------- |
| `FilesystemSpaceLow`               | warning    |      15m | storage         | non-temporary filesystem has less than 10% free space     |           |
| `FilesystemInodesLow`              | warning    |      15m | storage         | non-temporary filesystem has less than 10% free inodes    |           |
| `MemoryPressure`                   | warning    |      15m | host            | available memory remains below 10%                        |           |
| `HostTemperatureHigh`              | warning    |      10m | host            | highest hardware temperature sensor remains above 85 C    |           |
| `SystemdUnitFailed`                | warning    |       5m | availability    | a monitored systemd unit is failed                        |           |
| `ZigbeeCoordinatorMissing`         | warning    |       5m | home-automation | configured Zigbee coordinator device path is absent       |           |
| `SystemProfileNotActive`           | info       |      15m | maintenance     | active system differs from the current system profile     |           |
| `ServiceProbeFailed`               | warning    |       5m | availability    | HTTP or TCP blackbox probe is failing                     |           |
| `BackupFailed`                     | warning    |      15m | backup          | last recorded backup run did not succeed                  |           |
| `BackupStale`                      | warning    |      15m | backup          | no completed backup has been recorded for 36 hours        |           |
| `HousekeepingFailed`               | warning    |      15m | maintenance     | last housekeeping run failed                              |           |
| `HousekeepingStale`                | warning    |      30m | maintenance     | no completed housekeeping run for eight days              |           |
| `MqttRoundtripFailed`              | warning    |       5m | mqtt            | authenticated publish/subscribe round trip is failing     |           |
| `MqttTopicStale`                   | warning    |       5m | mqtt            | monitored MQTT topic has no message for five minutes      |           |
| `MqttTopicUnhealthy`               | warning    |       5m | mqtt            | monitored MQTT topic is missing or has unhealthy payload  |           |
| `PvInverterPayloadInvalid`         | warning    |       5m | energy          | inverter MQTT state payload is not valid JSON             |           |
| `PvInverterTelemetryStale`         | warning    |       5m | energy          | inverter payload timestamp is older than 15 minutes       |           |
| `PvInverterFault`                  | warning    |       5m | energy          | inverter reports explicit fault state                     |           |
| `PvEnergyTotalDecreased`           | warning    |       5m | energy          | lifetime energy counter decreased over 30 minutes         |           |
| `MonitoringMetricsStale`           | warning    |       5m | notification    | repository-specific textfile metrics stopped updating     |           |
| `PrometheusSelfScrapeDown`         | warning    |       5m | notification    | Prometheus cannot scrape itself                           |           |
| `PrometheusRuleEvaluationFailures` | warning    |       5m | notification    | Prometheus rule evaluations failed in the last 15 minutes |           |
| `PrometheusTargetDown`             | warning    |       5m | notification    | Alertmanager or the ntfy bridge cannot be scraped         |           |
| `AlertmanagerNtfyPublishFailures`  | warning    |       5m | notification    | bridge failed to publish notifications to ntfy            |           |
| `MonitoringDeliveryCanaryStale`    | warning    |      30m | notification    | no successful scheduled canary publish for 84 hours       |           |
| `MonitoringTestAlert`              | variable   |      30s | notification    | manually fired synthetic alert is active                  | test-only |
| `MonitoringDeliveryCanary`         | configured |      30s | notification    | scheduled synthetic canary reached Alertmanager           | test-only |

### Completion criteria

- every alert has a justified severity;
- critical alerts are reserved for conditions that require prompt attention;
- alert names and summaries are understandable without opening Prometheus;
- noisy or redundant alerts are removed.

## Stage 4 — Improve routing, grouping, inhibition, and maintenance handling

**Status: completed on 2026-07-05.**

### Goal

Keep notifications stable and predictable without adding unnecessary handling
process.

### Notification policy

Alerts are routed to severity-specific ntfy topics. Repeats are intentionally
minimal:

| Severity | Repeat interval |
| -------- | --------------: |
| Critical |          1 hour |
| Warning  |          1 week |
| Info     |      no repeats |

The Alertmanager route groups alerts by alert name and severity. No separate
notification channel is planned while ntfy remains reliable enough for this
system.

### Inhibition

No inhibition rules are currently implemented. Add one later only when a real
alert cascade proves it is needed.

### Completion criteria

- [x] critical alerts repeat hourly;
- [x] warning alerts repeat weekly;
- [x] info alerts do not repeat in normal operation;
- [x] alerts are grouped by alert name and severity.

## Stage 5 — Complete MQTT and inverter observability

**Status: postponed.**

### Goal

Keep the option open to add deeper MQTT and inverter transport diagnostics, but
do not implement them preemptively.

The current availability is high enough that the full fault-domain model is not
justified. Revisit this only if real incidents show that the existing MQTT
round-trip, topic freshness, systemd, and service-probe alerts are not enough to
identify or recover from failures.

### Completion criteria

- [ ] a recurring or hard-to-diagnose MQTT or inverter incident demonstrates
      that deeper observability is necessary.

## Stage 6 — Add conservative PV health monitoring

**Status: in progress.**

### Goal

Detect inverter and photovoltaic faults without creating night-time or
weather-driven false positives.

### Implementation order

1. identify the MQTT fields already available for inverter status, event or
   fault indicators, current power, energy counters, and timestamps;
2. expose simple derived textfile metrics from the existing retained MQTT
   payloads;
3. alert on explicit inverter fault or warning states first;
4. add counter-continuity checks for daily and lifetime energy;
5. add a daylight gate and only then check daylight inverter availability;
6. add conservative production plausibility after the status and counter checks
   have been stable for a while;
7. defer comparative performance until there is enough local history to avoid
   noisy weather and seasonality assumptions.

### Design constraints

A simple `power == 0` alert is invalid because production depends on night,
sunrise and sunset, season, weather, shading, and planned shutdowns.

Begin with a conservative daylight gate based on a reliable sun-elevation or
sunrise/sunset source. Production anomaly checks should:

- require fresh telemetry;
- operate only during a meaningful daylight window;
- use long persistence intervals;
- suppress during known inverter faults or planned shutdowns;
- begin as warnings until their reliability is proven.

Prefer relative or historical comparisons over hard-coded wattage thresholds.
Weather-adjusted models should remain later work unless reliable irradiance or
cloud data is available.

### Suggested first work package

Start with observability that should be true regardless of weather:

- [x] document the exact inverter MQTT payload fields currently published;
- [x] add a small parser that emits status, current power, lifetime energy,
      event bitmask, payload validity, and payload timestamp metrics;
- [x] alert when the inverter reports explicit `fault` state;
- [x] alert when lifetime energy decreases;
- [x] alert when the retained JSON payload is invalid or stale;
- [ ] add decoded fault-code metrics if the raw SunSpec event bitmask proves
      useful enough to decode;
- [ ] add daily energy checks if the collector starts publishing a daily energy
      counter;
- [ ] add a compact dashboard section showing current status, event bitmask,
      current power, and lifetime energy.

### Suggested second work package

Add daylight-aware checks after the basic metrics have proven stable:

- choose a simple sun source for Icarus' location;
- emit a boolean daylight metric with a conservative elevation threshold;
- require daylight and fresh telemetry for every production-related alert;
- warn if the inverter is unavailable for a sustained daylight window;
- warn if production remains zero during a long daylight window while the
  inverter reports no explicit fault.

### Topic policy

Reuse the main severity topics while the same user receives all infrastructure
alerts. Add PV-specific topics only when a separate audience needs PV alerts
without access to unrelated infrastructure notifications.

### Completion criteria

- no night-time zero-production alerts occur;
- explicit inverter faults are visible;
- stale telemetry and inverter unavailability remain distinct;
- production anomaly alerts are conservative and diagnostically useful.

## Stage 7 — Consolidate dashboard usability

### Goal

Make Grafana useful for rapid diagnosis on both phone and laptop.

Feature-specific panels should be added with their corresponding monitoring
work. This stage is the final usability and consistency pass.

### Work

- fix the backup table so data is joined by the `backup` label;
- replace raw series labels such as `#A` and `#B` with readable fields;
- display backup result, last-run age, and duration with appropriate mappings
  and units;
- align panel terminology with alert names;
- add links from alerts to relevant dashboards or panels;
- use consistent units and thresholds;
- remove panels that do not support an operational decision;
- add a notification-path section;
- split the dashboard if one large page becomes an obstacle to diagnosis.

Possible dashboard boundaries are:

1. Icarus overview;
2. host and storage;
3. backups and housekeeping;
4. MQTT and inverter/PV;
5. monitoring and notification path.

### Completion criteria

- a phone or laptop view quickly reveals the failing component;
- an alert reaches relevant evidence in one interaction;
- backup status is readable;
- notification-system health is visible.

## Stage 8 — Consolidate the operations runbook

### Goal

Make the system maintainable without reconstructing its architecture from Nix
source or previous chat history.

Documentation should be updated during every stage. This final stage audits and
consolidates it.

### Runbook coverage

- architecture and data flow;
- ports and hostnames;
- secret names without secret values;
- ntfy password hash generation;
- adding users, topics, and ACLs;
- phone setup;
- deterministic alert testing;
- viewing alerts and creating safe silences;
- Prometheus, Alertmanager, bridge, ntfy, and MQTT troubleshooting;
- state, backup, and restore considerations;
- rollback to a previous NixOS generation;
- recovery from stale systemd state directories where still relevant.

### Completion criteria

- a new user and topic can be added declaratively;
- common failures have concrete diagnostic commands;
- rollback and recovery procedures have been exercised;
- no undocumented manual provisioning is required.

## Deferred work

### Home Assistant API integration

Defer until the current notification path and monitoring stages are stable.
Future scope may include a least-privilege token, API health, selected entity
states, automation health, integration availability, device freshness, and
battery monitoring.

### Zigbee health model

This depends on Home Assistant API access or another reliable telemetry source.
Future work should distinguish mains-powered routers from battery devices and
apply device-class-specific freshness and battery thresholds.

### External Icarus reachability

Prometheus running on Icarus cannot independently report that Icarus itself is
unreachable. A later deployment should probe it from another device or an
independent monitoring location.

## Patch and validation rules

For every future work package:

- use the newest uploaded repository archive as the sole source of truth;
- never assume an earlier patch has been applied;
- inspect the exact target files before editing;
- generate patches from an extracted repository rather than handwritten
  context;
- verify against a second fresh extraction of the same archive;
- run `git apply --check` and `git diff --check`;
- run Nix evaluation or a build when Nix is available;
- do not claim build validation when it was not performed;
- run relevant Prometheus, Python, JSON, and shell validation;
- keep Nix code linter-friendly;
- prefer native NixOS module interfaces and declarative configuration;
- keep patches small enough to review and roll back independently.

## Recommended patch sequence

1. baseline inventory and static validation;
2. deterministic end-to-end alert tests;
3. notification-path metrics and alerts;
4. alert-label, annotation, and severity normalization;
5. routing and grouping policy;
6. PV payload inventory and derived metrics;
7. explicit inverter fault-state monitoring;
8. PV counter-continuity checks;
9. daylight-aware availability and production checks;
10. dashboard consolidation;
11. runbook and recovery audit.
