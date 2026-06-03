#!/usr/bin/env bash
# Wait for Exasol to accept real SQL connections using exapump.
# Mirrors the exarrow-rs / exapump pattern: poll via SELECT 1 over the same
# wire protocol the dbt adapters use — not just a TCP port check.
#
# Usage: ./scripts/wait_for_exasol.sh [container_name] [max_wait_seconds]
#
# Pass an empty container_name to skip the docker-ps liveness check
# (used when connecting to an external Exasol instance rather than a local Docker container).
#
# Connection is read from env vars with Docker-local defaults:
#   EXASOL_HOST (default: localhost)
#   EXASOL_PORT (default: 8563)
#   EXASOL_USER (default: sys)
#   EXASOL_PASSWORD (default: exasol)
set -euo pipefail

CONTAINER="${1-exasol}"  # ${1-default} keeps empty string; ${1:-default} would replace it
MAX_WAIT="${2:-600}"
INTERVAL=5

HOST="${EXASOL_HOST:-localhost}"
PORT="${EXASOL_PORT:-8563}"
USER="${EXASOL_USER:-sys}"
PASS="${EXASOL_PASSWORD:-exasol}"

mkdir -p ~/.exapump
cat > ~/.exapump/config.toml << EOF
[ci]
host = "${HOST}"
port = ${PORT}
user = "${USER}"
password = "${PASS}"
tls = true
validate_certificate = false
EOF

echo "Waiting for Exasol at ${HOST}:${PORT} (container: ${CONTAINER:-<external>}, timeout: ${MAX_WAIT}s)..."

elapsed=0
attempt=0

while true; do
  attempt=$((attempt + 1))

  if [[ -n "${CONTAINER}" ]]; then
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
      echo "ERROR: container '${CONTAINER}' stopped unexpectedly"
      docker logs "${CONTAINER}" 2>&1 | tail -50
      exit 1
    fi
  fi

  if exapump sql 'SELECT 1' > /dev/null 2>&1; then
    echo "Exasol is ready (attempt ${attempt}, ${elapsed}s elapsed)."
    exit 0
  fi

  if [ "${elapsed}" -ge "${MAX_WAIT}" ]; then
    echo "ERROR: Exasol not ready after ${MAX_WAIT}s"
    if [[ -n "${CONTAINER}" ]]; then
      docker logs "${CONTAINER}" 2>&1 | tail -50
    fi
    exit 1
  fi

  printf "  [%4ds] not ready yet...\n" "${elapsed}"
  sleep "${INTERVAL}"
  elapsed=$((elapsed + INTERVAL))
done
