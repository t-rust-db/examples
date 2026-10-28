#!/usr/bin/env bash
# Generates the fixture (if missing) and runs every queries/*.sql against
# column-rs, printing each query's SQL and its output.
#
#   ./run.sh
#
# ## Which column-rs binary?
#
# Resolved newest first, needing 0.32.0 or later (LIST columns):
#   1. $$COLUMN_RS                                       -- explicit path
#   2. ../../tools/target/release/column-rs, built first when t-rust-db/tools
#      is checked out next to this examples repo (only what changed)
#   3. `column-rs` on $PATH                              -- installed build
# (../lib/tool.sh); it prints the version it uses.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

. "$ROOT/../lib/tool.sh"
BIN="$(find_tool column-rs column-rs COLUMN_RS 0.32.0)"

FIXTURE="fixture"
if [ ! -f "$FIXTURE/orders.parquet" ] || [ ! -f "$FIXTURE/customers.parquet" ]; then
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
    "$BIN" -c "$sql" "$FIXTURE/orders.parquet" "$FIXTURE/customers.parquet"
    echo
done
