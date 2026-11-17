CREATE DATABASE IF NOT EXISTS events_db ON CLUSTER '{cluster}';

CREATE TABLE IF NOT EXISTS events_db.user_events_local ON CLUSTER '{cluster}'
(
    event_id    UInt64,
    user_id     UInt32,
    event_type  LowCardinality(String),
    country     LowCardinality(String),
    amount      Decimal(10, 2),
    event_time  DateTime
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/user_events_local', '{replica}')
PARTITION BY toYYYYMM(event_time)
ORDER BY (user_id, event_time);

CREATE TABLE IF NOT EXISTS events_db.user_events ON CLUSTER '{cluster}'
AS events_db.user_events_local
ENGINE = Distributed('{cluster}', 'events_db', 'user_events_local', cityHash64(user_id));
