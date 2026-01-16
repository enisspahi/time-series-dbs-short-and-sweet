# Prometheus Demo

## Quick Start

### 1. Start all services
```bash
docker-compose up -d

# Wait for services
curl http://localhost:8000/metrics  # Readings exporter
curl http://localhost:9090/-/healthy  # Prometheus
```

### 2. View Readings

**Exporter (raw readings):**
```bash
curl http://localhost:8000/metrics
```

### 3. Access Services
- **Prometheus UI**: http://localhost:9090
- **Reading Exporter**: http://localhost:8000/metrics

## How It Works

```
Readings Exporter (Python) → Updates readings every 1 minute
         ↓
    /metrics endpoint
         ↓
  Prometheus scrapes every 15s
```

## Functional Analysis

### Ingestion
> Every 15 minute scrapes are ingestions

### Backfills
> No backfills

## Querying

### Time-range query
```promql
# single device
reading{device_id="1"}

# all devices
reading
```


### Aggregations
```promql
# per-minute
sum by (device_id) (reading)
sum by (device_id) (last_over_time(reading[1m]))

# hourly
sum_over_time(reading[1h:1m])
```

## Limitations

⚠️ **No custom timestamps** - Prometheus uses scrape time  
⚠️ **No backfills** - No restrospective updates

