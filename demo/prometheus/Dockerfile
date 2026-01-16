# prometheus-Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install wget for healthcheck
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget && \
    rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose the metrics port
EXPOSE 8000

# Run the exporter
CMD ["python", "readings_exporter.py"]