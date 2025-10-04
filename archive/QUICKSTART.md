# TraderX ConfigHub Deployment - Quick Start Guide

Get TraderX deployed with ConfigHub in 15 minutes.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Deployment](#deployment)
4. [Validation](#validation)
5. [Access the Application](#access-the-application)
6. [Next Steps](#next-steps)
7. [Common Pitfalls](#common-pitfalls)

---

## Prerequisites

### Required Software

Before you begin, ensure you have these tools installed:

```bash
# Check if you have everything installed
which cub kubectl docker

# Expected output:
# /usr/local/bin/cub
# /usr/local/bin/kubectl
# /usr/local/bin/docker
```

If any are missing, install them:

#### 1. ConfigHub CLI (cub)
```bash
# macOS
brew install confighubai/tap/cub

# Verify installation
cub version
# Expected: v1.0.0 or higher
```

#### 2. Kubernetes CLI (kubectl)
```bash
# macOS
brew install kubectl

# Verify installation
kubectl version --client
```

#### 3. Docker Desktop
```bash
# macOS - Download from:
# https://www.docker.com/products/docker-desktop

# Start Docker Desktop
open -a Docker

# Wait 30-60 seconds for Docker to fully start

# Verify Docker is running
docker info
# Should show system information without errors
```

#### 4. Kubernetes Cluster

Choose one option:

**Option A: Kind (Recommended for local testing)**
```bash
# Install Kind
brew install kind

# Create cluster
kind create cluster --name traderx

# Set kubectl context
kubectl cluster-info --context kind-traderx

# Expected: Cluster info displayed
```

**Option B: Minikube**
```bash
# Install Minikube
brew install minikube

# Start cluster
minikube start --memory=4096 --cpus=2

# Set kubectl context
kubectl config use-context minikube
```

**Option C: Cloud Provider**
```bash
# Configure kubectl for your cloud provider
# - AWS EKS: aws eks update-kubeconfig --name <cluster-name>
# - GCP GKE: gcloud container clusters get-credentials <cluster-name>
# - Azure AKS: az aks get-credentials --name <cluster-name> --resource-group <rg>

# Verify connection
kubectl cluster-info
```

---

### Authentication

#### ConfigHub Login
```bash
# Login to ConfigHub
cub auth login

# Follow prompts to authenticate
# This opens a browser for OAuth login

# Verify authentication
cub auth status
# Expected: "Authenticated as <your-email>"
```

#### Kubernetes Access
```bash
# Verify kubectl can access cluster
kubectl get nodes

# Expected: At least one node in Ready state
```

---

## Installation

### Step 1: Clone or Navigate to Repository

```bash
# If you already have the repository
cd /Users/alexis/traderx

# Or clone it
# git clone <repository-url>
# cd traderx
```

### Step 2: Verify Prerequisites

Run our pre-flight check:

```bash
# Check Docker is running
docker info

# Check kubectl can access cluster
kubectl get nodes

# Check ConfigHub authentication
cub auth status

# All three should succeed before proceeding
```

---

## Deployment

### Step 1: Create ConfigHub Infrastructure (2-3 minutes)

```bash
# Create base ConfigHub structure
bin/install-base

# This creates:
# - Project prefix: mellow-muzzle-traderx
# - Base space: mellow-muzzle-traderx-base
# - Filters space: mellow-muzzle-traderx-filters
# - 7 filters (all, app, infra, frontend, backend, data, critical)
# - 2 sets (critical-services, data-services)
# - 17 units (namespace + 8 services × 2 resources each)
```

**Expected output:**
```
Creating ConfigHub base structure for TraderX...
Creating unique project prefix...
Project prefix: mellow-muzzle-traderx
Saving to .cub-project...

Creating base space...
✓ Created space: mellow-muzzle-traderx-base

Creating filters...
✓ Created filter: all
✓ Created filter: app
...

Creating sets...
✓ Created set: critical-services
✓ Created set: data-services

Creating units...
✓ Created unit: namespace
✓ Created unit: reference-data-deployment
✓ Created unit: reference-data-service
...

Base structure created successfully!
```

### Step 2: Create Environment Hierarchy (1-2 minutes)

```bash
# Create dev, staging, prod environments
bin/install-envs

# This creates:
# - Dev space: mellow-muzzle-traderx-dev
# - Staging space: mellow-muzzle-traderx-staging
# - Prod space: mellow-muzzle-traderx-prod
# - Clones all units to each environment
# - Sets up upstream/downstream relationships
```

**Expected output:**
```
Creating environment hierarchy...

Creating dev environment...
✓ Created space: mellow-muzzle-traderx-dev
✓ Cloned 17 units to dev

Creating staging environment...
✓ Created space: mellow-muzzle-traderx-staging
✓ Cloned 17 units to staging

Creating prod environment...
✓ Created space: mellow-muzzle-traderx-prod
✓ Cloned 17 units to prod

Environment hierarchy created successfully!
```

### Step 3: View ConfigHub Structure (Optional)

```bash
# View the environment hierarchy
cub unit tree --node=space --filter mellow-muzzle-traderx/all --space '*'

# Expected: Tree showing base → dev → staging → prod
```

### Step 4: Deploy to Kubernetes (3-5 minutes)

```bash
# Deploy all services to dev environment
bin/ordered-apply dev

# This deploys services in dependency order:
# 1. namespace
# 2. reference-data (data layer)
# 3. people-service
# 4. account-service
# 5. position-service
# 6. trade-service
# 7. trade-processor
# 8. trade-feed
# 9. web-gui (frontend)
# 10. ingress

# Each service waits for health checks before proceeding
```

**Expected output:**
```
Deploying services in dependency order to dev...

[1/9] Deploying namespace...
✓ Applied namespace
✓ Namespace active

[2/9] Deploying reference-data...
✓ Applied reference-data-deployment
✓ Applied reference-data-service
✓ Waiting for health check... (30s)
✓ reference-data is healthy

[3/9] Deploying people-service...
...

All services deployed successfully!
```

**Deployment time**: Approximately 3-5 minutes

---

## Validation

### Step 1: Run Comprehensive Validation

```bash
# Run full deployment validation
bin/validate-deployment dev

# This checks:
# - ConfigHub authentication
# - Project setup
# - ConfigHub spaces
# - ConfigHub units
# - Kubernetes namespace
# - Service deployments
# - Service endpoints
# - Pod health
# - Resource limits
# - Health probes
# - Ingress
# - ConfigHub live state
# - Labels and annotations
```

**Expected output:**
```
Running deployment validation for dev environment...

✓ ConfigHub authentication
✓ Project setup (.cub-project exists)
✓ ConfigHub spaces (5 spaces found)
✓ ConfigHub units (60 units across all environments)
✓ Kubernetes namespace (traderx-dev is Active)
✓ Service deployments (8/8 deployed)
✓ Service endpoints (8/8 have endpoints)
✓ Service dependencies (all services can communicate)
✓ Pod health (no failed pods)
✓ Resource limits (all pods have limits)
✓ Health probes (all pods have probes)
✓ Ingress (ingress resource exists)
✓ ConfigHub live state (worker sync active)
✓ Labels and annotations (proper labeling)

Validation Result: PASS (14/14 checks)
Deployment is healthy and ready for use!
```

### Step 2: Check Pod Status

```bash
# List all pods
kubectl get pods -n traderx-dev

# Expected: All pods in Running state with 1/1 ready
```

**Expected output:**
```
NAME                               READY   STATUS    RESTARTS   AGE
account-service-5f8c9d7b6c-abc12   1/1     Running   0          3m
people-service-7d6f8b9a5e-def34    1/1     Running   0          3m
position-service-6c5d7a8b4f-ghi56  1/1     Running   0          2m
reference-data-8e7f9c0d5a-jkl78    1/1     Running   0          4m
trade-feed-9f8g0d1e6b-mno90        1/1     Running   0          1m
trade-processor-0g9h1e2f7c-pqr01   1/1     Running   0          2m
trade-service-1h0i2f3g8d-stu23     1/1     Running   0          2m
web-gui-2i1j3g4h9e-vwx45           1/1     Running   0          1m
```

### Step 3: Quick Health Check

```bash
# Run health check on all services
bin/health-check dev

# Or check specific service
bin/health-check dev trade-service
```

---

## Access the Application

### Option 1: Port Forward (Easiest)

```bash
# Forward web-gui port to localhost
kubectl port-forward -n traderx-dev svc/web-gui 18080:18080

# Keep this terminal open
```

Open browser to: **http://localhost:18080**

### Option 2: Ingress (For Persistent Access)

#### Install NGINX Ingress Controller (if not already installed)

```bash
# Install NGINX ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Wait for controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

#### Configure /etc/hosts

```bash
# Add entry to /etc/hosts
echo "127.0.0.1 traderx.local" | sudo tee -a /etc/hosts
```

#### Access via Ingress

```bash
# Get ingress details
kubectl get ingress -n traderx-dev

# Open browser to:
open http://traderx.local
```

### Option 3: Individual Services

Access individual services via port-forward:

```bash
# Reference Data (master data)
kubectl port-forward -n traderx-dev svc/reference-data 18085:18085 &
curl http://localhost:18085/health

# People Service (users)
kubectl port-forward -n traderx-dev svc/people-service 18089:18089 &
curl http://localhost:18089/health

# Account Service (accounts)
kubectl port-forward -n traderx-dev svc/account-service 18091:18091 &
curl http://localhost:18091/health

# Position Service (positions)
kubectl port-forward -n traderx-dev svc/position-service 18090:18090 &
curl http://localhost:18090/health

# Trade Service (trades)
kubectl port-forward -n traderx-dev svc/trade-service 18092:18092 &
curl http://localhost:18092/health

# Trade Feed (real-time feed)
kubectl port-forward -n traderx-dev svc/trade-feed 18088:18088 &
curl http://localhost:18088/health

# Web GUI (frontend)
kubectl port-forward -n traderx-dev svc/web-gui 18080:18080 &
open http://localhost:18080
```

---

## Next Steps

### 1. Explore ConfigHub

```bash
# View all spaces
cub space list | grep mellow-muzzle-traderx

# View units in dev
cub unit list --space mellow-muzzle-traderx-dev

# View environment hierarchy
cub unit tree --node=space --filter mellow-muzzle-traderx/all --space '*'

# View unit details
cub unit get trade-service-deployment --space mellow-muzzle-traderx-dev
```

### 2. Make a Change

```bash
# Update service version
cub run set-image-reference \
  --container-name trade-service \
  --image-reference finos/traderx-trade-service:v1.1.0 \
  --space mellow-muzzle-traderx-dev

# Apply the change
cub unit apply trade-service-deployment --space mellow-muzzle-traderx-dev

# Watch the update
kubectl rollout status deployment/trade-service -n traderx-dev

# Verify new version
kubectl get deployment trade-service -n traderx-dev -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### 3. Deploy to Staging

```bash
# Promote dev to staging
bin/promote dev staging

# Deploy to staging
bin/apply-all staging

# Validate staging
bin/validate-deployment staging
```

### 4. Set Up Worker (Optional)

For automatic deployments when ConfigHub units change:

```bash
# Install worker in dev
bin/setup-worker dev

# Verify worker is running
kubectl get pods -n traderx-dev -l app=confighub-worker

# Now ConfigHub changes auto-deploy within 10 seconds!

# Test it:
cub run set-image-reference \
  --container-name web-gui \
  --image-reference finos/traderx-web-gui:v1.1.0 \
  --space mellow-muzzle-traderx-dev

# Worker applies automatically
# Watch logs:
kubectl logs -n traderx-dev -l app=confighub-worker --follow
```

### 5. Practice Rollback

```bash
# Make a change
cub run set-image-reference \
  --container-name trade-service \
  --image-reference finos/traderx-trade-service:v2.0.0 \
  --space mellow-muzzle-traderx-dev

cub unit apply trade-service-deployment --space mellow-muzzle-traderx-dev

# Simulate a problem (or wait for health check to fail)

# Rollback to previous version
bin/rollback dev trade-service

# Verify rollback
bin/health-check dev trade-service
```

### 6. Read the Documentation

- **README.md** - Project overview
- **RUNBOOK.md** - Comprehensive operational guide
- **CHANGELOG.md** - What's new in this version
- **SECURITY-REVIEW.md** - Security assessment
- **CODE-REVIEW.md** - Code quality review
- **TEST-RESULTS.md** - Test coverage report

---

## Common Pitfalls

### Issue 1: Docker Not Running

**Symptom**: `bin/install-base` or deployment scripts fail with "Cannot connect to Docker daemon"

**Solution**:
```bash
# Start Docker Desktop
open -a Docker

# Wait 30-60 seconds

# Verify Docker is running
docker info

# Retry deployment
bin/ordered-apply dev
```

---

### Issue 2: Kubernetes Cluster Not Accessible

**Symptom**: `kubectl get nodes` fails

**Solution**:
```bash
# Check current context
kubectl config current-context

# List available contexts
kubectl config get-contexts

# Switch to correct context
kubectl config use-context <context-name>

# For Kind clusters:
kubectl config use-context kind-traderx

# For Minikube:
kubectl config use-context minikube

# Verify connection
kubectl cluster-info
```

---

### Issue 3: ConfigHub Authentication Failed

**Symptom**: `cub auth status` shows "Not authenticated"

**Solution**:
```bash
# Re-authenticate
cub auth login

# Follow browser prompts

# Verify
cub auth status
```

---

### Issue 4: Pods Stuck in Pending

**Symptom**: `kubectl get pods -n traderx-dev` shows pods in "Pending" state

**Diagnosis**:
```bash
# Check pod events
kubectl describe pod <pod-name> -n traderx-dev

# Common causes:
# - Insufficient cluster resources
# - Image pull errors
# - Persistent volume issues
```

**Solution**:

**For insufficient resources:**
```bash
# Check cluster capacity
kubectl top nodes

# For Kind/Minikube, increase resources:
# Kind: Recreate cluster with more resources
kind delete cluster --name traderx
kind create cluster --name traderx --config=kind-config.yaml

# Minikube: Increase resources
minikube delete
minikube start --memory=8192 --cpus=4
```

**For image pull errors:**
```bash
# Check image exists
docker pull finos/traderx-<service>:latest

# If image doesn't exist, use different tag
# (See service README for available tags)
```

---

### Issue 5: Services Not Communicating

**Symptom**: Services can't reach each other

**Diagnosis**:
```bash
# Test service connectivity
kubectl run test-curl --rm -i --restart=Never --image=curlimages/curl -- \
  curl -f http://reference-data.traderx-dev.svc.cluster.local:18085/health

# Check endpoints
kubectl get endpoints -n traderx-dev
```

**Solution**:
```bash
# Ensure all services are deployed
bin/ordered-apply dev

# Verify services have endpoints
kubectl get svc -n traderx-dev

# Check pods are ready
kubectl get pods -n traderx-dev
```

---

### Issue 6: Port Forward Doesn't Work

**Symptom**: `kubectl port-forward` fails or browser can't connect

**Solution**:
```bash
# Check pod is running
kubectl get pods -n traderx-dev | grep web-gui

# Check pod logs for errors
kubectl logs -n traderx-dev -l app=web-gui

# Ensure correct service name
kubectl get svc -n traderx-dev

# Retry port-forward with verbose output
kubectl port-forward -n traderx-dev svc/web-gui 18080:18080 -v=6

# Try different local port if 18080 is in use
kubectl port-forward -n traderx-dev svc/web-gui 8080:18080
```

---

### Issue 7: Deployment Takes Too Long

**Symptom**: `bin/ordered-apply` takes more than 10 minutes

**Diagnosis**:
```bash
# Check which service is slow
watch -n 2 'kubectl get pods -n traderx-dev'

# Check service logs
kubectl logs -n traderx-dev -l app=<slow-service> --tail=100
```

**Solution**:
```bash
# Increase timeout
export DEPLOYMENT_TIMEOUT=600

# Retry deployment
bin/ordered-apply dev

# For specific slow service, check:
# - Image size (large images take longer to pull)
# - Startup time (Java services can be slow to start)
# - Resource limits (too low = throttled startup)
```

---

### Issue 8: "Space Already Exists" Error

**Symptom**: `bin/install-base` fails with "space already exists"

**Solution**:
```bash
# This is normal if you've run install-base before
# ConfigHub spaces are persistent

# Option 1: Continue with existing space (recommended)
# Just proceed to next step: bin/install-envs

# Option 2: Delete and recreate (CAUTION: deletes all data)
cub space delete mellow-muzzle-traderx-base --force
cub space delete mellow-muzzle-traderx-filters --force
bin/install-base
```

---

## Getting Help

### Documentation
- [README.md](README.md) - Project overview
- [RUNBOOK.md](RUNBOOK.md) - Comprehensive operational guide
- [CHANGELOG.md](CHANGELOG.md) - Version history

### Logs
```bash
# View deployment script logs
ls -lh logs/

# View recent log
tail -100 logs/ordered-apply-dev-*.log

# View pod logs
kubectl logs -n traderx-dev <pod-name>

# View worker logs
kubectl logs -n traderx-dev -l app=confighub-worker
```

### Health Checks
```bash
# Comprehensive health check
bin/health-check dev

# Full deployment validation
bin/validate-deployment dev
```

### ConfigHub Resources
- **Documentation**: https://docs.confighub.com
- **ConfigHub Hub**: https://hub.confighub.com (view your spaces and units)

### TraderX Resources
- **FINOS TraderX**: https://github.com/finos/traderX
- **DevOps as Apps**: https://github.com/monadic/devops-as-apps-project

---

## Success!

If you've made it this far, you should have:

✅ ConfigHub infrastructure created
✅ Environment hierarchy (base → dev → staging → prod)
✅ All 8 services deployed to dev
✅ Services healthy and communicating
✅ Web GUI accessible

**Congratulations!** You've successfully deployed TraderX using ConfigHub.

---

## What's Next?

### Explore More
- Deploy to staging: `bin/promote dev staging && bin/apply-all staging`
- Set up blue-green deployments: `bin/blue-green-deploy trade-service v1.1.0 dev`
- Practice rollbacks: `bin/rollback dev`
- Install worker for auto-deployment: `bin/setup-worker dev`

### Production Deployment
Before deploying to production:
1. Read [SECURITY-REVIEW.md](SECURITY-REVIEW.md)
2. Implement critical security fixes (RBAC, NetworkPolicies, TLS)
3. Run integration tests: `./test/integration/test-deployment.sh`
4. Review [RUNBOOK.md](RUNBOOK.md) for operational procedures

### Contribute
This is an example implementation of the DevOps as Apps pattern. Contributions welcome!

---

**Happy Deploying!** 🚀
