-- ============================================
-- TIMESCALEDB SETUP
-- ============================================

CREATE EXTENSION IF NOT EXISTS timescaledb;

-- ============================================
-- TABLESPACES
-- ============================================

CREATE TABLESPACE ts_hot_1 
    OWNER postgres 
    LOCATION '/tablespaces/hot_1';

CREATE TABLESPACE ts_hot_2 
    OWNER postgres 
    LOCATION '/tablespaces/hot_2';

-- ============================================
-- Readings TABLE
-- ============================================

CREATE TABLE readings (
    device_id INTEGER NOT NULL,
    reading_time TIMESTAMPTZ NOT NULL,
    value_kwh NUMERIC(10,3) NOT NULL,
    
    PRIMARY KEY (device_id, reading_time)
);

-- Create hypertable on version_ts
SELECT create_hypertable('readings', by_range('reading_time', INTERVAL '1 week'), if_not_exists => TRUE);
SELECT add_dimension('readings', by_hash('device_id', 4), if_not_exists => TRUE);
SELECT enable_chunk_skipping('readings', 'device_id', if_not_exists => TRUE);

-- Attach tablespaces for parallel disk usage
SELECT attach_tablespace('ts_hot_1', 'readings');
SELECT attach_tablespace('ts_hot_2', 'readings');

-- Configure compression for versioned_meter_data
ALTER TABLE readings SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'reading_time DESC'
);

-- Add compression policy for versioned_meter_data
SELECT add_compression_policy('readings', INTERVAL '7 days', if_not_exists => true);

-- Add retention policy for concluded_meter_data
SELECT add_retention_policy('readings', INTERVAL '120 months');

-- ============================================
-- Device Regions
-- ============================================
CREATE TABLE devices (
    device_id INTEGER PRIMARY KEY,
    device_region VARCHAR NOT NULL
);

CREATE INDEX idx_device_regions ON devices(device_region);
