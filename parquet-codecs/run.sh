#!/usr/bin/env bash
# Parquet codecs across writers and readers (db-core#622).
#
# The same event table is written uncompressed, Snappy and zstd, once by
# db-core's writer (writer/) and once by DuckDB, and every one of the six
# files is read by column-rs and by DuckDB. Every reader must give the
# same answer for every file, and each file must carry the codec it was
# written with. Exits non-zero on the first mismatch.
#
# Then it times a free-text search that must scan every record (a
# LIKE '%...%' on the text column: no statistics can skip a row group),
# per file and per reader, with hyperfine (skipped if it is not on PATH).
#
#   ./run.sh            (ROWS=200000, RUNS=10 by default)
#   ROWS=2000000 ./run.sh   for timings dominated by the scan, not startup
#
# column-rs is resolved as in ../column-rs/run.sh: $COLUMN_RS, then
# `column-rs` on $PATH, then ../../tools/target/release/column-rs.
#
# Output is coloured on a terminal (or with FORCE_COLOR=1); NO_COLOR=1, or
# a pipe, keeps it plain.
set -euo pipefail

if { [ -t 1 ] || [ -n "${FORCE_COLOR:-}" ]; } && [ -z "${NO_COLOR:-}" ]; then
    BOLD=$'\e[1m' DIM=$'\e[2m' RED=$'\e[31m' GREEN=$'\e[32m'
    YELLOW=$'\e[33m' BLUE=$'\e[34m' CYAN=$'\e[36m' RESET=$'\e[0m'
else
    BOLD='' DIM='' RED='' GREEN='' YELLOW='' BLUE='' CYAN='' RESET=''
fi
# Section header, progress line, and an error that ends the run.
header() { printf '\n%s%s== %s%s\n' "$BOLD" "$CYAN" "$*" "$RESET"; }
step() { printf '%s> %s%s\n' "$DIM" "$*" "$RESET"; }
die() { printf '%serror:%s %s\n' "$RED$BOLD" "$RESET" "$*" >&2; exit 1; }
# A codec name padded to 13 columns, coloured by codec.
codec_cell() {
    local colour
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
        zstd) colour="$CYAN" ;;
        snappy) colour="$YELLOW" ;;
        *) colour="$DIM" ;;
    esac
    printf '%s%-13s%s' "$colour" "$1" "$RESET"
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
ROWS="${ROWS:-200000}"
RUNS="${RUNS:-10}"
OUT="out"

if [ -n "${COLUMN_RS:-}" ]; then
    BIN="$COLUMN_RS"
elif command -v column-rs >/dev/null 2>&1; then
    BIN="$(command -v column-rs)"
else
    BIN="$ROOT/../../tools/target/release/column-rs"
fi
[ -x "$BIN" ] || die "no column-rs binary at '$BIN' (build it: cd ../../tools && cargo build --release -p column-rs)"
command -v duckdb >/dev/null 2>&1 || die "duckdb not found on PATH"

step "building the db-core writer"
(cd writer && { cargo build --release -q 2>/dev/null || cargo build --release; })
rm -rf "$OUT" && mkdir -p "$OUT"

step "writing $ROWS rows with db-core and DuckDB"
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
header "codecs: 6 files, ${#QUERIES[@]} queries, column-rs and DuckDB"
printf '%s%-29s %-13s %10s  %s%s\n' "$BOLD" file codec bytes "readers agree" "$RESET"
for writer in db_core duckdb; do
    for codec in uncompressed snappy zstd; do
        table="${writer}_${codec}"
        file="$OUT/$table.parquet"
        stored="$(duckdb -noheader -list -c "SELECT string_agg(DISTINCT compression, ',') FROM parquet_metadata('$file')")"
        want="$(echo "$codec" | tr '[:lower:]' '[:upper:]')"
        if [ "$stored" != "$want" ]; then
            printf '%sMISMATCH%s %s stores %s, expected %s\n' "$RED$BOLD" "$RESET" "$file" "$stored" "$want"
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
                    printf '%sMISMATCH%s %s: %s\n' "$RED$BOLD" "$RESET" "$file" "$q"
                    printf '  %sexpected:%s %s\n' "$DIM" "$RESET" "$ref"
                    printf '  %sgot:     %s %s%s%s\n' "$DIM" "$RESET" "$RED" "$got" "$RESET"
                    agree=no
                    fail=1
                fi
            done
        done
        if [ "$agree" = yes ]; then agree="${GREEN}yes${RESET}"; else agree="${RED}${BOLD}no${RESET}"; fi
        printf '%-29s %s %10s  %s\n' "$table.parquet" "$(codec_cell "$stored")" "$(wc -c <"$file" | tr -d ' ')" "$agree"
    done
done
echo
if [ "$fail" -ne 0 ]; then
    printf '%sFAILED%s: a reader disagreed or a codec was not recorded\n' "$RED$BOLD" "$RESET"
    exit 1
fi
printf '%sok%s: 6 files x %s queries, column-rs and DuckDB agree\n' "$GREEN$BOLD" "$RESET" "${#QUERIES[@]}"

# --- Read timings: a full-scan free-text search -----------------------------

SEARCHES=(
    "SELECT count(*) FROM T WHERE note LIKE '%host 42%'"
    "SELECT id, user_name FROM T WHERE note LIKE '%request 1999%' ORDER BY id"
)
if ! command -v hyperfine >/dev/null 2>&1; then
    echo
    printf '%s(read timings skipped: hyperfine not on PATH)%s\n' "$YELLOW" "$RESET"
    exit 0
fi
# The median of $RUNS runs of one command, in milliseconds.
median_ms() {
    hyperfine -N -w 2 -r "$RUNS" --export-json "$OUT/t.json" "$1" >/dev/null 2>&1
    python3 -c 'import json,sys; print("%.1f" % (json.load(open(sys.argv[1]))["results"][0]["median"] * 1e3))' "$OUT/t.json"
}
for search in "${SEARCHES[@]}"; do
    header "read timings, median of $RUNS runs (ms)"
    printf '%s%s%s\n' "$DIM" "$search" "$RESET"
    printf '%s%-29s %-13s %10s %10s%s\n' "$BOLD" file codec column-rs DuckDB "$RESET"
    for writer in db_core duckdb; do
        for codec in uncompressed snappy zstd; do
            table="${writer}_${codec}"
            file="$OUT/$table.parquet"
            file_from="FROM '$file'"
            rs_sql="${search//FROM T/FROM $table}"
            duck_sql="${search//FROM T/$file_from}"
            # Both readers must find the same rows before they are timed.
            ours="$("$BIN" -c "$rs_sql" "$file" | tail -n +2 | tr '\t' ',')"
            theirs="$(duckdb -csv -noheader -c "$duck_sql")"
            if [ "$ours" != "$theirs" ]; then
                printf '%sMISMATCH%s %s: %s\n' "$RED$BOLD" "$RESET" "$file" "$search"
                exit 1
            fi
            rs_ms="$(median_ms "$BIN -c \"$rs_sql\" $file")"
            duck_ms="$(median_ms "duckdb -c \"$duck_sql\"")"
            # The faster reader of the row in green.
            rs_cell="$(printf '%10s' "$rs_ms")" duck_cell="$(printf '%10s' "$duck_ms")"
            if awk "BEGIN { exit !($rs_ms <= $duck_ms) }"; then
                rs_cell="$GREEN$rs_cell$RESET"
            else
                duck_cell="$GREEN$duck_cell$RESET"
            fi
            printf '%-29s %s %s %s\n' "$table.parquet" "$(codec_cell "$codec")" "$rs_cell" "$duck_cell"
        done
    done
done
