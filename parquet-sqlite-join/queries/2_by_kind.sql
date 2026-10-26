-- Aggregate by a lookup column: events and spend per kind of event
-- expect: payment 3072 15512688
SELECT event_def.kind, COUNT(*) AS n, SUM(events.amount_cents) AS spend
FROM events JOIN event_def ON events.event_id = event_def.event_id
GROUP BY event_def.kind
ORDER BY event_def.kind
