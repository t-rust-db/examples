-- GROUP BY aggregate: total order amount per product.
SELECT product, SUM(amount) FROM orders GROUP BY product
