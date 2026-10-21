-- Velocity detection: customers with 3+ transactions, ranked by count.
SELECT customer_id, COUNT(event_id), SUM(amount) FROM events GROUP BY customer_id ORDER BY COUNT(event_id) DESC
