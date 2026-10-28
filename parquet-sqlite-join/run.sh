#!/usr/bin/env bash
# Generates the fixtures (if missing) and runs every queries/*.sql through
# column-rs with the Parquet file and the SQLite file loaded side by side,
# printing each query's SQL and its output.
#
#   ./run.sh
#
# Each query carries its own check: an `-- expect: <text>` line the output
# must contain (tabs read as spaces), and `-- refused` on a query column-rs
# must refuse. Exits non-zero if any check fails.
#
# Binary resolution (../lib/tool.sh): $COLUMN_RS > a sibling tools checkout,
# built first > column-rs on PATH
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

. "$ROOT/../lib/tool.sh"
BIN="$(find_tool column-rs column-rs COLUMN_RS)"

FIXTURE="fixture"
if [ ! -f "$FIXTURE/events.parquet" ] || [ ! -f "$FIXTURE/lookups.db" ]; then
    ./fixture/generate.sh
fi

failed=0
for query in queries/*.sql; do
    name="$(basename "$query" .sql)"
    comment="$(grep '^--' "$query" | head -1 | sed 's/^-- //')"
    expect="$(grep '^-- expect: ' "$query" | sed 's/^-- expect: //' || true)"
    refused="$(grep -c '^-- refused$' "$query" || true)"
    sql="$(grep -v '^[[:space:]]*--' "$query" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')"

    echo "=== $name ==="
    echo "$comment"
    echo "> $sql"
    echo
    status=0
    out="$("$BIN" -c "$sql" "$FIXTURE/events.parquet" "$FIXTURE/lookups.db" 2>&1)" || status=$?
    echo "$out"

    if [ "$refused" = 1 ] && [ "$status" = 0 ]; then
        echo "FAIL: expected column-rs to refuse this query" >&2
        failed=1
    elif [ "$refused" = 0 ] && [ "$status" != 0 ]; then
        echo "FAIL: column-rs exited $status" >&2
        failed=1
    elif [ -n "$expect" ] && ! tr '\t' ' ' <<<"$out" | grep -qF -- "$expect"; then
        echo "FAIL: output does not contain '$expect'" >&2
        failed=1
    fi
    echo
done

if [ "$failed" != 0 ]; then
    echo "some checks failed" >&2
    exit 1
fi
echo "all checks passed"
