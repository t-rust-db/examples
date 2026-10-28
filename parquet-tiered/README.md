# Striped (tiered) table example

A db-core table written the way an event stream fills it, then read by
two readers that must agree:
[column-rs](https://github.com/t-rust-db/tools/tree/main/column-rs) over the
table directory, and DuckDB over exactly the files the table's manifest
lists. Every page is zstd at its fastest level (db-core ADR 0028, #589, #622).

## What the writer does

`writer/` (a small program over db-core's `TableWriter`; db-core is
expected as a sibling checkout, `../../db-core`) appends 2 000 events an
hour for hours 08-13 of two days. The table's clock is the events' own
time, so:

- **each closed hour** is flushed to `live/date=…/hour=…/` as one file,
  sorted by `session_id` and cut into row groups of 500 rows, so a filter
  on `session_id` skips files and row groups;
- **day 0**, closed once day 1 starts, is merged into
  `archive/date=…/` as one file;
- **day 1** stays as hour files in `live/`, as an open day does.

Sessions span hours, so one session's events sit in neighbouring hour
files.

```
archive/date=2026-10-21/00000000000000000001-00000000000000012000.parquet
live/date=2026-10-22/hour=08/00000000000000012001-00000000000000014000.parquet
...
live/date=2026-10-22/hour=13/00000000000000022001-00000000000000024000.parquet
```

## Running

```bash
./run.sh
```

It builds and runs the writer into `out/events`, prints the layout and
each file's row groups, rows and codec (all must be ZSTD), then runs every
query through column-rs (`column-rs -c "…" out/events`) and through DuckDB
(`read_parquet` of the manifest's files) and compares the answers.

column-rs is found as in `../column-rs/`: `$COLUMN_RS`, a sibling
`../../tools` checkout (built first), or `column-rs` on `$PATH`. It must be built
against db-core v0.153.0 or later: tables with a sort key write manifest
version 4, which older readers refuse.
