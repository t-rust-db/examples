#!/usr/bin/env bash
# Parquet codecs across writers and readers (db-core#622).
#
# The same event table is written uncompressed, Snappy and zstd, once by
# db-core's writer (writer/) and once by DuckDB, and every one of the six
# files is read by column-rs and by DuckDB. Every reader must give the
# same answer for every file, and each file must carry the codec it was
# written with. Exits non-zero on the first mismatch.
#
#   ./run.sh            (ROWS=200000 by default)
#
# column-rs is resolved as in ../column-rs/run.sh: $COLUMN_RS, then
# `column-rs` on $PATH, then ../../tools/target/release/column-rs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
ROWS="${ROWS:-200000}"
OUT="out"

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
rm -rf "$OUT" && mkdir -p "$OUT"

echo "writing $ROWS rows with db-core and DuckDB..."
writer/target/release/parquet-codecs-writer "$OUT" "$ROWS"
for codec in uncompressed snappy zstd; do
    duckdb -batch -c "
        COPY (
            SELECT
                i AS id,
                TIMESTAMP '2026-10-21 00:00:00' + to_seconds(i) AS ts,
                ['login', 'search', 'view', 'checkout', 'logout'][i % 5 + 1] AS kind,
                'user-' || (i * 7919 % 10007) AS user_name,
                CASE WHEN i % 3 = 0 THEN NULL ELSE i * 37 % 1000 END AS amount,
                CASE WHEN i % 4 = 0 THEN NULL ELSE 'request ' || i || ' from host ' || (i % 97) END AS note
            FROM range($ROWS) t(i)
        ) TO '$OUT/duckdb_$codec.parquet' (FORMAT parquet, COMPRESSION $codec)"
done

# The queries, with T for the table (column-rs names a file's table after
# its stem). "DUCKDB||COLUMN_RS" gives each reader its own SQL for one
# answer: column-rs prints a timestamp aggregate as epoch microseconds.
QUERIES=(
    "SELECT count(*), count(amount), sum(amount), min(id), max(id) FROM T"
    "SELECT kind, count(*), sum(amount), count(note) FROM T GROUP BY kind ORDER BY kind"
    "SELECT count(*) FROM T WHERE note IS NULL"
    "SELECT user_name, count(*) FROM T WHERE kind = 'checkout' GROUP BY user_name ORDER BY user_name LIMIT 5"
    "SELECT epoch_us(min(ts)), epoch_us(max(ts)) FROM T||SELECT min(ts), max(ts) FROM T"
)

fail=0
echo
printf '%-29s %-13s %10s  %s\n' file codec bytes "readers agree"
for writer in db_core duckdb; do
    for codec in uncompressed snappy zstd; do
        table="${writer}_${codec}"
        file="$OUT/$table.parquet"
        stored="$(duckdb -noheader -list -c "SELECT string_agg(DISTINCT compression, ',') FROM parquet_metadata('$file')")"
        want="$(echo "$codec" | tr '[:lower:]' '[:upper:]')"
        if [ "$stored" != "$want" ]; then
            echo "MISMATCH: $file stores $stored, expected $want"
            fail=1
        fi
        agree=yes
        for entry in "${QUERIES[@]}"; do
            q="${entry%%||*}"
            q_rs="${entry##*||}"
            ref_from="FROM '$OUT/duckdb_uncompressed.parquet'"
            file_from="FROM '$file'"
            ref="$(duckdb -csv -noheader -c "${q//FROM T/$ref_from}")"
            ours="$("$BIN" -c "${q_rs//FROM T/FROM $table}" "$file" | tail -n +2 | tr '\t' ',')"
            theirs="$(duckdb -csv -noheader -c "${q//FROM T/$file_from}")"
            for got in "$ours" "$theirs"; do
                if [ "$got" != "$ref" ]; then
                    echo "MISMATCH: $file: $q"
                    echo "  expected: $ref"
                    echo "  got:      $got"
                    agree=no
                    fail=1
                fi
            done
        done
        printf '%-29s %-13s %10s  %s\n' "$table.parquet" "$stored" "$(wc -c <"$file" | tr -d ' ')" "$agree"
    done
done
echo
if [ "$fail" -ne 0 ]; then
    echo "FAILED: a reader disagreed or a codec was not recorded"
    exit 1
fi
echo "ok: 6 files x ${#QUERIES[@]} queries, column-rs and DuckDB agree"
