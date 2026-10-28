# column-rs example

A small, runnable tour of [column-rs](https://github.com/t-rust-db/tools/tree/main/column-rs), the
SQL-over-Parquet analytics engine in the t-rust-db family. Two tiny fixture
tables — `orders` and `customers` — and six queries that show what its SQL
subset actually supports: a filter, a `GROUP BY` aggregate, `ORDER BY` +
`LIMIT`, an equi-join, a window function, and a list column.

column-rs's SQL is a deliberately small subset of standard SQL (no
`SELECT *`, no table aliases, joins must use the real table name, at most one
comparison per level, single-column top-level `ORDER BY`, and more) — see
`t-rust-db/grammar/column-rs.ebnf` for the full grammar. Every query here is
valid against it.

## Fixture

Two Parquet files, generated with DuckDB:

- `orders.parquet` — 10 rows: `id`, `customer_id`, `product`, `amount`, `placed_at`, `tags`
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
| `queries/list.sql` | A `LIST<VARCHAR>` column (see [Lists](#lists)) |

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

## Lists

`orders.tags` is a `VARCHAR[]`: zero or more labels per order, rather than
one delimited string. column-rs reads a Parquet LIST column (db-core 0.189,
column-rs 0.32) and prints each list as a JSON array:

```bash
column-rs -c "SELECT id, product, tags FROM orders WHERE tags IS NOT NULL" \
    fixture/orders.parquet fixture/customers.parquet
```

```
id	product	tags
1	widget	["gift","express"]
2	widget	[]
3	gadget	["express"]
5	widget	["gift",null]
6	gadget	["wholesale"]
7	gizmo	["gift","express","gift"]
8	widget	[]
9	gadget	["wholesale","express"]
```

A NULL list (orders 4 and 10) is not the same as an empty one (`[]`), and
an element can be NULL or repeat. The query runs unchanged in DuckDB over the
same file and returns the same rows; DuckDB displays a list as
`[gift, express]`, and `to_json(tags)` gives column-rs's JSON form. In `--pipe` mode the column's type is
`VARCHAR[]` and each value is a JSON array. A list can be selected and
tested with `IS NULL` / `IS NOT NULL`; taking it apart per element waits
for `UNNEST` (db-core#802).

If your fixture predates the `tags` column, regenerate it with
`./fixture/generate.sh`.

### Finding the column-rs binary

`run.sh` resolves the binary in this order (`../lib/tool.sh`), and prints
the version it uses:

1. `$$COLUMN_RS` — explicit path, if set
2. `../../tools/target/release/column-rs`, built first with `cargo build
   --release` when the `t-rust-db/tools` workspace is checked out as a
   sibling of this `examples` repo under `t-rust-db/` (cargo rebuilds only
   what changed, so this is quick once built)
3. `column-rs` on `$PATH` — a globally installed/linked build

It stops if the binary is older than column-rs 0.32.0, which the list query
needs.
