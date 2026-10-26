-- A filter on the lookup table becomes a key set that skips the Parquet row groups that can't match
-- expect: (1 of 10 kept)
EXPLAIN QUERY PLAN
SELECT COUNT(*), SUM(events.amount_cents)
FROM events JOIN event_def ON events.event_id = event_def.event_id
WHERE event_def.name = 'transfer'
