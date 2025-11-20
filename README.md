# OpenShift Virtualization Test Plan Tracker

A containerized web application for tracking OpenShift Virtualization test cases and results, deployed on OpenShift with PostgreSQL database persistence.

## Quick Start

```bash
# Log into OpenShift
oc login

# Deploy everything
./deploy.sh
```

That's it! The script will configure the internal registry, deploy PostgreSQL, build and deploy the application.

**For POC demos**: See [POC_GUIDE.md](POC_GUIDE.md) for presentation tips and demo scenarios  
**For detailed steps**: See [DEPLOYMENT.md](DEPLOYMENT.md) for manual deployment options  
**For troubleshooting**: See [QUICKSTART.md](QUICKSTART.md) for common issues

## Architecture

- **Backend**: Python Flask REST API
- **Database**: PostgreSQL 15
- **Frontend**: HTML/CSS/JavaScript (vanilla)
- **Container**: Docker/Podman
- **Platform**: OpenShift Container Platform

## Features

- Track 36 comprehensive test cases across 14 phases
- Real-time status updates (Pass/Fail/Pending)
- Date tracking and tester assignment
- Comments and notes for each test
- Statistics dashboard
- Excel export functionality
- Filter by phase and status
- Database persistence
- RESTful API
- OpenShift-ready deployment

## Quick Start - Local Development

### Prerequisites

- Python 3.11+
- PostgreSQL 15+
- pip

### Local Setup

1. **Install PostgreSQL and create database:**

```bash
# On Linux
sudo apt-get install postgresql postgresql-contrib

# Start PostgreSQL
sudo systemctl start postgresql

# Create database
sudo -u postgres psql -c "CREATE DATABASE testcases;"
sudo -u postgres psql -c "CREATE USER testcaseuser WITH PASSWORD 'changeme123';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE testcases TO testcaseuser;"
```

2. **Install Python dependencies:**

```bash
pip install -r requirements.txt
```

3. **Set environment variables:**

```bash
export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=testcaseuser
export DB_PASSWORD=changeme123
export DB_NAME=testcases
export PORT=8080
```

4. **Run the application:**

```bash
python app.py
```

5. **Access the application:**

Open your browser to: `http://localhost:8080`

## 🐳 Docker Deployment

### Build the image:

```bash
docker build -t testcase-tracker:latest .
```

### Run with Docker Compose (optional):

Create a `docker-compose.yml`:

```yaml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: testcases
      POSTGRES_USER: testcaseuser
      POSTGRES_PASSWORD: changeme123
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  app:
    image: testcase-tracker:latest
    environment:
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USER: testcaseuser
      DB_PASSWORD: changeme123
      DB_NAME: testcases
      PORT: 8080
    ports:
      - "8080:8080"
    depends_on:
      - postgres

volumes:
  postgres_data:
```

Run:
```bash
docker-compose up -d
```

## OpenShift Deployment

### Quick Deployment

For a complete OpenShift POC deployment with internal registry:

```bash
./deploy.sh
```

This automated script will:
1. Enable and configure the internal registry with persistent storage
2. Deploy PostgreSQL with persistent storage  
3. Build the application using the internal registry
4. Deploy with 2 replicas and health checks
5. Create a secure HTTPS route

**Prerequisites**:
- OpenShift CLI (`oc`) installed and logged in
- cluster-admin permissions (for registry setup)

**Access your application**:
```bash
oc get route testcase-tracker -o jsonpath='https://{.spec.host}'
```

### Verify Deployment

```bash
# Check all pods are running
oc get pods

# Check application logs
oc logs -f deployment/testcase-tracker

# Check PostgreSQL logs
oc logs -f deployment/postgres

# Test the API
curl $(oc get route testcase-tracker -o jsonpath='{.spec.host}')/api/health
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_HOST` | PostgreSQL host | `localhost` |
| `DB_PORT` | PostgreSQL port | `5432` |
| `DB_USER` | Database user | `postgres` |
| `DB_PASSWORD` | Database password | `postgres` |
| `DB_NAME` | Database name | `testcases` |
| `PORT` | Application port | `8080` |

### Security Best Practices

1. **Change default passwords:**
```bash
# Update the secret
oc create secret generic postgres-secret \
  --from-literal=database-user=testcaseuser \
  --from-literal=database-password=YOUR_STRONG_PASSWORD \
  --from-literal=database-name=testcases \
  --dry-run=client -o yaml | oc apply -f -

# Rollout restart to pick up new secret
oc rollout restart deployment/postgres
oc rollout restart deployment/testcase-tracker
```

2. **Use Network Policies** to restrict database access
3. **Enable TLS** for the route (already configured in deployment)

## API Documentation

### pgAdmin Database Access (Optional)

For web-based database management, deploy pgAdmin:

```bash
# Create service account and grant permissions
oc create serviceaccount pgadmin-sa
oc adm policy add-scc-to-user anyuid -z pgadmin-sa

# Deploy pgAdmin
oc apply -f pgadmin.yaml

# Get the URL
oc get route pgadmin -o jsonpath='https://{.spec.host}'
```

Login to pgAdmin with credentials from `pgadmin.yaml` and connect to the database:
- Host: `postgres`
- Port: `5432`
- Database: `testcases`
- Username: `testcaseuser`
- Password: `changeme123`

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/health` | Health check |
| `GET` | `/api/test-cases` | Get all test cases with results |
| `GET` | `/api/test-results` | Get all test results |
| `GET` | `/api/test-results/<test_id>` | Get specific test result |
| `PUT` | `/api/test-results/<test_id>` | Update test result |
| `GET` | `/api/stats` | Get test statistics |
| `GET` | `/api/export` | Export data for Excel |

### Example API Calls

```bash
# Health check
curl https://your-app-url/api/health

# Get all test cases
curl https://your-app-url/api/test-cases

# Update a test result
curl -X PUT https://your-app-url/api/test-results/1.1 \
  -H "Content-Type: application/json" \
  -d '{
    "status": "Pass",
    "date_tested": "2025-11-18",
    "tester": "John Doe",
    "comments": "All checks passed successfully"
  }'

# Get statistics
curl https://your-app-url/api/stats
```

## Maintenance

### Database Backup

```bash
# Backup database
oc exec deployment/postgres -- pg_dump -U testcaseuser testcases > backup.sql

# Restore database
cat backup.sql | oc exec -i deployment/postgres -- psql -U testcaseuser testcases
```

### Scaling

```bash
# Scale application pods
oc scale deployment/testcase-tracker --replicas=3

# PostgreSQL should remain at 1 replica (no HA configured)
```

### Monitoring

```bash
# Watch pod status
oc get pods -w

# Check resource usage
oc adm top pods

# View events
oc get events --sort-by='.lastTimestamp'
```

## 🐛 Troubleshooting

### Application won't start

```bash
# Check logs
oc logs -f deployment/testcase-tracker

# Check database connectivity
oc exec deployment/testcase-tracker -- ping postgres
```

### Database connection issues

```bash
# Check PostgreSQL logs
oc logs -f deployment/postgres

# Verify secret
oc get secret postgres-secret -o yaml

# Test database connection
oc exec deployment/postgres -- psql -U testcaseuser -d testcases -c "SELECT 1;"
```

### Image pull errors

```bash
# Check ImageStream
oc get imagestream

# Trigger new build
oc start-build testcase-tracker --follow
```

## Test Cases Included

The application includes 36 test cases across 14 phases:

1. **Phase 1**: Installation and Configuration (2 tests)
2. **Phase 2**: Storage Testing (3 tests)
3. **Phase 3**: Network Testing (4 tests)
4. **Phase 4**: Backup and Restore (3 tests)
5. **Phase 5**: Identity and Access Management (3 tests)
6. **Phase 6**: High Availability and DR (3 tests)
7. **Phase 7**: VM Lifecycle Management (3 tests)
8. **Phase 8**: Windows VM Support (2 tests)
9. **Phase 9**: Performance and Scalability (3 tests)
10. **Phase 10**: Monitoring and Observability (2 tests)
11. **Phase 11**: Migration from VMware (2 tests)
12. **Phase 12**: Day 2 Operations (2 tests)
13. **Phase 13**: Security and Compliance (2 tests)
14. **Phase 14**: Cost Analysis (1 test)

## Contributing

To add new test cases or features:

1. Update `app.py` to add new test cases in the `init_test_cases()` function
2. Rebuild and redeploy the application

## License

This project is provided as-is for internal use.

## Related Resources

- [OpenShift Virtualization Documentation](https://docs.openshift.com/container-platform/latest/virt/about-virt.html)
- [Migration Toolkit for Virtualization](https://docs.openshift.com/container-platform/latest/migration_toolkit_for_virtualization/about-mtv.html)
