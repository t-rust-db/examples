-- Resolve event ids to names: the Parquet file probes, the SQLite table is the build side
-- expect: 7 transfer 1024
SELECT events.event_id, event_def.name, COUNT(*) AS n
FROM events JOIN event_def ON events.event_id = event_def.event_id
GROUP BY events.event_id, event_def.name
ORDER BY events.event_id
LIMIT 8
