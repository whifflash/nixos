set -euo pipefail

: "${ALERT_ACTIVE_DURATION:?ALERT_ACTIVE_DURATION must be set}"
: "${ALERT_SEVERITY:?ALERT_SEVERITY must be set}"

test_id=scheduled-canary

cleanup() {
  infra-monitoring-test-alert resolve "$ALERT_SEVERITY" "$test_id"
}
trap cleanup EXIT INT TERM

infra-monitoring-test-alert fire "$ALERT_SEVERITY" "$test_id"
sleep "$ALERT_ACTIVE_DURATION"
