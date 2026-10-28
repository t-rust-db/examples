#!/usr/bin/env bash
# Generates the fixture (if missing) and runs every queries/*.sql against
# column-rs, printing each query's SQL and its output.
#
#   ./run.sh
#
# Binary resolution (../lib/tool.sh): $COLUMN_RS > a sibling tools checkout,
# built first > column-rs on PATH
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

. "$ROOT/../lib/tool.sh"
BIN="$(find_tool column-rs column-rs COLUMN_RS)"

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
