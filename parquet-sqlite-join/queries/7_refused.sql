-- Refused: a lookup table LEFT JOIN the Parquet table would need the Parquet side as the build side
-- refused
-- expect: write this as `events LEFT JOIN ...`
SELECT COUNT(*)
FROM event_def LEFT JOIN events ON events.event_id = event_def.event_id
