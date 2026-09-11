#!/usr/bin/env bash
# Generates the fixtures (if missing) and launches db-studio against
# fleet.sqlite and readings.parquet as two open files.
#
#   ./run.sh
#
# Unlike ../sqlite-rs/run.sh and ../column-rs/run.sh, this doesn't loop
# over queries/*.sql and print output -- db-studio is an interactive TUI,
# not a batch query runner. Once it's open, paste any queries/*.sql query
# into the query pane (Tab cycles focus, F1 shows results). See
# ./README.md for what each open file demonstrates and the current
# cross-mode-join and .log limitations.
#
# ## Which db-studio binary?
#
# Resolved in the same order as ../sqlite-rs/run.sh and ../column-rs/run.sh:
#   1. $DB_STUDIO                                        -- explicit path
#   2. `db-studio` on $PATH                               -- installed build
#   3. ../../db-studio/target/release/db-studio           -- t-rust-db/db-studio
#      built in place, the normal case when this examples repo is checked
#      out as a sibling of db-studio under t-rust-db/
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if [ -n "${DB_STUDIO:-}" ]; then
    BIN="$DB_STUDIO"
elif command -v db-studio >/dev/null 2>&1; then
    BIN="$(command -v db-studio)"
else
    BIN="$ROOT/../../db-studio/target/release/db-studio"
fi

if [ ! -x "$BIN" ]; then
    echo "error: no db-studio binary found at '$BIN'" >&2
    echo "  set \$DB_STUDIO to an explicit binary path, or put db-studio on \$PATH," >&2
    echo "  or build it in place: (cd ../../db-studio && cargo build --release --bin db-studio)" >&2
    exit 1
fi

if [ ! -f fixture/fleet.sqlite ] || [ ! -f fixture/readings.parquet ]; then
    ./fixture/generate.sh
fi

exec "$BIN" fixture/fleet.sqlite fixture/readings.parquet
