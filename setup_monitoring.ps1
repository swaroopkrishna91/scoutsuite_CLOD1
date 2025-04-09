# Define the folder and file paths
$FOLDER = "scoutsuite_monitoring"
$EXPORTER_SCRIPT = "$FOLDER\json_exporter.py"
$DOCKERFILE = "$FOLDER\Dockerfile"
$PROMETHEUS_CONFIG = "$FOLDER\prometheus.yml"
$DOCKER_COMPOSE_FILE = "$FOLDER\docker-compose.yml"
$SCOUTSUITE_JSON = "$FOLDER\data.json"

Write-Host "Setting up Scout Suite Monitoring System..."

# Step 1: Create a directory to store all files
if (!(Test-Path -Path $FOLDER)) {
    New-Item -ItemType Directory -Path $FOLDER | Out-Null
}
Write-Host "Folder '$FOLDER' created."

# Step 2: Ensure the JSON file exists before proceeding
if (!(Test-Path "data.json")) {
    Write-Host "Error: The file 'data.json' was not found in the current directory. Please provide a valid Scout Suite JSON file."
    exit 1
}

# Step 3: Copy the JSON file into the monitoring folder
Copy-Item -Path "data.json" -Destination $SCOUTSUITE_JSON -Force
Write-Host "JSON file copied to '$SCOUTSUITE_JSON'."

# Step 4: Create JSON Exporter Python script
@"
from prometheus_client import start_http_server, Gauge
import json
import time

# Load JSON data
file_path = "/data/data.json"
with open(file_path, "r") as file:
    data = json.load(file)

# Extract summaries and rules
services_data = data.get("last_run", {}).get("summary", {})
rules_data = data.get("services", {}).get("ec2", {}).get("findings", {})# <-- rule-level data

# Define Prometheus metrics
SERVICES = [
    "ec2", "iam", "vpc", "cloudtrail", "s3", "rds", "config", "cloudwatch",
    "cloudfront", "lambda", "kms", "elb", "sns", "sqs", "route53",
    "elasticache", "secretsmanager", "guardduty", "ses", "codebuild"
]

# Service-level metrics
CHECKED_ITEMS = Gauge("aws_checked_items", "Number of checked security items", ["service"])
FLAGGED_ITEMS = Gauge("aws_flagged_items", "Number of flagged security issues", ["service"])
RESOURCES_COUNT = Gauge("aws_resources_count", "Number of resources assessed", ["service"])
RULES_COUNT = Gauge("aws_rules_count", "Number of security rules checked", ["service"])

# Rule-level metrics
RULE_CHECKED_ITEMS = Gauge(
    "aws_rule_checked_items",
    "Checked items for specific security rules",
    ["rule_id", "service", "description"]
)

RULE_FLAGGED_ITEMS = Gauge(
    "aws_rule_flagged_items",
    "Flagged (non-compliant) items for specific security rules",
    ["rule_id", "service", "description", "severity"]
)

def collect_metrics():
    """Update Prometheus metrics from JSON data."""

    # Update service-level metrics
    for service in SERVICES:
        details = services_data.get(service, {})
        CHECKED_ITEMS.labels(service=service).set(details.get("checked_items", 0))
        FLAGGED_ITEMS.labels(service=service).set(details.get("flagged_items", 0))
        RESOURCES_COUNT.labels(service=service).set(details.get("resources_count", 0))
        RULES_COUNT.labels(service=service).set(details.get("rules_count", 0))

    # Update rule-level metrics (like ec2-security-group-opens-SSH-port-to-all)
    for rule_id, rule in rules_data.items():
        if not isinstance(rule, dict):
            continue  # Skip if the rule is not a dictionary

        service = rule.get("service", "unknown")
        description = rule.get("description", rule_id)
        severity = rule.get("level", "info")

        checked = rule.get("checked_items", 0)
        flagged = rule.get("flagged_items", 0)

        RULE_CHECKED_ITEMS.labels(
            rule_id=rule_id,
            service=service,
            description=description
        ).set(checked)

        RULE_FLAGGED_ITEMS.labels(
            rule_id=rule_id,
            service=service,
            description=description,
            severity=severity
        ).set(flagged)


if __name__ == "__main__":
    # Start Prometheus HTTP server
    start_http_server(8000)
    print("Prometheus Exporter running on port 8000...")

    while True:
        collect_metrics()
        time.sleep(30)  # Update metrics every 30 seconds
"@ | Out-File -Encoding utf8 $EXPORTER_SCRIPT

Write-Host "JSON Exporter script created."

# Step 5: Create Dockerfile for JSON Exporter
@"
FROM python:3.9
WORKDIR /app
COPY json_exporter.py /app
COPY data.json /data/data.json
RUN pip install flask prometheus_client requests
CMD ["python", "json_exporter.py"]
"@ | Out-File -Encoding utf8 $DOCKERFILE

Write-Host "Dockerfile created."

# Step 6: Create Prometheus config file
@"
global:
  scrape_interval: 10s

scrape_configs:
  - job_name: "json_exporter"
    static_configs:
      - targets: ["json-exporter:8000"]
"@ | Out-File -Encoding utf8 $PROMETHEUS_CONFIG

Write-Host "Prometheus config created."

# Step 7: Create Docker Compose file
@"
version: '3.8'

services:
  json-exporter:
    build: .
    container_name: json-exporter
    ports:
      - "8000:8000"
    volumes:
      - ./data.json:/data/data.json

  prometheus:
    image: prom/prometheus
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
    ports:
      - "9090:9090"
    depends_on:
      - json-exporter

  grafana:
    image: grafana/grafana
    container_name: grafana
    ports:
      - "3000:3000"
    depends_on:
      - prometheus
"@ | Out-File -Encoding utf8 $DOCKER_COMPOSE_FILE

Write-Host "Docker Compose file created."

# Step 8: Build and Start the Containers
Set-Location $FOLDER
Write-Host "Starting Docker containers in '$FOLDER'..."
docker-compose up -d --build

Write-Host "Monitoring system started!"
Write-Host "Prometheus: http://localhost:9090"
Write-Host "Grafana: http://localhost:3000"
Write-Host "JSON Exporter Metrics: http://localhost:8000/metrics"
