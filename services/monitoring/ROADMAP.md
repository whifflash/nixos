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

**Status: in progress.**

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
A second independent notification channel can be considered later.

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

### Remaining work

- confirm the new bridge metrics and stale-canary rule after the next deployed
  scheduled canary;
- decide whether a second independent notification channel is needed for ntfy
  outages;
- include the new notification-path alerts in the Stage 3 severity and wording
  review.

### Completion criteria

- [x] failures in Prometheus, Alertmanager, the bridge, nginx, or ntfy are visible
      locally;
- [x] rule-evaluation failures are surfaced;
- [x] the last successful canary time is visible;
- [x] a fallback diagnostic procedure exists for an ntfy outage;
- [ ] deployed canary observation confirms the new success timestamp updates.

## Stage 3 — Review and normalize alert rules

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

### Completion criteria

- every alert has a justified severity;
- every critical alert has a concrete remediation path;
- alert names and summaries are understandable without opening Prometheus;
- noisy or redundant alerts are removed;
- nontrivial PromQL rules have tests.

## Stage 4 — Improve routing, grouping, inhibition, and maintenance handling

### Goal

Turn normalized labels into a predictable notification policy.

### Initial policy to validate

The final values should be based on Stage 1 observations. A reasonable starting
point is:

| Severity | Group wait | Group interval |       Repeat interval |
| -------- | ---------: | -------------: | --------------------: |
| Critical | 10 seconds |      5 minutes |                1 hour |
| Warning  |   1 minute |     15 minutes |              12 hours |
| Info     |  5 minutes |         1 hour | 24 hours or no repeat |

Group by stable operational dimensions such as alert name, severity, host, and
service. Avoid volatile labels that unnecessarily split related notifications.

### Inhibition

Implement only relationships that are reliably causal:

- host down inhibits dependent service alerts on that host;
- Mosquitto down inhibits MQTT topic-freshness alerts;
- the inverter collector being down inhibits collector-derived telemetry
  alerts;
- ntfy down inhibits bridge-delivery symptoms where appropriate;
- a critical form of a condition inhibits its warning form.

Planned maintenance should normally use a narrow, expiring Alertmanager silence
rather than a permanent inhibition rule.

### Completion criteria

- a host or broker outage does not create a cascade of dependent alerts;
- critical alerts remain promptly visible;
- warning and info alerts are meaningfully grouped;
- repeat intervals behave as documented;
- maintenance silences are scoped, commented, and time limited.

## Stage 5 — Complete MQTT and inverter observability

### Goal

Distinguish broker, collector, transport, payload, and inverter faults instead
of treating all missing telemetry as the same problem.

### Telemetry contract

For each monitored topic, document:

- exact topic name and publisher;
- payload schema and units;
- retained-message behavior;
- expected publish interval;
- behavior when the inverter is offline or it is night;
- whether timestamps originate from the inverter, collector, or probe;
- valid ranges and explicit health or fault values.

### Collector observability

Expose and monitor:

- process state;
- recent restart increases;
- last successful inverter poll;
- last successful MQTT publish;
- transport or Modbus failures;
- payload parsing and validation failures.

A running systemd unit is not sufficient evidence that useful telemetry is
being produced.

### Fault domains

Keep these states distinguishable:

```text
broker unavailable
collector unavailable
inverter transport unavailable
telemetry stale
payload malformed
inverter explicitly unhealthy
```

### Dashboard work

Add the corresponding panels in the same work package:

- MQTT round-trip result and latency;
- last successful round trip;
- inverter topic age;
- collector last-success age and restarts;
- inverter availability and fault state.

### Completion criteria

- broker health and topic health are distinguishable;
- stale telemetry produces a useful warning;
- prolonged telemetry loss can escalate appropriately;
- the alert and dashboard identify the likely fault domain.

## Stage 6 — Add conservative PV health monitoring

### Goal

Detect inverter and photovoltaic faults without creating night-time or
weather-driven false positives.

### Implementation order

1. connectivity and telemetry freshness;
2. explicit inverter warning and fault codes;
3. lifetime and daily counter continuity;
4. daylight-aware inverter availability;
5. conservative production plausibility;
6. comparative performance only after sufficient historical data exists.

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
6. inhibition and maintenance-silence procedures;
7. MQTT telemetry contract and collector metrics;
8. inverter alerts and dashboard panels;
9. PV fault-state monitoring;
10. daylight-aware production monitoring;
11. dashboard consolidation;
12. runbook and recovery audit.
