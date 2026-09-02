# column-rs example

A small, runnable tour of [column-rs](https://github.com/iheitlager/column-rs), the
SQL-over-Parquet analytics engine in the t-rust-db family. Two tiny fixture
tables — `orders` and `customers` — and five queries that show what its SQL
subset actually supports: a filter, a `GROUP BY` aggregate, `ORDER BY` +
`LIMIT`, an equi-join, and a window function.

column-rs's SQL is a deliberately small subset of standard SQL (no
`SELECT *`, no table aliases, joins must use the real table name, at most one
comparison per level, single-column top-level `ORDER BY`, and more) — see
`t-rust-db/grammar/column-rs.ebnf` for the full grammar. Every query here is
valid against it.

## Fixture

Two Parquet files, generated with DuckDB:

- `orders.parquet` — 10 rows: `id`, `customer_id`, `product`, `amount`, `placed_at`
- `customers.parquet` — 4 rows: `customer_id`, `name`, `tier`

Table names are derived from the file stem, so `orders.parquet` becomes table
`orders` and `customers.parquet` becomes table `customers`.

```bash
./fixture/generate.sh
```

Regenerate any time — the `.parquet` files aren't committed.

## Queries

| File | Demonstrates |
|---|---|
| `queries/filter.sql` | `WHERE` filter |
| `queries/group_by.sql` | `GROUP BY` aggregate |
| `queries/order_by_limit.sql` | `ORDER BY` + `LIMIT` |
| `queries/join.sql` | `INNER JOIN`, qualified columns, no aliases |
| `queries/window.sql` | `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)` |

## Running

```bash
./run.sh
```

Generates the fixture if it's missing, then runs every query in `queries/`
against column-rs, printing the SQL and its output. To run a single query by
hand, once the fixture exists:

```bash
column-rs -c "SELECT product, SUM(amount) FROM orders GROUP BY product" \
    fixture/orders.parquet fixture/customers.parquet
```

Expected output for that one:

```
product	SUM(amount)
widget	66.74
gadget	187.25
gizmo	369.99
```

### Finding the column-rs binary

`run.sh` resolves the binary in this order, same as
`benchmark/parity/column-rs/run.sh`:

1. `$COLUMN_RS` — explicit path, if set
2. `column-rs` on `$PATH` — a globally installed/linked build
3. `../../column-rs/target/release/column-rs` — i.e. `t-rust-db/column-rs`
   built in place, the normal case when this `examples` repo is checked out
   as a sibling of `column-rs` under `t-rust-db/`

It does not build column-rs for you — build it first if needed:

```bash
(cd ../../column-rs && cargo build --release)
```
