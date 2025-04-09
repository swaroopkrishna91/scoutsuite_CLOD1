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
