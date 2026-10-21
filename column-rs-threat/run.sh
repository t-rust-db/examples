#!/usr/bin/env bash
# Generates the fixture (if missing) and runs every queries/*.sql against
# column-rs, printing each query's SQL and its output.
#
#   ./run.sh
#
# Binary resolution: $COLUMN_RS > column-rs on PATH > ../../tools/target/release/column-rs
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [ -n "${COLUMN_RS:-}" ]; then
    BIN="$COLUMN_RS"
elif command -v column-rs >/dev/null 2>&1; then
    BIN="$(command -v column-rs)"
else
    BIN="$ROOT/../../tools/target/release/column-rs"
fi

if [ ! -x "$BIN" ]; then
    echo "error: no column-rs binary found at '$BIN'" >&2
    echo "  set \$COLUMN_RS to an explicit binary path, or put column-rs on \$PATH," >&2
    echo "  or build it in place: (cd ../../tools && cargo build --release -p column-rs)" >&2
    exit 1
fi

FIXTURE="fixture"
if [ ! -f "$FIXTURE/events.parquet" ] || [ ! -f "$FIXTURE/blacklist.parquet" ]; then
    ./fixture/generate.sh
fi

for query in queries/*.sql; do
    name="$(basename "$query" .sql)"
    comment="$(grep '^--' "$query" | head -1 | sed 's/^-- //')"
    sql="$(grep -v '^[[:space:]]*--' "$query" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')"

    echo "=== $name ==="
    echo "$comment"
    echo "> $sql"
    echo
    "$BIN" -c "$sql" "$FIXTURE/events.parquet" "$FIXTURE/blacklist.parquet"
    echo
done
