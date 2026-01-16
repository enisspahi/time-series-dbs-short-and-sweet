# InfluxDB Demo

## Quick Start

### Start InfluxDB and Grafana
```bash
docker-compose up -d

# Wait for services
curl http://localhost:8086/health
curl http://localhost:3000/api/health
```


### Connection Details
- **InfluxDB URL**: http://localhost:8086
- **Grafana URL**: http://localhost:3000
- **Organization**: openvalue
- **Bucket**: smart-meters
- **Token**: admintoken


## Functional Analysis

### HTTP Endpoints

#### Ingestion

##### Insert new data
````bash
curl -X POST "http://localhost:8086/api/v2/write?org=openvalue&bucket=smart-meters&precision=s" \
  -H "Authorization: Token admintoken" \
  -H "Content-Type: text/plain; charset=utf-8" \
  --data-binary @- << EOF
readings,device_id=1 value_kwh=10.0 $(date -j -f "%Y-%m-%d %H:%M:%S" "2026-01-15 00:15:00" +%s)
readings,device_id=1 value_kwh=11.0 $(date -j -f "%Y-%m-%d %H:%M:%S" "2026-01-15 00:30:00" +%s)
readings,device_id=1 value_kwh=10.5 $(date -j -f "%Y-%m-%d %H:%M:%S" "2026-01-15 00:45:00" +%s)
readings,device_id=1 value_kwh=10.9 $(date -j -f "%Y-%m-%d %H:%M:%S" "2026-01-15 01:00:00" +%s)
EOF
````

##### Simulate full day readings
````bash
for device in {1..10}; do
  START_TIME=$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-01-15 00:15:00' +%s)
  for i in {0..95}; do
    TIMESTAMP=$((START_TIME + i * 900))
    # Generate random value between 0.8 and 1.2
    RAND_NUM=$((RANDOM % 400))
    VALUE=$(echo "scale=3; 0.8 + $RAND_NUM / 1000" | bc)
    echo "readings,device_id=$device value_kwh=$VALUE $TIMESTAMP"
  done
done | curl -X POST "http://localhost:8086/api/v2/write?org=openvalue&bucket=smart-meters&precision=s" \
  -H "Authorization: Token admintoken" \
  -H "Content-Type: text/plain; charset=utf-8" \
  --data-binary @-
````

#### Querying meter values

##### Time-range query

```bash
curl -X POST "http://localhost:8086/api/v2/query?org=openvalue" \
  -H "Authorization: Token admintoken" \
  -H "Content-Type: application/vnd.flux" \
  --data 'from(bucket: "smart-meters")
    |> range(start: 2026-01-15T00:15:00+01:00, stop: 2026-01-16T00:00:00+01:00)
    |> filter(fn: (r) => r._measurement == "readings")
    |> filter(fn: (r) => r.device_id == "1")
    |> sort(columns: ["_time"])'
```

##### Per-hour aggregation

```bash
curl -X POST "http://localhost:8086/api/v2/query?org=openvalue" \
  -H "Authorization: Token admintoken" \
  -H "Content-Type: application/vnd.flux" \
  --data 'from(bucket: "smart-meters")
    |> range(start: 2026-01-15T00:15:00+01:00, stop: 2026-01-16T00:00:00+01:00)
    |> filter(fn: (r) => r._measurement == "readings")
    |> filter(fn: (r) => r.device_id == "1")
    |> aggregateWindow(every: 1h, fn: sum)'
```



### Grafana Usage

#### Time-range query
````sql
SELECT last("value_kwh") FROM "readings" WHERE $timeFilter GROUP BY time(15m)
````

#### Per-hour aggregation

````sql
SELECT sum("value_kwh") 
FROM "readings" 
WHERE $timeFilter 
GROUP BY time(1h)
````

## Data cleanup
````bash
curl -X POST "http://localhost:8086/api/v2/delete?org=openvalue&bucket=smart-meters" \
  -H "Authorization: Token admintoken" \
  -H "Content-Type: application/json" \
  --data '{
    "start": "1970-01-01T00:00:00Z",
    "stop": "2099-01-01T00:00:00Z"
  }'
````

## Limitations

- ⚠️ **High cardinality:** Up to ~100,000 meters in InfluxDB OSS