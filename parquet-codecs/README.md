# Parquet codecs example

One event table written **uncompressed, Snappy and zstd** by two writers,
db-core's Parquet writer and DuckDB, and every file read back by two
readers, [column-rs](https://github.com/t-rust-db/tools/tree/main/column-rs)
and DuckDB. The six files must give the same answers to the same queries,
and each must record the codec it was written with (db-core#622).

## The table

`ROWS` events (200 000 by default), built from the row number `i` by the
same formulas in both writers (`writer/src/main.rs` and the DuckDB `COPY`
in `run.sh`):

| column | type | value |
|---|---|---|
| `id` | BIGINT | `i` |
| `ts` | TIMESTAMP (µs) | 2026-10-21 00:00:00 + `i` seconds |
| `kind` | VARCHAR | one of five event names, cycling |
| `user_name` | VARCHAR | `user-<i·7919 mod 10007>` |
| `amount` | BIGINT, nullable | `i·37 mod 1000`, NULL every 3rd row |
| `note` | VARCHAR, nullable | free text, NULL every 4th row |

## Running

```bash
./run.sh                 # ROWS=200000, RUNS=10
ROWS=2000000 ./run.sh    # timings dominated by the scan, not process start
```

Output is coloured on a terminal: passes green, mismatches red, codecs by
codec, and the faster reader of each timing row green. `NO_COLOR=1` turns
it off; `FORCE_COLOR=1` keeps it on in a pipe or CI log.

It builds `writer/` (a small program over db-core's writer; db-core is
expected as a sibling checkout, `../../db-core`), writes the six files
into `out/`, checks each file's codec with DuckDB's `parquet_metadata`, and
runs every query through column-rs and DuckDB on every file. A reader that
disagrees with DuckDB on DuckDB's uncompressed file fails the run.

Then it times a **free-text search that scans every record**, a
`LIKE '%…%'` on `note`, which no statistics can prune, through both readers
on all six files with [hyperfine](https://github.com/sharkdp/hyperfine)
(median of `RUNS`; skipped if hyperfine is not on `PATH`). Both readers must
find the same rows before they are timed.

column-rs is found as in `../column-rs/`: `$COLUMN_RS`, `column-rs` on
`$PATH`, or `../../tools/target/release/column-rs`.

## Output

```
file                          codec              bytes  readers agree
db_core_uncompressed.parquet  UNCOMPRESSED     8668471  yes
db_core_snappy.parquet        SNAPPY           3993486  yes
db_core_zstd.parquet          ZSTD             2609648  yes
duckdb_uncompressed.parquet   UNCOMPRESSED     8710036  yes
duckdb_snappy.parquet         SNAPPY           3584361  yes
duckdb_zstd.parquet           ZSTD             1227144  yes

ok: 6 files x 5 queries, column-rs and DuckDB agree
```

Read timings at `ROWS=2000000` (Apple M-series, warm page cache; process
start included):

```
== read timings, median of 10 runs (ms): SELECT count(*) FROM T WHERE note LIKE '%host 42%'
file                          codec          column-rs     DuckDB
db_core_uncompressed.parquet  uncompressed        95.3       21.0
db_core_snappy.parquet        snappy              95.2       21.8
db_core_zstd.parquet          zstd               102.0       23.5
duckdb_uncompressed.parquet   uncompressed        86.9       20.9
duckdb_snappy.parquet         snappy              86.4       21.8
duckdb_zstd.parquet           zstd                93.9       21.4

== read timings, median of 10 runs (ms): SELECT id, user_name FROM T WHERE note LIKE '%request 1999%' ORDER BY id
file                          codec          column-rs     DuckDB
db_core_uncompressed.parquet  uncompressed       110.4       21.9
db_core_snappy.parquet        snappy             115.7       23.0
db_core_zstd.parquet          zstd               123.3       24.8
duckdb_uncompressed.parquet   uncompressed        98.3       22.2
duckdb_snappy.parquet         snappy              99.1       23.0
duckdb_zstd.parquet           zstd               109.4       23.4
```

## Notes

- **The codec costs little on a full scan.** zstd adds 7-10% for either
  reader against Snappy or uncompressed, in a warm page cache, where fewer
  bytes buy nothing. **The reader costs more:** column-rs scans text
  4-5x slower than DuckDB.

- **The zstd gap is the encoder, not the encoding.** Both writers produce
  the same pages here (PLAIN `id`, `ts` and `note`, dictionaries for the
  rest; the same uncompressed bytes per column), so the difference is in
  compression alone. At 200 000 rows:

  | encoder | file |
  |---|---|
  | db-core, `ruzstd` `Fastest` | 2.61 MB |
  | DuckDB, libzstd level 1 | 1.61 MB |
  | DuckDB, libzstd level 3 (its default) | 1.23 MB |
  | DuckDB, libzstd level 9 | 1.18 MB |

  `ruzstd`'s fastest level, nominally zstd level 1, writes 1.6x libzstd's
  level 1, and about 4x on the text column (`note`, 0.9 vs 0.21 MB); the
  rest is DuckDB's default level 3. Tracked in db-core#692.
- **Timestamps:** db-core writes `ts` as UTC-adjusted, which DuckDB reads
  as `TIMESTAMP WITH TIME ZONE`; DuckDB's own files hold a plain
  `TIMESTAMP`. The instants are the same, so the timestamp query compares
  epoch microseconds.
