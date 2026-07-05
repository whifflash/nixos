set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  infra-monitoring-test-alert fire <critical|warning|info> [test-id]
  infra-monitoring-test-alert resolve <critical|warning|info> [test-id]
  infra-monitoring-test-alert status

The optional test-id defaults to "manual" and may contain letters, digits,
underscores, and hyphens.
USAGE
}

action="${1:-}"
severity="${2:-}"
test_id="${3:-manual}"
output_directory=/var/lib/prometheus-node-exporter-text-files

case "$action" in
fire | resolve)
  ;;
status)
  find "$output_directory" \
    -maxdepth 1 -type f -name 'test-alert-*.prom' -print -exec cat {} \;
  exit 0
  ;;
*)
  usage >&2
  exit 2
  ;;
esac

case "$severity" in
critical | warning | info)
  ;;
*)
  printf 'invalid severity: %s\n' "$severity" >&2
  usage >&2
  exit 2
  ;;
esac

if [ -z "$test_id" ]; then
  printf 'test-id must not be empty\n' >&2
  usage >&2
  exit 2
fi

case "$test_id" in
*[!a-zA-Z0-9_-]*)
  printf 'invalid test-id: %s\n' "$test_id" >&2
  usage >&2
  exit 2
  ;;
esac

output_file="$output_directory/test-alert-$severity-$test_id.prom"

case "$action" in
fire)
  temporary_file="$output_file.tmp"
  install -d -m 0755 "$output_directory"
  printf 'infra_monitoring_test_alert{severity="%s",test_id="%s"} 1\n' \
    "$severity" "$test_id" >"$temporary_file"
  chmod 0644 "$temporary_file"
  mv "$temporary_file" "$output_file"
  printf 'fired %s test alert %s\n' "$severity" "$test_id"
  ;;
resolve)
  rm -f "$output_file" "$output_file.tmp"
  printf 'resolved %s test alert %s\n' "$severity" "$test_id"
  ;;
esac
