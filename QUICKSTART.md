# OpenShift Virtualization Test Case Tracker - Quick Start

## Deployment

Run the automated deployment script:

```bash
./deploy.sh
```

## What You'll Need

- OpenShift cluster access (POC/CRC/production)
- `oc` CLI installed and logged in (`oc login`)
- **cluster-admin** permissions (script will configure internal registry)

The script will prompt you to choose between:
1. **PVC storage** (persistent - recommended)
2. **EmptyDir storage** (ephemeral)

Choose option 1 for production-like demos.

## After Deployment

Access your application at the provided URL (will be something like):
```
https://testcase-tracker-testcase-tracker.apps.xps.planenotsimple.com
```

## Troubleshooting

### PostgreSQL not starting
```bash
oc logs -f deployment/postgres
oc describe pod -l app=postgres
```

### Application not starting
```bash
oc logs -f deployment/testcase-tracker
oc get pods
oc describe pod -l app=testcase-tracker
```

### Need to start over
```bash
oc delete project testcase-tracker
# Wait a minute, then run the script again
./deploy.sh
```

## Alternative: If You Have Cluster Admin

The automated script handles this, but if you want to manually configure the registry:

```bash
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge --patch '{"spec":{"storage":{"emptyDir":{}}}}'

# Wait for registry to be ready
oc wait --for=condition=Available deployment/image-registry -n openshift-image-registry --timeout=300s

# Then deploy
./deploy.sh
```
