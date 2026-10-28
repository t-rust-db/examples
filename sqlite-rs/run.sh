#!/usr/bin/env bash
# Generates the fixture (if missing) and runs every queries/*.sql against
# sqlite-rs, printing each query's SQL and its output.
#
#   ./run.sh
#
# ## Which sqlite-rs binary?
#
# Resolved newest first, as in ../column-rs/run.sh:
#   1. $$SQLITE_RS                                       -- explicit path
#   2. ../../tools/target/release/sqlite-rs, built first when t-rust-db/tools
#      is checked out next to this examples repo (only what changed)
#   3. `sqlite-rs` on $PATH                              -- installed build
# (../lib/tool.sh); it prints the version it uses.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

. "$ROOT/../lib/tool.sh"
BIN="$(find_tool sqlite-rs sqlite-rs SQLITE_RS)"

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
