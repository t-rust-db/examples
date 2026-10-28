-- UNNEST: one row per tag of each order, then how often each tag is used.
SELECT tag, count(*) FROM orders, UNNEST(tags) AS t(tag) GROUP BY tag ORDER BY tag
