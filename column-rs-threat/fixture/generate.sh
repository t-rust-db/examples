#!/usr/bin/env bash
# Generates Parquet fixtures for the threat-analysis example, via DuckDB.
# Re-run any time -- the .parquet files are gitignored.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

command -v duckdb >/dev/null 2>&1 || { echo "error: duckdb not found on PATH" >&2; exit 1; }

duckdb -batch <<'SQL'
-- Transaction events modelled after a payment fraud-detection workload.
-- Fields: event_id, timestamp, customer_id, channel, device_id, amount, currency, country, state.
COPY (
    SELECT *
    FROM (
        VALUES
            (1,  TIMESTAMP '2026-09-01 08:01:12', 'C001', 'mobile',  'D-A1', CAST(250.00  AS DOUBLE), 'EUR', 'NL', 'completed'),
            (2,  TIMESTAMP '2026-09-01 08:01:45', 'C001', 'mobile',  'D-A1', CAST(310.00  AS DOUBLE), 'EUR', 'NL', 'completed'),
            (3,  TIMESTAMP '2026-09-01 08:02:03', 'C001', 'mobile',  'D-A1', CAST(175.50  AS DOUBLE), 'EUR', 'NL', 'completed'),
            (4,  TIMESTAMP '2026-09-01 08:02:18', 'C001', 'mobile',  'D-A1', CAST(420.00  AS DOUBLE), 'EUR', 'DE', 'completed'),
            (5,  TIMESTAMP '2026-09-01 08:02:30', 'C001', 'mobile',  'D-A1', CAST(89.99   AS DOUBLE), 'EUR', 'NL', 'completed'),
            (6,  TIMESTAMP '2026-09-01 09:15:00', 'C002', 'web',     'D-B1', CAST(45.00   AS DOUBLE), 'EUR', 'NL', 'completed'),
            (7,  TIMESTAMP '2026-09-01 10:30:00', 'C002', 'web',     'D-B1', CAST(62.50   AS DOUBLE), 'EUR', 'BE', 'completed'),
            (8,  TIMESTAMP '2026-09-01 11:00:00', 'C003', 'pos',     'D-C1', CAST(1200.00 AS DOUBLE), 'EUR', 'NL', 'completed'),
            (9,  TIMESTAMP '2026-09-01 11:05:00', 'C003', 'web',     'D-C2', CAST(8500.00 AS DOUBLE), 'EUR', 'RO', 'pending'),
            (10, TIMESTAMP '2026-09-01 11:06:00', 'C003', 'web',     'D-C2', CAST(9200.00 AS DOUBLE), 'EUR', 'RO', 'pending'),
            (11, TIMESTAMP '2026-09-01 12:00:00', 'C004', 'mobile',  'D-D1', CAST(35.00   AS DOUBLE), 'EUR', 'NL', 'completed'),
            (12, TIMESTAMP '2026-09-01 12:30:00', 'C004', 'mobile',  'D-D1', CAST(28.00   AS DOUBLE), 'EUR', 'NL', 'completed'),
            (13, TIMESTAMP '2026-09-01 13:00:00', 'C005', 'atm',     'D-E1', CAST(500.00  AS DOUBLE), 'EUR', 'NL', 'completed'),
            (14, TIMESTAMP '2026-09-01 13:01:00', 'C005', 'atm',     'D-E2', CAST(500.00  AS DOUBLE), 'EUR', 'DE', 'completed'),
            (15, TIMESTAMP '2026-09-01 13:02:00', 'C005', 'atm',     'D-E3', CAST(500.00  AS DOUBLE), 'EUR', 'BE', 'completed'),
            (16, TIMESTAMP '2026-09-01 14:00:00', 'C006', 'web',     'D-F1', CAST(15000.00 AS DOUBLE), 'EUR', 'NL', 'completed'),
            (17, TIMESTAMP '2026-09-01 14:15:00', 'C002', 'mobile',  'D-B2', CAST(3200.00 AS DOUBLE), 'EUR', 'NG', 'pending'),
            (18, TIMESTAMP '2026-09-01 15:00:00', 'C007', 'web',     'D-G1', CAST(75.00   AS DOUBLE), 'EUR', 'NL', 'completed'),
            (19, TIMESTAMP '2026-09-01 15:30:00', 'C007', 'web',     'D-G1', CAST(82.00   AS DOUBLE), 'EUR', 'NL', 'completed'),
            (20, TIMESTAMP '2026-09-01 16:00:00', 'C008', 'pos',     'D-H1', CAST(22.50   AS DOUBLE), 'EUR', 'NL', 'completed')
    ) AS t(event_id, ts, customer_id, channel, device_id, amount, currency, country, state)
) TO 'events.parquet' (FORMAT PARQUET);

-- Known-bad entities: flagged devices and countries.
COPY (
    SELECT *
    FROM (
        VALUES
            ('D-C2', 'stolen_credential',  'device'),
            ('D-E3', 'cloned_card',        'device'),
            ('D-F1', 'mule_account',       'device')
    ) AS t(entity_id, reason, entity_type)
) TO 'blacklist.parquet' (FORMAT PARQUET);
SQL

echo "wrote $ROOT/events.parquet and $ROOT/blacklist.parquet"
