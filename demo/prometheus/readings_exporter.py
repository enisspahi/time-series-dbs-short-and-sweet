#!/usr/bin/env python3
"""
Simple Smart Meter Simulator for Prometheus
Simulates 10 meters with random readings
"""

from prometheus_client import start_http_server, Gauge
import random
import time

# Create Prometheus gauge for meter readings
readings = Gauge('reading', 'Current device reading in kWh', ['device_id'])

def update_readings():
    """Update readings for 10 devices with random values"""
    for device_id in range(1, 11):
        # Generate random value between 0.8 and 1.2 kWh
        value = 0.8 + random.random() * 0.4
        readings.labels(device_id=str(device_id)).set(value)

if __name__ == '__main__':
    # Start HTTP server on port 8000
    print("Starting Smart Meter Exporter on http://localhost:8000")
    print("Metrics available at http://localhost:8000/metrics")
    start_http_server(8000)
    
    # Update readings every 1 minute
    while True:
        update_readings()
        print(f"Updated readings at {time.strftime('%Y-%m-%d %H:%M:%S')}")
        time.sleep(60)