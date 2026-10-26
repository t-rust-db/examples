# examples

Runnable examples for the t-rust-db family of products. Each one is a
directory with a `run.sh` and a README: it builds or generates its own
fixture, runs against the real binaries, and prints what it does. The
Parquet examples also check themselves against DuckDB and exit non-zero on
a mismatch.

| Example | Product | What it shows |
|---|---|---|
| [`column-rs/`](column-rs/) | column-rs | A tour of column-rs's SQL subset over Parquet |
| [`column-rs-threat/`](column-rs-threat/) | column-rs | Fraud and threat-detection queries over payment events |
| [`sqlite-rs/`](sqlite-rs/) | sqlite-rs | A four-table SQLite database, joined |
| [`parquet-codecs/`](parquet-codecs/) | db-core, column-rs | Parquet codecs across two writers and two readers, with read timings |
| [`parquet-tiered/`](parquet-tiered/) | db-core, column-rs | A striped (tiered) table written hour by hour and read back |
| [`parquet-sqlite-join/`](parquet-sqlite-join/) | column-rs | A Parquet event table joined to SQLite lookup tables |

## The examples

### [`column-rs/`](column-rs/): SQL over Parquet

Two small Parquet tables, `orders` and `customers`, generated with DuckDB,
and five queries that show what column-rs's deliberately small SQL subset
supports: a `WHERE` filter, a `GROUP BY` aggregate, `ORDER BY` + `LIMIT`, an
equi-join on qualified columns, and a `ROW_NUMBER()` window function. Its
README also explains how every example finds the `column-rs` binary.

### [`column-rs-threat/`](column-rs-threat/): threat detection

A security analyst's workload on column-rs: twenty payment events across
eight customers and a device blacklist, with planted scenarios (a velocity
burst, a stolen device, ATMs in three countries within two minutes, a mule
account). Six queries find them: velocity, high-value payments, channel
profiles, a blacklist join, pending risk, and a per-customer windowed
ranking.

### [`sqlite-rs/`](sqlite-rs/): a SQLite database

sqlite-rs, the byte-compatible SQLite clone, over a database built with the
real `sqlite3`: directors, movies, actors and a cast junction table
(Tarantino's and the Coen Brothers' films), queried with a join across all
four tables.

### [`parquet-codecs/`](parquet-codecs/): codecs, writers and readers

One event table written **uncompressed, Snappy and zstd**, once by db-core's
Parquet writer and once by DuckDB. All six files are read by column-rs and
by DuckDB with the same queries, and every answer must match; each file
must record the codec it was written with. It prints the file size per
writer and codec, then times a **full-scan free-text search** (a
`LIKE '%…%'` no statistics can prune) per file and per reader with
hyperfine. Findings so far: zstd costs 7-10% on a warm scan for DuckDB and
about 30% for column-rs, whose zstd decoder is slower (db-core#697); since
db-core v0.156.0 column-rs searches text as fast as DuckDB (db-core#691);
and db-core's zstd files are larger than DuckDB's because of the encoder
(db-core#692).

### [`parquet-tiered/`](parquet-tiered/): a striped table

A db-core tiered table on the events' own clock: each closed hour flushed to
`live/date=…/hour=…/` as one file sorted by `session_id` and cut into row
groups, day 0 merged into `archive/date=…/`, every page zstd. column-rs
reads the table directory and DuckDB reads exactly the files the manifest
lists; their answers must agree, including a `session_id` lookup that skips
files and row groups on the sort key.

### [`parquet-sqlite-join/`](parquet-sqlite-join/): Parquet joined to SQLite

An event table in Parquet and its lookup tables (event definitions,
channels) in a SQLite file, loaded side by side in column-rs and joined in
db-core's cross-mode engine: inner, `GROUP BY` a lookup column, a star
join, and `LEFT JOIN`. A filter on a lookup table skips the Parquet row
groups whose keys can't match, and `EXPLAIN QUERY PLAN` shows how many were
kept. This one runs through column-rs only; each query carries the check
its output must pass. Needs column-rs 0.28.0 or later.

## Requirements

- **DuckDB** on `PATH` for the Parquet examples (fixtures and the reference
  reader), and the real **`sqlite3`** for `sqlite-rs/` and
  `parquet-sqlite-join/`.
- **column-rs** and **sqlite-rs** from
  [t-rust-db/tools](https://github.com/t-rust-db/tools), found as
  `$COLUMN_RS` / `$SQLITE_RS`, on `PATH`, or built in place in a sibling
  `../tools` checkout (`cargo build --release -p column-rs`).
- The `parquet-*` examples build a small writer against a sibling
  `../db-core` checkout, and need a column-rs built against db-core v0.153.0
  or later (tools pins v0.156.0). `parquet-codecs` uses
  [hyperfine](https://github.com/sharkdp/hyperfine) for its timings, and
  skips them without it.

The `iot-fleet` example has moved to
[t-rust-db/db-studio](https://github.com/t-rust-db/db-studio).
