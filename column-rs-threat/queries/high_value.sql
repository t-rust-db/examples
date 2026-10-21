-- High-value transactions: single payments above 1000 EUR.
SELECT event_id, customer_id, amount, country FROM events WHERE amount > 1000
