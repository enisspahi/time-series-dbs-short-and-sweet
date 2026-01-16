# MongoDB Time-series Demo

## Quick Start


### 1. Start MongoDB
```bash
docker-compose up -d

# Wait for all nodes to be ready (~20 seconds)
sleep 20
```

### 2. Create schema
```bash
docker exec -i mongo-primary mongosh -u admin -p admin_pass --authenticationDatabase admin < schema.js
```

---

## Architecture

**Primary Database**: localhost:27017 (read/write)  

### Collections
- `readings`

### Volumes
**Primary:**
- `mongo_primary_data` → `/data/db` - Primary database data

### Connect

To be able to connect from MongoDB Compass configure `/etc/hosts` as follows.
```bash
127.0.0.1 mongo-primary
```

### Connect from MongoShell
```bash
# Connect to primary (read/write)
mongosh "mongodb://admin:admin_pass@localhost:27017/smart-meters?authSource=admin"


### Connect via Docker
```bash
docker exec -it mongo-primary mongosh -u admin -p admin_pass --authenticationDatabase admin smart-meters;
```


### Connect via MongoDB Compass

Set a connection from MongoDB Compass using the following connection string:
```bash
mongodb://admin:admin_pass@localhost:27017/admin?authSource=admin
```

---

## Functional Analysis

### Ingestion

#### Insert new data
```bash
var deviceId = 1;
var startTime = new Date();
var startDate = new Date('2025-12-01T00:00:00.000Z');
var endDate = new Date('2026-01-01T00:00:00.000Z');

for (var currentDate = new Date(startDate); currentDate <= endDate; currentDate.setDate(currentDate.getDate() + 1)) {
  var readings = [];
  
  for (var i = 1; i <= 96; i++) {
    var readingTime = new Date(currentDate.getTime() + (i * 15 * 60 * 1000));
    var value = 100 + Math.random() * 50;
    
    readings.push({
      reading_time: readingTime,
      metadata: { device_id: deviceId },
      value_kwh: value
    });
  }
  
  // Insert readings
  db.readings.insertMany(readings);
    
}

var endTime = new Date();
var elapsedSeconds = (endTime - startTime) / 1000;

print("Completed in " + elapsedSeconds + " seconds");
```

### Querying meter values

#### Time-range query on versioned meter data
```bash
db.readings.find({
  "metadata.device_id": 1,
  reading_time: {
    $gt: new Date('2025-12-01'),
    $lte: new Date('2026-01-01')
  }
}).sort({ reading_time: 1 });
```


#### Per-month aggregation on concluded meter data
```bash
db.readings.aggregate([
  {
    $match: {
      "metadata.device_id": 1,
      reading_time: {
        $gte: ISODate('2025-12-01T00:00:00.000Z'),
        $lt: ISODate('2026-01-01T00:00:00.000Z')
      }
    }
  },
  {
    $group: {
      _id: {
        device_id: '$metadata.device_id',
        year: { $year: '$reading_time' },
        month: { $month: '$reading_time' },
        day: { $dayOfMonth: '$reading_time' }
      },
      total_kwh: { $sum: '$value_kwh' }
    }
  },
  {
    $sort: {
      '_id.year': 1,
      '_id.month': 1,
      '_id.day': 1,
    }
  }
])
```

## Limitations

- ⚠️ **No Updates:** Updates require delete/insert or versioning with append-only semantics