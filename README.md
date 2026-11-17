# ClickHouse cluster with Docker Compose: 2 shards x 3 replicas

A small ClickHouse cluster for learning sharding and replication hands-on:

- **6 ClickHouse nodes**: 2 shards, 3 replicas per shard
- **3 ClickHouse Keeper nodes** (Raft) coordinating replication
- `ReplicatedMergeTree` tables on every node and a `Distributed` table on top
- Sharding key: `cityHash64(user_id)`
- Synthetic user-events dataset generated inside ClickHouse (no download needed)

```
              keeper1        keeper2        keeper3
                 ▲              ▲              ▲
   ┌─────────────┴──────────────┴──────────────┴─────────────┐
   │ SHARD 1: ch-s1-r1  ch-s1-r2  ch-s1-r3                   │
   │ SHARD 2: ch-s2-r1  ch-s2-r2  ch-s2-r3                   │
   └─────────────────────────────────────────────────────────┘
```

A full Persian report with results and explanations is in [REPORT.md](REPORT.md).

## Requirements

- Docker and Docker Compose v2 (tested with Docker 29.9.3 and Compose v5.7.0)
- About 6 GB of free RAM
- Image: `clickhouse/clickhouse-server:26.8`

## Quick start

```bash
docker compose up -d
docker compose ps

# create the database and tables on all 6 nodes
docker compose exec -T ch-s1-r1 clickhouse-client --multiquery < sql/01-schema.sql

# generate and insert 1,000,000 events through the Distributed table (run once)
docker compose exec -T ch-s1-r1 clickhouse-client --multiquery < sql/02-load.sql
```

## Check the distribution

```bash
# total rows through the Distributed table
docker compose exec ch-s1-r1 clickhouse-client --query "SELECT count() FROM events_db.user_events"

# rows per shard and replica
docker compose exec ch-s1-r1 clickhouse-client --query "SELECT getMacro('shard') AS shard, getMacro('replica') AS replica, count() AS rows FROM clusterAllReplicas('events_cluster', events_db.user_events_local) GROUP BY shard, replica ORDER BY shard, replica"

# users stored on more than one shard (expected: 0)
docker compose exec ch-s1-r1 clickhouse-client --query "SELECT count() FROM (SELECT user_id FROM clusterAllReplicas('events_cluster', events_db.user_events_local) GROUP BY user_id HAVING uniqExact(getMacro('shard')) > 1)"
```

## Failure tests

```bash
# stop one replica: reads and writes keep working, it catches up after restart
docker compose stop ch-s1-r3
docker compose start ch-s1-r3

# stop one Keeper: everything keeps working (2 of 3 = quorum)
docker compose stop keeper1

# stop a second Keeper: quorum is lost, tables become read-only, inserts fail
docker compose stop keeper2

# restore
docker compose start keeper1 keeper2
```

## Notes

- Node-specific values (`SHARD`, `REPLICA`, `KEEPER_ID`) come from environment variables in `docker-compose.yml`; the XML files in `config/` are shared by all nodes.
- The `default` user has no password. This is acceptable for a local demo only: the published ports are bound to `127.0.0.1`, and `config/users-network.xml` only opens the user to the internal Docker network.
- Data lives in named Docker volumes. `docker compose down -v` deletes it.
