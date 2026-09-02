#!/usr/bin/env bash
# Generates the fixture (if missing) and runs every queries/*.sql against
# column-rs, printing each query's SQL and its output.
#
#   ./run.sh
#
# ## Which column-rs binary?
#
# Resolved in the same order as benchmark/parity/column-rs/run.sh:
#   1. $COLUMN_RS                                       -- explicit path
#   2. `column-rs` on $PATH                              -- installed build
#   3. ../../column-rs/target/release/column-rs          -- t-rust-db/column-rs
#      built in place, the normal case when this examples repo is checked
#      out as a sibling of column-rs under t-rust-db/
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [ -n "${COLUMN_RS:-}" ]; then
    BIN="$COLUMN_RS"
elif command -v column-rs >/dev/null 2>&1; then
    BIN="$(command -v column-rs)"
else
    BIN="$ROOT/../../column-rs/target/release/column-rs"
fi

if [ ! -x "$BIN" ]; then
    echo "error: no column-rs binary found at '$BIN'" >&2
    echo "  set \$COLUMN_RS to an explicit binary path, or put column-rs on \$PATH," >&2
    echo "  or build it in place: (cd ../../column-rs && cargo build --release)" >&2
    exit 1
fi

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
