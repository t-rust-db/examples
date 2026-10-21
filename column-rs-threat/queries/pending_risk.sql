-- Pending transactions: un-cleared events, largest first.
SELECT event_id, customer_id, amount, country FROM events WHERE state = 'pending' ORDER BY amount DESC
