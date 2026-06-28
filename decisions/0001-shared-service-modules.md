# 0001: Keep service modules outside host directories

## Status

Accepted.

## Context

Services may move between machines. Keeping implementation below a host directory makes the
current placement look permanent and encourages duplication.

## Decision

Reusable service modules live in `services/`. Hosts import the shared module set and enable the
services they currently own. `inventory/services.yaml` records temporary and intended placement.

## Consequences

Moving a service is primarily a change to host enable flags and inventory, while the service
module and its runbooks remain stable.
