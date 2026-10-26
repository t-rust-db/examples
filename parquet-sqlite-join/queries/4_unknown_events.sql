-- LEFT JOIN keeps every event; events 19 and 20 have no definition in the catalogue
-- expect: 20480 18432
SELECT COUNT(*) AS events, COUNT(event_def.name) AS known
FROM events LEFT JOIN event_def ON events.event_id = event_def.event_id
