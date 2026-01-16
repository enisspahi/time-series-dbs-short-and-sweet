# TimescaleDB Demo

## Quick Start

### 1. Start database
```bash
docker-compose up -d

# Set correct ownership and permissions for postgres user
docker exec timescale-primary chown -R postgres:postgres /tablespaces
docker exec timescale-primary chmod -R 700 /tablespaces
```

### 2. Create schema on primary
```bash
docker exec -i timescale-primary psql -U postgres -d smart-meters < schema.sql
```


## Architecture

**Primary Database**: localhost:5432 (read/write)  

### Tables
- `readings` - Smart Meter readings

### Volumes
**Primary:**
- `pg_primary` - Tables and first index
- `pg_primary_hot_1` - Hot storage 1
- `pg_primary_hot_2` - Hot storage 2


### Connect
```bash
# Connect to primary (read/write)
psql -h localhost -p 5432 -U postgres -d smart-meters

# Connect to replica (read-only)
psql -h localhost -p 5433 -U postgres -d smart-meters
```

## Functional Analysis

### Ingestion

#### Insert new data
```
INSERT INTO readings (device_id, reading_time, value_kwh)
    SELECT
        device_id,
        reading_time,
        1.000 AS value_kwh
    FROM 
        generate_series(1, 10) AS device_id,
        generate_series(
            '2025-12-01 00:15:00'::TIMESTAMPTZ,
            '2026-01-01 00:00:00'::TIMESTAMPTZ,
            INTERVAL '15 minutes'
        ) AS reading_time
```

#### Backfills
```
INSERT INTO readings (device_id, reading_time, value_kwh)
    SELECT
        device_id,
        reading_time,
        2.000 AS value_kwh
    FROM 
        generate_series(1, 5) AS device_id,
        generate_series(
            '2025-12-01 00:15:00'::TIMESTAMPTZ,
            '2026-01-01 00:00:00'::TIMESTAMPTZ,
            INTERVAL '15 minutes'
        ) AS reading_time
ON CONFLICT (device_id, reading_time) DO UPDATE 
  SET
    value_kwh = excluded.value_kwh;
```

### Querying readings

#### Time-range query
```sql
SELECT * FROM readings
WHERE device_id = 1
    AND reading_time between '2025-12-01 00:15:00' AND '2026-01-01 00:00:00'
ORDER BY reading_time;
```

#### Per-month aggregation
```sql
SELECT r.device_id,
       time_bucket('1 month', r.reading_time::TIMESTAMP, INTERVAL '15 minutes') AS month,
       SUM(r.value_kwh) as value_month
   FROM readings r
        WHERE r.device_id = 1
         AND r.reading_time between '2025-12-01 00:15:00' AND '2026-01-01 00:00:00'
   GROUP BY r.device_id, month
```

#### Metadata joins (consumption on device_region)
```sql
-- Dataset
INSERT INTO devices (device_id, device_region) VALUES
    (1, 'MUC'),
    (2, 'MUC'),
    (3, 'MUC'),
    (4, 'MUC'),
    (5, 'MUC'),
    (6, 'DUS'),
    (7, 'DUS'),
    (8, 'DUS'),
    (9, 'DUS'),
    (10, 'DUS');

-- Day sums per a device_region
SELECT 
    d.device_region,
    JSON_AGG(DISTINCT d.device_id) AS devices,
    time_bucket('1 day', r.reading_time::TIMESTAMP, INTERVAL '15 minutes') AS day,
    SUM(r.value_kwh) AS total_kwh,
    COUNT(*) AS readings_count,
    COUNT(DISTINCT r.device_id) AS meters
FROM readings r
    INNER JOIN devices d ON r.device_id = d.device_id
WHERE r.reading_time BETWEEN '2025-12-01 00:15:00' AND '2026-01-01 00:00:00'
GROUP BY 
    d.device_region,
    time_bucket('1 day', r.reading_time::TIMESTAMP, INTERVAL '15 minutes')
ORDER BY 
    d.device_region,
    day;
```



## Non-functional Analysis


### Retention

The following policy can drop readings after 10 years:
```sql
SELECT add_retention_policy('readings', INTERVAL '120 months');
```


### Storage efficiency and Compression

> ℹ️ Automatic compression can be achieved via compression policies. 

The following policy can compress data automatically for chunks older than 7 days:
```sql
SELECT add_compression_policy('readings', INTERVAL '7 days', if_not_exists => true);
```

![alt text](<compression.webp>)

#### Manual compression
```sql
SELECT compress_chunk(c) FROM show_chunks('readings', older_than => INTERVAL '20 days') c;
```

#### Compression Stats

````
-- Compression stats (before, after table sizes)
SELECT * FROM chunk_compression_stats('readings');
````


### Trubleshooting cheet-sheet
```sql
-- List or inspect chunks
SELECT * FROM show_chunks('readings');
SELECT * FROM timescaledb_information.chunks;

-- Detailed chunk sizes
SELECT * FROM chunks_detailed_size('readings');

-- Compression stats (before, after table sizes)
SELECT * FROM chunk_compression_stats('readings');
```