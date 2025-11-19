#!/bin/bash
set -e

echo "=== Simple Local Test with Podman Pod ==="
echo ""

# Clean up
echo "Cleaning up..."
podman pod rm -f testcase-pod 2>/dev/null || true
podman rm -f testcase-postgres testcase-app 2>/dev/null || true

# Create a pod (containers in a pod share localhost)
echo "Creating pod..."
podman pod create --name testcase-pod -p 8080:8080

# Start PostgreSQL in the pod
echo "Starting PostgreSQL..."
podman run -d \
  --name testcase-postgres \
  --pod testcase-pod \
  -e POSTGRES_USER=testcaseuser \
  -e POSTGRES_PASSWORD=changeme123 \
  -e POSTGRES_DB=testcases \
  docker.io/library/postgres:15

echo "Waiting for PostgreSQL..."
sleep 10

# Build the app
echo "Building application..."
podman build -t testcase-tracker:local .

# Start the app in the same pod
echo "Starting application..."
podman run -d \
  --name testcase-app \
  --pod testcase-pod \
  -e DB_HOST=localhost \
  -e DB_PORT=5432 \
  -e DB_USER=testcaseuser \
  -e DB_PASSWORD=changeme123 \
  -e DB_NAME=testcases \
  testcase-tracker:local

echo ""
echo "=== Application Started! ==="
echo ""
echo "Access at: http://localhost:8080"
echo ""
echo "View logs: podman logs -f testcase-app"
echo "Stop all:  podman pod stop testcase-pod"
echo "Remove:    podman pod rm -f testcase-pod"
echo ""
echo "Following application logs..."
sleep 3
podman logs -f testcase-app
