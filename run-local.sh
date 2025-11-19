#!/bin/bash
set -e

echo "=== Local Development Environment ==="
echo ""
echo "This will start the application locally using containers"
echo ""

# Check for container runtime
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
else
    echo "Error: Neither podman nor docker found."
    echo "Please install one of them:"
    echo "  - Podman: https://podman.io/getting-started/installation"
    echo "  - Docker: https://docs.docker.com/engine/install/"
    exit 1
fi

echo "Using container runtime: $CONTAINER_CMD"
echo ""

# Clean up any existing containers
echo "Cleaning up existing containers..."
$CONTAINER_CMD rm -f testcase-tracker-postgres testcase-tracker-app 2>/dev/null || true

# Start PostgreSQL (using host network for simplicity)
echo ""
echo "Starting PostgreSQL..."
$CONTAINER_CMD run -d \
  --name testcase-tracker-postgres \
  -e POSTGRES_USER=testcaseuser \
  -e POSTGRES_PASSWORD=changeme123 \
  -e POSTGRES_DB=testcases \
  -p 5432:5432 \
  docker.io/library/postgres:15

echo "Waiting for PostgreSQL to be ready..."
sleep 10

# Wait for postgres to have an IP
for i in {1..30}; do
    POSTGRES_IP=$($CONTAINER_CMD inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' testcase-tracker-postgres 2>/dev/null)
    if [ -n "$POSTGRES_IP" ]; then
        echo "PostgreSQL is accessible at IP: $POSTGRES_IP"
        break
    fi
    echo -n "."
    sleep 1
done

if [ -z "$POSTGRES_IP" ]; then
    echo ""
    echo "Error: Could not get PostgreSQL IP address"
    exit 1
fi

# Build the application image
echo ""
echo "Building application image..."
$CONTAINER_CMD build -t testcase-tracker:local .

# Get the IP of the postgres container (should already have it from above)
echo ""
echo "Connecting application to PostgreSQL at $POSTGRES_IP..."

# Start the application
echo ""
echo "Starting application..."
$CONTAINER_CMD run -d \
  --name testcase-tracker-app \
  --add-host=postgres:$POSTGRES_IP \
  -e DB_HOST=postgres \
  -e DB_PORT=5432 \
  -e DB_USER=testcaseuser \
  -e DB_PASSWORD=changeme123 \
  -e DB_NAME=testcases \
  -p 8080:8080 \
  testcase-tracker:local

echo ""
echo "=== Application Started! ==="
echo ""
echo "Access the application at: http://localhost:8080"
echo ""
echo "Useful commands:"
echo "  View app logs:      $CONTAINER_CMD logs -f testcase-tracker-app"
echo "  View postgres logs: $CONTAINER_CMD logs -f testcase-tracker-postgres"
echo "  Stop all:           $CONTAINER_CMD stop testcase-tracker-app testcase-tracker-postgres"
echo "  Remove all:         $CONTAINER_CMD rm -f testcase-tracker-app testcase-tracker-postgres"
echo ""
echo "Press Ctrl+C to view logs (containers will keep running in background)"
echo ""

# Follow logs
sleep 2
$CONTAINER_CMD logs -f testcase-tracker-app
