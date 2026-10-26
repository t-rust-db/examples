# Parquet joined to SQLite lookup tables

An event table in Parquet, joined to its lookup tables in a SQLite file by
[column-rs](https://github.com/t-rust-db/tools/tree/main/column-rs). Events
are large and append-only, so they live in a columnar file; the catalogue
that names them is small and edited in place, so it lives in a row store.
column-rs loads both side by side, and a query that names a SQLite table
runs in db-core's cross-mode engine (db-core#598): the Parquet file is the
probe side, read row group by row group, and the SQLite tables are hashed
as the build side.

Needs column-rs 0.28.0 or later (tools#69).

## Fixture

```bash
./fixture/generate.sh
```

- `events.parquet` (DuckDB): 20 480 events, `session_id`, `event_id`,
  `channel_id`, `ts`, `amount_cents`. Event ids 1 to 20, 1 024 of each,
  sorted by `event_id` and written in row groups of 2 048 rows, so each
  row group holds two event ids.
- `lookups.db` (the real `sqlite3`): `event_def(event_id, name, kind)`
  for events 1 to 18, and `channel(channel_id, name)`. Events 19 and 20
  have no definition.

## Queries

| File | What it shows |
|---|---|
| `queries/1_event_names.sql` | Event ids resolved to names |
| `queries/2_by_kind.sql` | `GROUP BY` a lookup column |
| `queries/3_star.sql` | A star join: events, event definitions and channels |
| `queries/4_unknown_events.sql` | `LEFT JOIN` keeps the events the catalogue doesn't know |
| `queries/5_pruned_plan.sql` | `EXPLAIN QUERY PLAN`: a filter on the lookup table skips 9 of the 10 row groups |
| `queries/6_pruned_result.sql` | The same query run |
| `queries/7_refused.sql` | `event_def LEFT JOIN events`, refused with how to write it instead |

### Pruning by a lookup filter

`WHERE event_def.name = 'transfer'` doesn't mention the Parquet file at all.
db-core runs the filter on the SQLite side first, turns the matching
`event_id`s into a key set, and checks it against each row group's min/max
statistics before reading it. With the events sorted by `event_id`, one row
group of ten can match:

```
└── PRUNE ROW GROUPS OF events BY event_def FILTER (1 of 10 kept)
```

## Running

```bash
./run.sh
```

Generates the fixture if missing, then runs every query through column-rs
only. Each query file carries its own check: an `-- expect:` line its output
must contain, and `-- refused` on the query column-rs must refuse. `run.sh`
exits non-zero if any check fails. Same binary resolution as the main
column-rs example; see
[`../column-rs/README.md`](../column-rs/README.md#finding-the-column-rs-binary).

## Limits

- One Parquet file per query. A table directory as the probe side is
  db-core#772, and a second Parquet table in the same query is db-core#782.
- The lookup tables are the build side: `lookup LEFT JOIN events` is
  refused (query 7).
