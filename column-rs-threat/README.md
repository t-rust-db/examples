# column-rs threat analysis example

A runnable threat-detection scenario for
[column-rs](https://github.com/t-rust-db/tools/tree/main/column-rs), modelled after a
payment fraud-detection workload. Twenty
transaction events across eight customers, plus a device blacklist — six
queries that show how a columnar analytics engine handles real security
analyst workflows.

## Fixture

Two Parquet files, generated with DuckDB:

- `events.parquet` — 20 transaction events: `event_id`, `ts`, `customer_id`,
  `channel`, `device_id`, `amount`, `currency`, `country`, `state`
- `blacklist.parquet` — 3 flagged devices: `entity_id`, `reason`, `entity_type`

```bash
./fixture/generate.sh
```

## Queries

| File | Threat pattern |
|---|---|
| `queries/velocity.sql` | Velocity detection — customers with many transactions |
| `queries/high_value.sql` | High-value filter — single payments above €1 000 |
| `queries/channel_profile.sql` | Channel profiling — volume and spend per channel |
| `queries/blacklist_hit.sql` | Blacklist match — events from flagged devices (JOIN) |
| `queries/pending_risk.sql` | Pending risk — un-cleared transactions, largest first |
| `queries/customer_window.sql` | Customer ranking — per-customer transaction rank (window) |

### Scenarios in the data

- **C001** fires 5 transactions in under 2 minutes (velocity burst)
- **C003** has a normal POS payment then two large pending web transactions
  from Romania on a stolen device (D-C2)
- **C005** hits three ATMs in three countries within 2 minutes (impossible travel)
- **C006** makes a single €15 000 payment from a mule-account device (D-F1)
- **C002** has normal activity then a €3 200 pending payment from Nigeria

## Running

```bash
./run.sh
```

Generates the fixture if missing, then runs every query. Same binary
resolution as the main column-rs example — see
[`../column-rs/README.md`](../column-rs/README.md#finding-the-column-rs-binary).
