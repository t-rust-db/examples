#!/usr/bin/env bash
# Generates the two small Parquet fixtures used by ../queries/*.sql, via
# DuckDB. Re-run any time to regenerate -- the .parquet files are gitignored.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

command -v duckdb >/dev/null 2>&1 || { echo "error: duckdb not found on PATH" >&2; exit 1; }

duckdb -batch <<'SQL'
COPY (
    SELECT id, customer_id, product, CAST(amount AS DOUBLE) AS amount, placed_at
    FROM (
        VALUES
            (1, 101, 'widget',  19.99,  TIMESTAMP '2026-01-05 09:12:00'),
            (2, 102, 'widget',   9.50,  TIMESTAMP '2026-01-06 14:03:00'),
            (3, 101, 'gadget',  49.00,  TIMESTAMP '2026-01-07 11:47:00'),
            (4, 103, 'gizmo',  120.00,  TIMESTAMP '2026-01-08 08:30:00'),
            (5, 102, 'widget',  15.25,  TIMESTAMP '2026-01-09 16:55:00'),
            (6, 104, 'gadget',  62.75,  TIMESTAMP '2026-01-10 10:20:00'),
            (7, 101, 'gizmo',   99.99,  TIMESTAMP '2026-01-11 13:00:00'),
            (8, 103, 'widget',  22.00,  TIMESTAMP '2026-01-12 17:41:00'),
            (9, 104, 'gadget',  75.50,  TIMESTAMP '2026-01-13 09:05:00'),
            (10, 102, 'gizmo', 150.00,  TIMESTAMP '2026-01-14 12:12:00')
    ) AS t(id, customer_id, product, amount, placed_at)
) TO 'orders.parquet' (FORMAT PARQUET);

COPY (
    SELECT *
    FROM (
        VALUES
            (101, 'Alice', 'gold'),
            (102, 'Bob',   'silver'),
            (103, 'Carol', 'gold'),
            (104, 'Dave',  'bronze')
    ) AS t(customer_id, name, tier)
) TO 'customers.parquet' (FORMAT PARQUET);
SQL

echo "wrote $ROOT/orders.parquet and $ROOT/customers.parquet"
