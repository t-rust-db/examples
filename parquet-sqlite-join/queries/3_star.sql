-- Star join: one Parquet table, two SQLite lookup tables
-- expect: atm 768
SELECT channel.name, COUNT(*) AS payments
FROM events
JOIN event_def ON events.event_id = event_def.event_id
JOIN channel ON events.channel_id = channel.channel_id
WHERE event_def.kind = 'payment'
GROUP BY channel.name
ORDER BY channel.name
