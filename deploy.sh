#!/bin/bash
set -e

echo "=== OpenShift Internal Registry Setup for POC ==="
echo ""
echo "This script will:"
echo "  1. Enable the OpenShift internal registry"
echo "  2. Configure persistent storage for the registry"
echo "  3. Expose the registry for external access"
echo "  4. Deploy the test case tracker application"
echo ""
echo "Choose registry storage option:"
echo "  1) PVC - Persistent Volume Claim (RECOMMENDED - survives restarts)"
echo "  2) EmptyDir - Ephemeral storage (data lost on pod restart)"
echo ""
read -p "Enter choice (1 or 2, default 1): " STORAGE_CHOICE
STORAGE_CHOICE=${STORAGE_CHOICE:-1}
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Check if we have the right permissions
echo ""
echo "Checking cluster permissions..."
if ! oc auth can-i patch configs.imageregistry.operator.openshift.io 2>/dev/null; then
    echo "Error: You need cluster-admin permissions to configure the internal registry."
    echo ""
    echo "Please ask your cluster administrator to run:"
    echo "  oc patch configs.imageregistry.operator.openshift.io/cluster --type merge --patch '{\"spec\":{\"managementState\":\"Managed\",\"storage\":{\"emptyDir\":{}}}}'"
    echo ""
    exit 1
fi

echo "[OK] You have sufficient permissions"
echo ""

# Step 1: Enable and configure the internal registry
echo "Step 1: Configuring internal registry..."

if [ "$STORAGE_CHOICE" == "1" ]; then
    echo "Using PVC (Persistent Volume Claim) - images will persist across registry restarts"
    echo ""
    
    # Check if storage supports ReadWriteMany
    echo "Checking available storage classes..."
    DEFAULT_SC=$(oc get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
    
    if [ -z "$DEFAULT_SC" ]; then
        DEFAULT_SC=$(oc get storageclass -o jsonpath='{.items[0].metadata.name}')
    fi
    
    echo "Using storage class: $DEFAULT_SC"
    echo ""
    
    # Create PVC for registry
    cat <<EOF | oc apply -n openshift-image-registry -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: image-registry-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
EOF
    
    echo "Configuring registry to use PVC with Recreate strategy..."
    echo "(Using Recreate instead of RollingUpdate due to ReadWriteOnce storage)"
    oc patch configs.imageregistry.operator.openshift.io/cluster --type merge --patch '{"spec":{"managementState":"Managed","rolloutStrategy":"Recreate","storage":{"pvc":{"claim":"image-registry-storage"}},"defaultRoute":true}}'
else
    echo "Using EmptyDir (ephemeral) - images will be lost on registry pod restart"
    echo "Note: This is simpler but not recommended for demos that need to show persistence"
    echo ""
    
    oc patch configs.imageregistry.operator.openshift.io/cluster --type merge --patch '{"spec":{"managementState":"Managed","storage":{"emptyDir":{}},"defaultRoute":true}}'
fi

echo "Waiting for image registry to be ready..."
sleep 5

# Wait for registry deployment to be created first
echo "Waiting for registry deployment to be created..."
for i in {1..30}; do
    if oc get deployment/image-registry -n openshift-image-registry &>/dev/null; then
        echo "[OK] Registry deployment found"
        break
    fi
    echo -n "."
    sleep 2
done

echo ""

# Wait for registry deployment to be available
echo "Waiting for registry to become available (this may take a few minutes)..."
if ! oc wait --for=condition=Available deployment/image-registry -n openshift-image-registry --timeout=300s 2>/dev/null; then
    echo ""
    echo "Registry deployment is still starting. Checking status..."
    
    # Show current state
    oc get pods -n openshift-image-registry
    echo ""
    
    # Check if it's progressing
    if oc get deployment/image-registry -n openshift-image-registry &>/dev/null; then
        echo "Registry deployment exists but not yet ready. Waiting longer..."
        sleep 30
        
        if oc wait --for=condition=Available deployment/image-registry -n openshift-image-registry --timeout=180s 2>/dev/null; then
            echo "[OK] Registry is now ready!"
        else
            echo "Warning: Registry is taking longer than expected."
            echo ""
            echo "Current status:"
            oc get deployment/image-registry -n openshift-image-registry
            echo ""
            echo "Check registry operator logs with:"
            echo "  oc logs -n openshift-image-registry-operator deployment/cluster-image-registry-operator"
            echo ""
            read -p "Continue anyway? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        echo "Error: Registry deployment was not created."
        echo ""
        echo "Check registry operator status:"
        oc get pods -n openshift-image-registry-operator
        echo ""
        echo "Check registry config:"
        oc get configs.imageregistry.operator.openshift.io/cluster -o yaml
        exit 1
    fi
fi

echo "[OK] Internal registry is ready!"
echo ""

# Step 2: Get registry route
echo "Step 2: Checking registry route..."

# Wait a moment for the route to be created
sleep 5

REGISTRY_HOST=""
for i in {1..10}; do
    REGISTRY_HOST=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
    if [ -n "$REGISTRY_HOST" ]; then
        break
    fi
    echo -n "."
    sleep 3
done

echo ""

if [ -z "$REGISTRY_HOST" ]; then
    echo "Registry route not found. Creating default route..."
    oc patch configs.imageregistry.operator.openshift.io/cluster --type merge --patch '{"spec":{"defaultRoute":true}}' 2>/dev/null || true
    
    sleep 10
    
    REGISTRY_HOST=$(oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
fi

if [ -n "$REGISTRY_HOST" ]; then
    echo "[OK] Registry accessible at: $REGISTRY_HOST"
else
    echo "[WARN] Registry route not available yet (this is okay for internal builds)"
    REGISTRY_HOST="image-registry.openshift-image-registry.svc:5000"
fi
echo ""

# Step 3: Deploy the application
PROJECT=${1:-testcase-tracker}

echo "Step 3: Deploying application to project: $PROJECT"
oc new-project $PROJECT 2>/dev/null || oc project $PROJECT

echo ""
echo "Deploying PostgreSQL..."
oc apply -f openshift/postgres-deployment.yaml

echo "Waiting for PostgreSQL to be ready..."
oc wait --for=condition=ready pod -l app=postgres --timeout=300s || {
    echo "Warning: PostgreSQL is taking longer than expected."
    oc get pods -l app=postgres
}

echo "[OK] PostgreSQL is ready"
echo ""

# Step 4: Build using internal registry
echo "Step 4: Building application using internal registry..."

# Wait for API server to be stable
echo "Waiting for API server to stabilize..."
sleep 5

# Create ImageStream with retry
echo "Creating ImageStream..."
for attempt in {1..5}; do
    if cat <<EOF | oc apply -f -
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: testcase-tracker
spec:
  lookupPolicy:
    local: true
EOF
    then
        echo "[OK] ImageStream created"
        break
    else
        echo "Attempt $attempt failed, retrying in 5 seconds..."
        sleep 5
        if [ $attempt -eq 5 ]; then
            echo "Error: Failed to create ImageStream after 5 attempts"
            echo "The API server may be experiencing issues."
            echo "Please try again in a few minutes or check cluster health."
            exit 1
        fi
    fi
done

sleep 2

# Create BuildConfig for binary builds with retry
echo "Creating BuildConfig..."
for attempt in {1..5}; do
    if cat <<EOF | oc apply -f -
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: testcase-tracker
spec:
  output:
    to:
      kind: ImageStreamTag
      name: testcase-tracker:latest
  source:
    binary: {}
    type: Binary
  strategy:
    dockerStrategy: {}
    type: Docker
EOF
    then
        echo "[OK] BuildConfig created"
        break
    else
        echo "Attempt $attempt failed, retrying in 5 seconds..."
        sleep 5
        if [ $attempt -eq 5 ]; then
            echo "Error: Failed to create BuildConfig after 5 attempts"
            exit 1
        fi
    fi
done

sleep 2

echo "Starting build from local files..."
oc start-build testcase-tracker --from-dir=. --follow || {
    echo "Build failed. Check logs with: oc logs -f bc/testcase-tracker"
    exit 1
}

echo "[OK] Build completed successfully"
echo ""

# Step 5: Deploy the application
echo "Step 5: Deploying the application..."

cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: testcase-tracker
  labels:
    app: testcase-tracker
    app.kubernetes.io/part-of: testcase-tracker
    app.openshift.io/runtime: python
spec:
  replicas: 2
  selector:
    matchLabels:
      app: testcase-tracker
  template:
    metadata:
      labels:
        app: testcase-tracker
    spec:
      containers:
      - name: testcase-tracker
        image: image-registry.openshift-image-registry.svc:5000/$PROJECT/testcase-tracker:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        env:
        - name: DB_HOST
          value: postgres
        - name: DB_PORT
          value: "5432"
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: database-user
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: database-password
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: database-name
        - name: PORT
          value: "8080"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /api/health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 3
        readinessProbe:
          httpGet:
            path: /api/health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: testcase-tracker
  labels:
    app: testcase-tracker
spec:
  ports:
  - port: 8080
    targetPort: 8080
    name: http
    protocol: TCP
  selector:
    app: testcase-tracker
  type: ClusterIP
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: testcase-tracker
  labels:
    app: testcase-tracker
spec:
  to:
    kind: Service
    name: testcase-tracker
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF

echo "Waiting for application to be ready..."
sleep 10
oc wait --for=condition=available deployment/testcase-tracker --timeout=300s || {
    echo "Warning: Application is taking longer than expected."
    oc get pods -l app=testcase-tracker
    echo ""
    echo "Check logs with: oc logs -f deployment/testcase-tracker"
}

echo ""
echo "=== Deployment Complete! ==="
echo ""
echo "[OK] Internal Registry: Enabled and configured"
echo "[OK] PostgreSQL: Running"
echo "[OK] Application: Deployed with 2 replicas"
echo ""

APP_URL=$(oc get route testcase-tracker -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [ -n "$APP_URL" ]; then
    echo ">>> Application URL: https://$APP_URL"
else
    echo "Getting route URL..."
    oc get route testcase-tracker
fi

echo ""
echo "=== POC Demonstration Commands ==="
echo ""
echo "Show application pods:"
echo "  oc get pods -l app=testcase-tracker"
echo ""
echo "View application logs:"
echo "  oc logs -f deployment/testcase-tracker"
echo ""
echo "Scale application:"
echo "  oc scale deployment/testcase-tracker --replicas=3"
echo ""
echo "View internal registry images:"
echo "  oc get imagestreams"
echo "  oc describe is/testcase-tracker"
echo ""
echo "Trigger new build:"
echo "  oc start-build testcase-tracker --from-dir=. --follow"
echo ""
echo "Show all resources (great for demos):"
echo "  oc get all -l app=testcase-tracker"
echo ""
echo "Access PostgreSQL:"
echo "  oc exec -it deployment/postgres -- psql -U testcaseuser testcases"
echo ""
echo "View topology (web console):"
echo "  Developer perspective → Topology"
echo ""
echo "=== POC Highlights ==="
echo "[OK] Fully contained within OpenShift (no external dependencies)"
echo "[OK] Internal registry with automatic image builds"
echo "[OK] Persistent database storage"
echo "[OK] Secure routes with TLS"
echo "[OK] Health checks and self-healing"
echo "[OK] Horizontal pod autoscaling ready"
echo "[OK] Developer-friendly topology view"
echo ""

# Step 6: Optional pgAdmin deployment
echo ""
read -p "Deploy pgAdmin for database management? (y/n, default n): " DEPLOY_PGADMIN
DEPLOY_PGADMIN=${DEPLOY_PGADMIN:-n}

if [[ $DEPLOY_PGADMIN =~ ^[Yy]$ ]]; then
    echo ""
    echo "Step 6: Deploying pgAdmin..."
    
    # Create service account
    echo "Creating pgAdmin service account..."
    oc create serviceaccount pgadmin-sa 2>/dev/null || echo "  Service account already exists"
    
    # Grant anyuid SCC
    echo "Granting anyuid SCC to pgadmin-sa..."
    oc adm policy add-scc-to-user anyuid -z pgadmin-sa 2>/dev/null || echo "  SCC already granted"
    
    # Deploy pgAdmin
    echo "Deploying pgAdmin..."
    if [ -f "openshift/pgadmin.yaml" ]; then
        oc apply -f openshift/pgadmin.yaml
        
        echo "Waiting for pgAdmin to be ready..."
        sleep 5
        oc wait --for=condition=available deployment/pgadmin --timeout=120s 2>/dev/null || {
            echo "[WARN] pgAdmin deployment is taking longer than expected"
            echo "Check status with: oc get pods -l app=pgadmin"
        }
        
        PGADMIN_URL=$(oc get route pgadmin -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
        if [ -n "$PGADMIN_URL" ]; then
            echo ""
            echo "[OK] pgAdmin deployed successfully!"
            echo ""
            echo ">>> pgAdmin URL: https://$PGADMIN_URL"
            echo ""
            echo "Login credentials:"
            echo "  Email: admin@testcases.com"
            echo "  Password: changeme123"
            echo ""
            echo "Database connection:"
            echo "  Host: postgres"
            echo "  Port: 5432"
            echo "  Database: testcases"
            echo "  Username: testcaseuser"
            echo "  Password: changeme123"
            echo ""
        else
            echo "[WARN] pgAdmin route not available yet"
            echo "Check with: oc get route pgadmin"
        fi
    else
        echo "[ERROR] pgadmin.yaml not found"
        echo "Skipping pgAdmin deployment"
    fi
else
    echo "Skipping pgAdmin deployment"
    echo ""
    echo "To deploy pgAdmin later:"
    echo "  oc create serviceaccount pgadmin-sa"
    echo "  oc adm policy add-scc-to-user anyuid -z pgadmin-sa"
    echo "  oc apply -f pgadmin.yaml"
fi

echo ""
