-- INNER JOIN: orders qualified with the real table name (no aliases), joined
-- to their customer's tier.
SELECT orders.id, orders.amount, customers.tier
FROM orders JOIN customers ON orders.customer_id = customers.customer_id
