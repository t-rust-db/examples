-- The same query run: one row group of ten read, the answer unchanged
-- expect: 1024 5053584
SELECT COUNT(*), SUM(events.amount_cents)
FROM events JOIN event_def ON events.event_id = event_def.event_id
WHERE event_def.name = 'transfer'
