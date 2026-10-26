#!/usr/bin/env bash
# Generates the fixtures for the Parquet-to-SQLite join example: an event
# table in Parquet (via DuckDB) and its lookup tables in SQLite (via the real
# sqlite3). Re-run any time -- the generated files are not tracked.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

for tool in duckdb sqlite3; do
    command -v "$tool" >/dev/null 2>&1 || { echo "error: $tool not found on PATH" >&2; exit 1; }
done

rm -f events.parquet lookups.db

# 20480 events: event_id 1..20, 1024 of each, sorted by event_id and written
# in row groups of 2048 rows -- so each row group holds two event ids, and a
# filter on one event's name can skip the other nine row groups.
duckdb -batch <<'SQL'
COPY (
    SELECT
        i % 997 + 1                                        AS session_id,
        i // 1024 + 1                                      AS event_id,
        i % 4 + 1                                          AS channel_id,
        TIMESTAMP '2026-10-01' + INTERVAL (i * 7) SECOND   AS ts,
        (i * 37) % 10000                                   AS amount_cents
    FROM range(20480) t(i)
    ORDER BY event_id, ts
) TO 'events.parquet' (FORMAT PARQUET, ROW_GROUP_SIZE 2048);
SQL

# The catalogue knows events 1..18; events 19 and 20 have no definition,
# which is what the LEFT JOIN query shows.
sqlite3 lookups.db <<'SQL'
CREATE TABLE event_def (event_id INTEGER PRIMARY KEY, name TEXT NOT NULL, kind TEXT NOT NULL);
INSERT INTO event_def VALUES
    (1, 'login', 'auth'), (2, 'logout', 'auth'), (3, 'password_reset', 'auth'),
    (4, 'view_balance', 'read'), (5, 'view_history', 'read'), (6, 'download_statement', 'read'),
    (7, 'transfer', 'payment'), (8, 'card_payment', 'payment'), (9, 'direct_debit', 'payment'),
    (10, 'add_payee', 'change'), (11, 'remove_payee', 'change'), (12, 'change_limit', 'change'),
    (13, 'update_address', 'profile'), (14, 'update_phone', 'profile'), (15, 'update_email', 'profile'),
    (16, 'open_ticket', 'support'), (17, 'chat', 'support'), (18, 'close_ticket', 'support');

CREATE TABLE channel (channel_id INTEGER PRIMARY KEY, name TEXT NOT NULL);
INSERT INTO channel VALUES (1, 'web'), (2, 'mobile'), (3, 'atm'), (4, 'branch');
SQL

echo "wrote $ROOT/events.parquet and $ROOT/lookups.db"
