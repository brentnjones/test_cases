# OpenShift Deployment Guide

## Automated Deployment (Recommended)

For a complete POC deployment with internal registry:

```bash
./deploy.sh
```

The script will:
- Configure the internal registry with persistent storage
- Deploy PostgreSQL
- Build and deploy the application
- Create secure routes

**Requirements**: cluster-admin permissions to configure the registry.

## Manual Deployment Steps

### Using Docker Hub:
```bash
# Login to Docker Hub
podman login docker.io

# Build and push
podman build -t docker.io/YOUR_USERNAME/testcase-tracker:latest .
podman push docker.io/YOUR_USERNAME/testcase-tracker:latest

# Deploy to OpenShift
oc new-project testcase-tracker
oc apply -f openshift/postgres-deployment.yaml
oc wait --for=condition=ready pod -l app=postgres --timeout=300s

# Create ImageStream from external image
oc import-image testcase-tracker:latest --from=docker.io/YOUR_USERNAME/testcase-tracker:latest --confirm

# Update and deploy
sed "s|image-registry.openshift-image-registry.svc:5000/YOUR_PROJECT/testcase-tracker:latest|docker.io/YOUR_USERNAME/testcase-tracker:latest|g" openshift/app-deployment.yaml | oc apply -f -
```

### Using Quay.io:
```bash
# Login to Quay.io
podman login quay.io

# Build and push
podman build -t quay.io/YOUR_USERNAME/testcase-tracker:latest .
podman push quay.io/YOUR_USERNAME/testcase-tracker:latest

# Deploy to OpenShift
oc new-project testcase-tracker
oc apply -f openshift/postgres-deployment.yaml
oc wait --for=condition=ready pod -l app=postgres --timeout=300s

# Deploy with external image
sed "s|image-registry.openshift-image-registry.svc:5000/YOUR_PROJECT/testcase-tracker:latest|quay.io/YOUR_USERNAME/testcase-tracker:latest|g" openshift/app-deployment.yaml | oc apply -f -
```

## Option 3: Git Repository with Source-to-Image (S2I)

If your code is in a Git repository:

```bash
# Update openshift/buildconfig.yaml with your Git URL
vim openshift/buildconfig.yaml

# Deploy
oc new-project testcase-tracker
oc apply -f openshift/postgres-deployment.yaml
oc wait --for=condition=ready pod -l app=postgres --timeout=300s
oc apply -f openshift/buildconfig.yaml
oc start-build testcase-tracker --follow
oc apply -f openshift/app-deployment.yaml
```

## Manual Step-by-Step (Most Control)

If you want to see each step:

```bash
# 1. Create project
oc new-project testcase-tracker

# 2. Deploy PostgreSQL
oc apply -f openshift/postgres-deployment.yaml
oc wait --for=condition=ready pod -l app=postgres --timeout=300s

# 3. Create binary build
oc new-build --name=testcase-tracker --binary --strategy=docker

# 4. Build from local directory
oc start-build testcase-tracker --from-dir=. --follow

# 5. Deploy application
cat openshift/app-deployment.yaml | \
  sed "s|image-registry.openshift-image-registry.svc:5000/YOUR_PROJECT/testcase-tracker:latest|image-registry.openshift-image-registry.svc.cluster.local:5000/testcase-tracker/testcase-tracker:latest|g" | \
  oc apply -f -

# 6. Get the URL
oc get route testcase-tracker
```

## Troubleshooting

### Check if you're logged in:
```bash
oc whoami
oc cluster-info
```

### View build logs:
```bash
oc logs -f bc/testcase-tracker
```

### View application logs:
```bash
oc logs -f deployment/testcase-tracker
```

### Check pod status:
```bash
oc get pods
oc describe pod POD_NAME
```

### If database connection fails:
```bash
# Check database is running
oc get pods -l app=postgres

# Test database connection
oc exec deployment/postgres -- psql -U testcaseuser -d testcases -c "SELECT 1;"
```

## Which Option Should I Use?

- **Most Reliable**: Use **Option 1** (External Registry Script) - `./deploy-external-registry.sh`
- **Have Docker Hub/Quay account**: Use **Option 2** (Manual) for more control
- **Git-based workflows**: Use **Option 3** (S2I) if your cluster has internal registry configured

## Why Binary Builds Don't Work

Your OpenShift cluster's internal image registry doesn't have storage configured (`storage: {}`). This is why binary builds fail with "InvalidOutputReference: Output image could not be resolved."

To fix this cluster-wide (requires admin access):
```bash
# This requires cluster-admin permissions
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge --patch '{"spec":{"storage":{"emptyDir":{}}}}'
```

## Optional: Add pgAdmin for Database Management

To add a web-based interface for PostgreSQL:

```bash
# Create service account with required permissions (pgAdmin needs anyuid SCC)
oc create serviceaccount pgadmin-sa
oc adm policy add-scc-to-user anyuid -z pgadmin-sa

# Deploy pgAdmin
oc apply -f pgadmin.yaml

# Get the URL
oc get route pgadmin
```

**pgAdmin Login** (credentials in `pgadmin.yaml`):
- Email: `brentjon@redhat.com`
- Password: `redhat123`

**Database Connection**:
- Host: `postgres`
- Port: `5432`
- Database: `testcases`
- Username: `testcaseuser`
- Password: `changeme123`

**Note**: pgAdmin requires the `anyuid` Security Context Constraint (SCC) because the container runs with specific user permissions that don't align with OpenShift's default restricted SCC.
