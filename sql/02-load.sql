INSERT INTO events_db.user_events
SELECT
    number + 1                                                         AS event_id,
    toUInt32(rand() % 50000) + 1                                       AS user_id,
    ['view', 'click', 'add_to_cart', 'purchase', 'refund'][1 + rand() % 5] AS event_type,
    ['NL', 'DE', 'FR', 'IR', 'US', 'GB', 'TR', 'CA'][1 + rand() % 8]   AS country,
    round((rand() % 50000) / 100, 2)                                   AS amount,
    toDateTime('2026-01-01 00:00:00') + (rand() % (86400 * 180))       AS event_time
FROM numbers(1000000)
SETTINGS distributed_foreground_insert = 1;
