#!/usr/bin/env bash
# Wait for Exasol to accept real SQL connections using exapump.
# Mirrors the exarrow-rs / exapump pattern: poll via SELECT 1 over the same
# wire protocol the dbt adapters use — not just a TCP port check.
#
# Usage: ./scripts/wait_for_exasol.sh [container_name] [max_wait_seconds]
set -euo pipefail

CONTAINER="${1:-exasol}"
MAX_WAIT="${2:-600}"
INTERVAL=5

# Write exapump profile for the local Docker instance.
# validate_certificate = false because Exasol Docker uses a self-signed cert.
mkdir -p ~/.exapump
cat > ~/.exapump/config.toml << 'EOF'
[ci]
host = "localhost"
port = 8563
user = "sys"
password = "exasol"
tls = true
validate_certificate = false
EOF

echo "Waiting for Exasol (container: ${CONTAINER}, timeout: ${MAX_WAIT}s)..."

elapsed=0
attempt=0

while true; do
  attempt=$((attempt + 1))

  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "ERROR: container '${CONTAINER}' stopped unexpectedly"
    docker logs "${CONTAINER}" 2>&1 | tail -50
    exit 1
  fi

  if exapump sql 'SELECT 1' > /dev/null 2>&1; then
    echo "Exasol is ready (attempt ${attempt}, ${elapsed}s elapsed)."
    exit 0
  fi

  if [ "${elapsed}" -ge "${MAX_WAIT}" ]; then
    echo "ERROR: Exasol not ready after ${MAX_WAIT}s"
    docker logs "${CONTAINER}" 2>&1 | tail -50
    exit 1
  fi

  printf "  [%4ds] not ready yet...\n" "${elapsed}"
  sleep "${INTERVAL}"
  elapsed=$((elapsed + INTERVAL))
done
