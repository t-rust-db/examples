-- Blacklist hit: events from flagged devices, joined to the reason.
SELECT events.event_id, events.customer_id, events.amount, blacklist.reason
FROM events JOIN blacklist ON events.device_id = blacklist.entity_id
