#!/usr/bin/env bash
# A striped (tiered) table, written and read (db-core ADR 0028, #622).
#
# writer/ builds a db-core table over two days of events: each closed hour
# flushed to live/ as one file sorted by session_id and cut into row
# groups, day 0 merged into archive/, every page zstd at its fastest level.
# The table is then read two ways that must agree: column-rs over the
# table directory, and DuckDB over exactly the files its manifest lists.
# Exits non-zero on a mismatch.
#
#   ./run.sh
#
# column-rs is resolved as in ../column-rs/run.sh: $COLUMN_RS, then
# `column-rs` on $PATH, then ../../tools/target/release/column-rs. It must
# be built against db-core v0.153.0 or later, which reads manifest version
# 4 (sort-key ranges, #589).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
TABLE="out/events"

if [ -n "${COLUMN_RS:-}" ]; then
    BIN="$COLUMN_RS"
elif command -v column-rs >/dev/null 2>&1; then
    BIN="$(command -v column-rs)"
else
    BIN="$ROOT/../../tools/target/release/column-rs"
fi
[ -x "$BIN" ] || { echo "error: no column-rs binary at '$BIN' (build it: cd ../../tools && cargo build --release -p column-rs)" >&2; exit 1; }
command -v duckdb >/dev/null 2>&1 || { echo "error: duckdb not found on PATH" >&2; exit 1; }

echo "building the db-core writer..."
(cd writer && { cargo build --release -q 2>/dev/null || cargo build --release; })
mkdir -p out
writer/target/release/parquet-tiered-writer "$TABLE"

echo
echo "== layout"
(cd "$TABLE" && find live archive -name '*.parquet' | sort)

# The files the manifest lists, as a DuckDB list of paths.
FILES="$(duckdb -noheader -list -c "
    SELECT string_agg('''$TABLE/' || f.path || '''', ', ' ORDER BY f.lsn_lo)
    FROM (SELECT unnest(files) AS f FROM read_json_auto('$TABLE/manifest.json'))")"
SOURCE="read_parquet([$FILES])"

fail=0
echo
echo "== files"
duckdb -batch -c "
    SELECT regexp_extract(file_name, '(live|archive)/.*') AS file,
           count(DISTINCT row_group_id) AS row_groups,
           CAST(sum(row_group_num_rows) / count(DISTINCT column_id) AS BIGINT) AS rows,
           string_agg(DISTINCT compression, ',') AS codec
    FROM parquet_metadata([$FILES])
    GROUP BY file_name ORDER BY file_name"
codecs="$(duckdb -noheader -list -c "SELECT string_agg(DISTINCT compression, ',') FROM parquet_metadata([$FILES])")"
if [ "$codecs" != "ZSTD" ]; then
    echo "MISMATCH: pages are $codecs, expected ZSTD only"
    fail=1
fi

# "DUCKDB||COLUMN_RS" when the readers need their own SQL for one answer:
# column-rs prints a timestamp aggregate as epoch nanoseconds.
QUERIES=(
    "SELECT count(*), count(amount), sum(amount) FROM T"
    "SELECT kind, count(*), sum(amount) FROM T GROUP BY kind ORDER BY kind"
    "SELECT count(*), sum(amount) FROM T WHERE session_id = 3300"
    "SELECT session_id, count(*) FROM T WHERE session_id >= 3250 AND session_id < 3260 GROUP BY session_id ORDER BY session_id"
    "SELECT epoch_ns(min(ts)), epoch_ns(max(ts)) FROM T||SELECT min(ts), max(ts) FROM T"
)
echo
echo "== queries (column-rs over $TABLE, DuckDB over the manifest's files)"
for entry in "${QUERIES[@]}"; do
    q="${entry%%||*}"
    q_rs="${entry##*||}"
    theirs="$(duckdb -csv -noheader -c "${q//FROM T/FROM $SOURCE}")"
    if raw="$("$BIN" -c "${q_rs//FROM T/FROM events}" "$TABLE" 2>&1)"; then
        ours="$(printf '%s\n' "$raw" | tail -n +2 | tr '\t' ',')"
    else
        ours="column-rs failed: $raw"
    fi
    if [ "$ours" = "$theirs" ]; then
        echo "ok    $q_rs"
    else
        echo "DIFF  $q_rs"
        echo "  DuckDB:    $theirs"
        echo "  column-rs: $ours"
        fail=1
    fi
done
echo
if [ "$fail" -ne 0 ]; then
    echo "FAILED"
    exit 1
fi
echo "ok: live/ and archive/ read the same through column-rs and DuckDB"
