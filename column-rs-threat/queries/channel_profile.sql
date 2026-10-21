-- Channel profile: volume and total amount per channel.
SELECT channel, COUNT(event_id), SUM(amount) FROM events GROUP BY channel
