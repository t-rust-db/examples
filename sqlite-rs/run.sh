#!/usr/bin/env bash
# Generates the fixture (if missing) and runs every queries/*.sql against
# sqlite-rs, printing each query's SQL and its output.
#
#   ./run.sh
#
# ## Which sqlite-rs binary?
#
# Resolved in the same order as ../column-rs/run.sh:
#   1. $SQLITE_RS                                        -- explicit path
#   2. `sqlite-rs` on $PATH                               -- installed build
#   3. ../../sqlite-rs/target/release/sqlite-rs           -- t-rust-db/sqlite-rs
#      built in place, the normal case when this examples repo is checked
#      out as a sibling of sqlite-rs under t-rust-db/
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [ -n "${SQLITE_RS:-}" ]; then
    BIN="$SQLITE_RS"
elif command -v sqlite-rs >/dev/null 2>&1; then
    BIN="$(command -v sqlite-rs)"
else
    BIN="$ROOT/../../sqlite-rs/target/release/sqlite-rs"
fi

if [ ! -x "$BIN" ]; then
    echo "error: no sqlite-rs binary found at '$BIN'" >&2
    echo "  set \$SQLITE_RS to an explicit binary path, or put sqlite-rs on \$PATH," >&2
    echo "  or build it in place: (cd ../../sqlite-rs && cargo build --release --bin sqlite-rs)" >&2
    exit 1
fi

FIXTURE="fixture/movies.db"
if [ ! -f "$FIXTURE" ]; then
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
    "$BIN" query "$FIXTURE" "$sql"
    echo
done
