# iot-fleet example

A [db-studio](https://github.com/t-rust-db/db-studio) example combining all
three file shapes it can (or will) open: a small IoT fleet with slow-changing
dimensions in SQLite, high-volume time-series metrics in Parquet, and raw
device events in a log file.

## Scenario

A fictional fleet of edge sensors across three sites:

- **`fixture/fleet.sqlite`** (row mode) -- dimensions: `sites`, `devices`,
  `sensors`. Small, relational, rarely changes.
- **`fixture/readings.parquet`** (batch mode) -- metrics: one row per
  `(device_id, sensor_id, ts, value)` reading, every 5 minutes for 24h across
  8 sensors (2304 rows). High volume, append-only.
- **`fixture/device.log`** (stream mode) -- events: freeform
  `INFO`/`WARN`/`ERROR` device log lines (reboots, connectivity, thresholds).

Both `fleet.sqlite` and `readings.parquet` are built by `fixture/generate.sh`
using the real `sqlite3` and `duckdb` CLIs, same convention as
`../sqlite-rs/` and `../column-rs/`. All three fixture files are gitignored;
regenerate any time.

## Current limitations

**No cross-mode joins.** db-studio opens one `Engine` per file, and there's
no join across a `.sqlite` file and a `.parquet` file in a single query.
Resolving a `device_id` from `readings.parquet` back to its device/site in
`fleet.sqlite` (or vice versa) takes two separate queries today, run against
each open file in turn -- not one query. This is the natural next step for
this example once db-core grows that capability.

**`.log` isn't openable yet.** db-studio has no stream-mode engine yet
(planned as M5, gated on db-core's `storage::stream` maturing).
`device.log` is included here for when that lands -- `run.sh` doesn't pass
it to db-studio today, and opening it would fail.

## Queries

| File | Mode | Demonstrates |
|---|---|---|
| `queries/devices_by_site.sql` | row (`fleet.sqlite`) | `JOIN`, `ORDER BY` |
| `queries/sensors_per_device.sql` | row (`fleet.sqlite`) | `GROUP BY` aggregate |
| `queries/avg_reading_per_sensor.sql` | batch (`readings.parquet`) | `GROUP BY` aggregate |
| `queries/highest_readings.sql` | batch (`readings.parquet`) | `ORDER BY` + `LIMIT` |

## Running

```bash
./run.sh
```

Generates the fixtures if missing, then launches db-studio with both
`fleet.sqlite` and `readings.parquet` open. Unlike `../sqlite-rs/run.sh` and
`../column-rs/run.sh`, this doesn't loop over `queries/*.sql` and print
output -- db-studio is an interactive TUI, not a batch query runner. Once
it's open:

- `Tab` cycles focus between the query pane and the schema tree
- Select a file's root in the tree + `Enter` to make it the active query
  target
- Type or paste any query from `queries/*.sql` into the query pane, `F5` to
  run it
- `F1`-`F4` switch between results/plan/opcodes/file-stats views

### Finding the db-studio binary

`run.sh` resolves the binary in this order, same as `../sqlite-rs/run.sh`
and `../column-rs/run.sh`:

1. `$DB_STUDIO` -- explicit path, if set
2. `db-studio` on `$PATH` -- a globally installed/linked build
3. `../../db-studio/target/release/db-studio` -- i.e. `t-rust-db/db-studio`
   built in place, the normal case when this `examples` repo is checked out
   as a sibling of `db-studio` under `t-rust-db/`

It does not build db-studio for you -- build it first if needed:

```bash
(cd ../../db-studio && cargo build --release --bin db-studio)
```
