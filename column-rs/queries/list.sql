-- LIST column: each order's tags as a JSON array ([] when empty).
SELECT id, product, tags FROM orders WHERE tags IS NOT NULL
