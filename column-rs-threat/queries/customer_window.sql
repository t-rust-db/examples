-- Customer transaction rank: each customer's events ranked by amount descending.
SELECT event_id, customer_id, amount, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY amount DESC) FROM events
