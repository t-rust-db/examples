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
./run.sh            # ROWS=200000
ROWS=1000000 ./run.sh
```

It builds `writer/` (a small program over db-core's writer; db-core is
expected as a sibling checkout, `../../db-core`), writes the six files
into `out/`, checks each file's codec with DuckDB's `parquet_metadata`, and
runs every query through column-rs and DuckDB on every file. A reader that
disagrees with DuckDB on DuckDB's uncompressed file fails the run.

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

## Notes

- **Sizes differ by writer, not only by codec.** db-core writes zstd at
  `ruzstd`'s one implemented level (about zstd level 1) and stores `id`
  and `ts` PLAIN; DuckDB uses zstd level 3 and delta encodings, so its
  zstd file is about half the size here.
- **Timestamps:** db-core writes `ts` as UTC-adjusted, which DuckDB reads
  as `TIMESTAMP WITH TIME ZONE`; DuckDB's own files hold a plain
  `TIMESTAMP`. The instants are the same, so the timestamp query compares
  epoch microseconds.
