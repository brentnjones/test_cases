# OpenShift POC Deployment Guide

This guide is for deploying the Test Case Tracker on a POC OpenShift cluster using **only internal OpenShift components** - perfect for showcasing OpenShift capabilities.

## 🎯 POC Benefits

This deployment showcases:
- ✅ **No external dependencies** - everything runs inside OpenShift
- ✅ **Internal container registry** - built-in image storage and distribution
- ✅ **Binary builds** - upload and build from local source code
- ✅ **Source-to-Image** capabilities
- ✅ **Persistent storage** - database with PVC
- ✅ **Secure routes** - automatic TLS termination
- ✅ **Health checks** - self-healing applications
- ✅ **Scaling** - horizontal pod autoscaling
- ✅ **Developer Console** - visual topology view

## 🚀 One-Command Deployment

```bash
./deploy.sh
```

This script will:
1. ✅ Enable and configure the internal registry with **persistent storage**
2. ✅ Deploy PostgreSQL with persistent storage
3. ✅ Build the application using internal registry
4. ✅ Deploy with 2 replicas and health checks
5. ✅ Create a secure HTTPS route

## Why Persistent Storage?

The script uses **PVC (Persistent Volume Claims)** for both:
- **Registry storage** - Container images persist across registry restarts
- **Database storage** - Test case data persists across database restarts

This shows customers a production-ready setup, not just a throwaway demo.

## 📋 Prerequisites

- OpenShift cluster access (POC/CRC/sandbox)
- `oc` CLI installed and logged in
- **cluster-admin** permissions (for registry setup)

### Check Your Permissions

```bash
oc auth can-i patch configs.imageregistry.operator.openshift.io
# Should return: yes
```

If you don't have cluster-admin, ask your administrator to run:
```bash
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge \
  --patch '{"spec":{"managementState":"Managed","storage":{"emptyDir":{}},"defaultRoute":true}}'
```

## 🎬 POC Demo Script

Perfect for walking through OpenShift features with customers:

### 1. Show Initial State
```bash
oc whoami --show-console
# Open the web console in browser

oc get projects
oc cluster-info
```

### 2. Deploy the Application
```bash
./deploy.sh
# Walk through each step as it executes
```

### 3. Show in Web Console
- Navigate to **Developer** perspective
- Click **Topology** 
- Show the visual application map
- Click on pods to show logs, metrics, terminal

### 4. Demonstrate Key Features

#### A. Show Internal Registry
```bash
# List images in internal registry
oc get imagestreams
oc describe imagestream testcase-tracker

# Show registry route
oc get route -n openshift-image-registry
```

#### B. Show Build Process
```bash
# View build history
oc get builds

# Trigger a new build
oc start-build testcase-tracker --from-dir=. --follow

# Show build logs in real-time
```

#### C. Show Application Scaling
```bash
# Scale up
oc scale deployment/testcase-tracker --replicas=4
oc get pods -w

# Scale down
oc scale deployment/testcase-tracker --replicas=2
```

#### D. Show Self-Healing
```bash
# Delete a pod
oc get pods -l app=testcase-tracker
oc delete pod <pod-name>

# Watch it automatically recreate
oc get pods -w
```

#### E. Show Database Persistence
```bash
# Access the database
oc exec -it deployment/postgres -- psql -U testcaseuser testcases

# Inside psql:
\dt
SELECT * FROM test_cases LIMIT 5;
SELECT * FROM test_results;
\q
```

#### F. Show Rolling Updates
```bash
# Trigger a rolling update
oc rollout restart deployment/testcase-tracker

# Watch the rolling update
oc rollout status deployment/testcase-tracker
```

#### G. Show Application Logs
```bash
# Stream logs
oc logs -f deployment/testcase-tracker

# Show logs from all pods
oc logs -l app=testcase-tracker --tail=20
```

### 5. Show Resource Management
```bash
# View all resources
oc get all -l app=testcase-tracker

# Show resource utilization
oc adm top pods
oc adm top nodes

# Show resource limits
oc describe deployment/testcase-tracker
```

### 6. Show Security Features
```bash
# Show secure route with TLS
oc get route testcase-tracker
curl -I https://$(oc get route testcase-tracker -o jsonpath='{.spec.host}')

# Show secrets management
oc get secrets postgres-secret -o yaml

# Show service accounts
oc get sa
```

## 🎤 POC Talking Points

### For Infrastructure Teams
- "The internal registry eliminates external dependencies"
- "EmptyDir storage is perfect for POC - can upgrade to persistent storage in production"
- "Built-in TLS termination on routes - no separate load balancer needed"
- "Health checks enable automatic pod recovery"

### For Development Teams
- "Binary builds let you deploy from local code instantly"
- "The topology view shows application dependencies visually"
- "Rolling updates enable zero-downtime deployments"
- "Built-in logging and monitoring - no additional setup needed"

### For Operations Teams
- "Scaling is a single command - manual or automatic"
- "Self-healing pods reduce operational overhead"
- "All configuration through declarative YAML"
- "Full audit trail through OpenShift events"

### For Management
- "Reduces vendor dependencies - everything is OpenShift"
- "Faster time to market with built-in CI/CD"
- "Lower operational costs with automation"
- "Enterprise support from Red Hat"

## 📊 Show the Application

Once deployed, access the application and demonstrate:

1. **Test Case Tracking**
   - Show all 36 test cases across 14 phases
   - Update a test status (Pending → Pass/Fail)
   - Add tester name and comments
   - Show real-time statistics update

2. **Data Persistence**
   - Make changes in the application
   - Restart a pod: `oc delete pod <pod-name>`
   - Refresh browser - data persists!

3. **Export Feature**
   - Click "Export to Excel"
   - Show the generated report

## 🔄 Application Updates

Show how easy it is to update the application:

```bash
# Make code changes to app.py or static/index.html

# Rebuild and deploy
oc start-build testcase-tracker --from-dir=. --follow

# Rolling update happens automatically
oc rollout status deployment/testcase-tracker
```

## 🧹 Cleanup After Demo

```bash
# Delete the project (removes everything)
oc delete project testcase-tracker

# To keep registry for other demos
# (registry stays enabled for future use)
```

## 🔧 Troubleshooting

### Registry Not Starting
```bash
# Check registry operator
oc get pods -n openshift-image-registry
oc logs -n openshift-image-registry deployment/image-registry

# Check registry config
oc get configs.imageregistry.operator.openshift.io/cluster -o yaml
```

### Build Failing
```bash
# View build logs
oc logs -f bc/testcase-tracker

# Check recent builds
oc get builds
oc describe build testcase-tracker-1
```

### Application Not Starting
```bash
# Check pods
oc get pods -l app=testcase-tracker
oc describe pod <pod-name>
oc logs <pod-name>

# Check events
oc get events --sort-by='.lastTimestamp' | grep testcase-tracker
```

### Database Connection Issues
```bash
# Check PostgreSQL
oc get pods -l app=postgres
oc logs deployment/postgres

# Test connection from app pod
oc exec deployment/testcase-tracker -- nc -zv postgres 5432
```

## 📈 Advanced POC Topics

### Add pgAdmin for Database Access

To provide a web-based database management interface:

```bash
# Create service account with required permissions
oc create serviceaccount pgadmin-sa
oc adm policy add-scc-to-user anyuid -z pgadmin-sa

# Deploy pgAdmin
oc apply -f pgadmin.yaml
```

**Access pgAdmin**:
```bash
# Get the pgAdmin URL
oc get route pgadmin -o jsonpath='https://{.spec.host}'
echo ""

# Login credentials (from pgadmin.yaml)
# Email: brentjon@redhat.com
# Password: redhat123
```

**Connect to Database**:
- Click "Add New Server"
- General tab:
  - Name: `Test Case Tracker`
- Connection tab:
  - Host: `postgres`
  - Port: `5432`
  - Database: `testcases`
  - Username: `testcaseuser`
  - Password: `changeme123`

**Demo Value**: Shows customers how to provide database access tools without installing software locally.

### Add Monitoring
```bash
# OpenShift comes with Prometheus - show metrics
oc get servicemonitor

# Access Prometheus in web console:
# Administrator → Observe → Metrics
```

### Add Horizontal Pod Autoscaler
```bash
oc autoscale deployment/testcase-tracker \
  --min=2 --max=5 --cpu-percent=80

# Generate load and watch it scale
```

### Configure Resource Quotas
```bash
# Show how to set project limits (great for multi-tenancy demos)
oc create quota project-quota \
  --hard=pods=20,requests.cpu=4,requests.memory=8Gi
```

## 🎁 Bonus: CI/CD Demo

Show how to set up automated builds from Git:

```bash
# Create BuildConfig from Git
oc new-build https://github.com/YOUR_REPO/testcase-tracker.git \
  --name=testcase-tracker-git \
  --strategy=docker

# Automatic rebuilds on Git commits (with webhooks)
```

## 📚 Documentation to Share

After the demo, share:
- This deployment guide
- `README.md` - Application overview
- `DEPLOYMENT.md` - Deployment options
- OpenShift documentation links

## 🎯 Success Criteria for POC

✅ Application accessible via HTTPS route  
✅ Database persisting data across pod restarts  
✅ Scaling demonstrated (manual)  
✅ Self-healing demonstrated  
✅ Updates/rollbacks demonstrated  
✅ Internal registry functioning  
✅ Developer console navigation shown  
✅ Basic monitoring/logging shown  

Perfect for showing VMware customers what OpenShift can do! 🚀
