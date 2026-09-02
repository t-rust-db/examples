-- Window function: rank each customer's own orders by amount, largest first.
SELECT id, customer_id, amount, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY amount DESC) FROM orders
