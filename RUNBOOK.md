# TraderX ConfigHub Deployment - Operations Runbook

**Version**: 1.0.0-alpha
**Project**: mellow-muzzle-traderx
**Last Updated**: 2025-10-03

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Prerequisites](#prerequisites)
3. [Deployment Procedures](#deployment-procedures)
4. [Health Check Procedures](#health-check-procedures)
5. [Troubleshooting Guide](#troubleshooting-guide)
6. [Rollback Procedures](#rollback-procedures)
7. [Worker Management](#worker-management)
8. [Common Error Resolutions](#common-error-resolutions)
9. [Monitoring and Alerts](#monitoring-and-alerts)
10. [Incident Response](#incident-response)

---

## System Overview

### Architecture
TraderX is deployed using ConfigHub with a base → dev → staging → prod environment hierarchy. All 8 microservices are deployed through ConfigHub units, not direct kubectl commands.

### Key Components
- **ConfigHub Spaces**: 5 (base, dev, staging, prod, filters)
- **Kubernetes Namespaces**: 3 (traderx-dev, traderx-staging, traderx-prod)
- **Services**: 8 microservices
- **Deployment Method**: ConfigHub-driven with optional worker automation

### Project Identifiers
- **Project Name**: `mellow-muzzle-traderx`
- **Base Space**: `mellow-muzzle-traderx-base`
- **Dev Space**: `mellow-muzzle-traderx-dev`
- **Staging Space**: `mellow-muzzle-traderx-staging`
- **Prod Space**: `mellow-muzzle-traderx-prod`

---

## Prerequisites

### Required Tools
```bash
# ConfigHub CLI
brew install confighubai/tap/cub
cub version  # Should be v1.0+

# Kubernetes CLI
kubectl version --client

# Docker (must be running)
docker info

# jq for JSON processing
brew install jq
```

### Authentication
```bash
# ConfigHub authentication
cub auth login

# Verify authentication
cub auth status

# Kubernetes context
kubectl config current-context
kubectl cluster-info
```

### Environment Variables
```bash
# Optional: Set project explicitly
export TRADERX_PROJECT="mellow-muzzle-traderx"

# Optional: Set deployment timeout
export DEPLOYMENT_TIMEOUT=300  # seconds
```

---

## Deployment Procedures

### Initial Deployment (First Time)

#### Step 1: Create ConfigHub Infrastructure
```bash
cd /Users/alexis/traderx

# Create base structure (spaces, filters, sets, units)
bin/install-base

# Expected output:
# - Created space: mellow-muzzle-traderx-base
# - Created 7 filters
# - Created 2 sets
# - Created 17 units

# Verify creation
cub space list | grep mellow-muzzle-traderx
cub unit list --space mellow-muzzle-traderx-base | wc -l  # Should be 17
```

#### Step 2: Create Environment Hierarchy
```bash
# Create dev, staging, prod environments
bin/install-envs

# Expected output:
# - Created space: mellow-muzzle-traderx-dev
# - Created space: mellow-muzzle-traderx-staging
# - Created space: mellow-muzzle-traderx-prod
# - Cloned units with upstream relationships

# Verify hierarchy
cub unit tree --node=space --filter mellow-muzzle-traderx/all --space '*'
```

#### Step 3: Deploy to Development
```bash
# Ensure Docker is running
docker info

# Ensure Kubernetes cluster is accessible
kubectl cluster-info

# Deploy all services in dependency order
bin/ordered-apply dev

# Expected duration: 3-5 minutes
# Expected output: All 8 services deployed and healthy

# Validate deployment
bin/validate-deployment dev

# Expected: All checks pass
```

#### Step 4: Optional - Install Worker
```bash
# Install ConfigHub worker for auto-deployment
bin/setup-worker dev

# Verify worker is running
kubectl get pods -n traderx-dev -l app=confighub-worker
kubectl logs -n traderx-dev -l app=confighub-worker --tail=50
```

### Subsequent Deployments

#### Update Single Service
```bash
# Update service version in ConfigHub
cub run set-image-reference \
  --container-name trade-service \
  --image-reference finos/traderx-trade-service:v1.2.3 \
  --space mellow-muzzle-traderx-dev

# Apply the change
cub unit apply trade-service-deployment --space mellow-muzzle-traderx-dev

# If worker is installed, it will auto-apply within 10 seconds
# Otherwise, manually apply as shown above

# Verify deployment
bin/health-check dev trade-service
```

#### Full Environment Redeploy
```bash
# Redeploy all services
bin/apply-all dev

# Validate
bin/validate-deployment dev
```

#### Blue-Green Deployment (Zero Downtime)
```bash
# Deploy new version with zero downtime
bin/blue-green-deploy trade-service v1.2.3 dev

# Expected process:
# 1. Deploy green version alongside blue
# 2. Health check green version
# 3. Switch traffic to green
# 4. Cleanup blue version

# Duration: 2-4 minutes
```

### Promotion Between Environments

#### Dev → Staging
```bash
# Test in dev first
bin/validate-deployment dev

# Promote to staging
bin/promote dev staging

# Apply to staging
bin/apply-all staging

# Validate staging
bin/validate-deployment staging
```

#### Staging → Production
```bash
# IMPORTANT: Production deployments require extra validation

# 1. Validate staging is stable
bin/health-check staging
bin/validate-deployment staging

# 2. Review changes
cub unit diff \
  --space mellow-muzzle-traderx-staging \
  --space mellow-muzzle-traderx-prod \
  --filter mellow-muzzle-traderx/all

# 3. Create backup
cub unit list --space mellow-muzzle-traderx-prod --format json > prod-backup-$(date +%Y%m%d-%H%M%S).json

# 4. Promote with confirmation
bin/promote staging prod  # Will prompt for confirmation

# 5. Apply to production (use ordered-apply for safer deployment)
bin/ordered-apply prod

# 6. Monitor closely
watch -n 5 'kubectl get pods -n traderx-prod'

# 7. Validate production
bin/validate-deployment prod

# 8. Run soak test (monitor for 15 minutes)
for i in {1..15}; do
  echo "Soak test minute $i/15"
  bin/health-check prod
  sleep 60
done
```

---

## Health Check Procedures

### Comprehensive Health Check
```bash
# Check all services in an environment
bin/health-check dev

# Check specific service
bin/health-check dev trade-service

# Expected output:
# ✓ Namespace exists: traderx-dev
# ✓ Deployment exists: trade-service
# ✓ Desired replicas: 2
# ✓ Available replicas: 2
# ✓ Ready replicas: 2
# ✓ Health probe: Passing
# ✓ Service endpoint: Responding
```

### Manual Health Checks

#### Pod Status
```bash
# List all pods
kubectl get pods -n traderx-dev

# Check for failed pods
kubectl get pods -n traderx-dev --field-selector=status.phase!=Running

# Describe failed pod
kubectl describe pod <pod-name> -n traderx-dev

# View pod logs
kubectl logs <pod-name> -n traderx-dev --tail=100 --follow
```

#### Service Endpoints
```bash
# Check service endpoints
kubectl get endpoints -n traderx-dev

# Test service connectivity (from within cluster)
kubectl run test-curl --rm -i --restart=Never --image=curlimages/curl -- \
  curl -f http://trade-service.traderx-dev.svc.cluster.local:18092/health

# Port-forward for local testing
kubectl port-forward -n traderx-dev svc/trade-service 18092:18092 &
curl http://localhost:18092/health
```

#### ConfigHub Live State
```bash
# Check ConfigHub sync status
cub unit get trade-service-deployment --space mellow-muzzle-traderx-dev --show-live-state

# Expected: live_state should match desired state
```

### Health Check Schedule
- **Development**: Every 5 minutes (automated via monitoring)
- **Staging**: Every 2 minutes
- **Production**: Every 1 minute + alerts

---

## Troubleshooting Guide

### Problem: Docker not running

**Symptoms**:
- `bin/install-base` or other scripts fail
- Error: "Cannot connect to Docker daemon"

**Resolution**:
```bash
# macOS: Start Docker Desktop
open -a Docker

# Verify Docker is running
docker info

# Wait for Docker to fully start (30-60 seconds)

# Retry deployment
bin/install-base
```

---

### Problem: Services not starting

**Symptoms**:
- Pods stuck in "Pending" or "CrashLoopBackOff"
- `kubectl get pods` shows errors

**Diagnosis**:
```bash
# Check pod status
kubectl get pods -n traderx-dev

# Describe problematic pod
kubectl describe pod <pod-name> -n traderx-dev

# Check logs
kubectl logs <pod-name> -n traderx-dev --tail=100
```

**Common Causes & Resolutions**:

#### Cause 1: Dependency not ready
```bash
# Example: trade-service requires reference-data

# Solution: Use ordered deployment
bin/ordered-apply dev

# This deploys in correct dependency order
```

#### Cause 2: Resource limits too low
```bash
# Check resource usage
kubectl top pods -n traderx-dev

# Increase limits in ConfigHub
cub unit update trade-service-deployment \
  --patch \
  --space mellow-muzzle-traderx-dev \
  --data '{"spec":{"template":{"spec":{"containers":[{"name":"trade-service","resources":{"limits":{"memory":"1Gi"}}}]}}}}'

# Apply the change
cub unit apply trade-service-deployment --space mellow-muzzle-traderx-dev
```

#### Cause 3: Image pull failure
```bash
# Check image pull status
kubectl describe pod <pod-name> -n traderx-dev | grep -A5 "Events"

# Verify image exists
docker pull finos/traderx-trade-service:latest

# Update image reference if incorrect
cub run set-image-reference \
  --container-name trade-service \
  --image-reference finos/traderx-trade-service:v1.0.0 \
  --space mellow-muzzle-traderx-dev
```

---

### Problem: ConfigHub units not applying

**Symptoms**:
- `cub unit apply` succeeds but pods don't update
- Live state doesn't match desired state

**Diagnosis**:
```bash
# Check if worker is installed
kubectl get pods -n traderx-dev -l app=confighub-worker

# Check worker logs
kubectl logs -n traderx-dev -l app=confighub-worker --tail=100
```

**Resolution**:

#### Option 1: Fix worker
```bash
# Restart worker
kubectl delete pod -n traderx-dev -l app=confighub-worker

# Worker will automatically restart and sync
```

#### Option 2: Manual apply
```bash
# Bypass worker and apply directly
kubectl apply -f <(cub unit get trade-service-deployment \
  --space mellow-muzzle-traderx-dev \
  --format yaml)
```

---

### Problem: Promotion failed

**Symptoms**:
- `bin/promote` fails with error
- Changes not propagating to target environment

**Diagnosis**:
```bash
# Check upstream/downstream relationships
cub unit tree --node=space --filter mellow-muzzle-traderx/all --space '*'

# Verify unit exists in source environment
cub unit list --space mellow-muzzle-traderx-dev | grep trade-service
```

**Resolution**:
```bash
# Manual promotion using push-upgrade
cub unit update trade-service-deployment \
  --patch \
  --upgrade \
  --space mellow-muzzle-traderx-staging

# Verify propagation
cub unit diff \
  --space mellow-muzzle-traderx-dev \
  --space mellow-muzzle-traderx-staging \
  trade-service-deployment
```

---

### Problem: Ingress not working

**Symptoms**:
- Cannot access web-gui from browser
- 404 or connection refused errors

**Diagnosis**:
```bash
# Check ingress resource
kubectl get ingress -n traderx-dev

# Describe ingress
kubectl describe ingress traderx-ingress -n traderx-dev

# Check ingress controller
kubectl get pods -n ingress-nginx
```

**Resolution**:

#### Cause 1: Ingress controller not installed
```bash
# Install NGINX ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Wait for controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

#### Cause 2: Incorrect host configuration
```bash
# Check ingress host
kubectl get ingress traderx-ingress -n traderx-dev -o yaml | grep host

# Update /etc/hosts if using traderx.local
echo "127.0.0.1 traderx.local" | sudo tee -a /etc/hosts

# Or use port-forward instead
kubectl port-forward -n traderx-dev svc/web-gui 18080:18080
open http://localhost:18080
```

---

## Rollback Procedures

### Automatic Rollback (Recommended)

#### Full Environment Rollback
```bash
# Rollback entire environment to previous revision
bin/rollback dev

# Expected process:
# 1. Query ConfigHub revision history
# 2. Identify previous stable revision
# 3. Apply rollback
# 4. Validate deployment
# 5. Run health checks

# Duration: 15-30 seconds
```

#### Service-Specific Rollback
```bash
# Rollback single service
bin/rollback dev trade-service

# Verify rollback
bin/health-check dev trade-service
```

### Manual Rollback

#### Step 1: Identify previous revision
```bash
# List revision history
cub unit history trade-service-deployment --space mellow-muzzle-traderx-dev

# Output example:
# Revision 5: 2025-10-03 14:30:00 - Updated image to v1.2.3
# Revision 4: 2025-10-03 12:00:00 - Updated image to v1.2.2  <-- Target
# Revision 3: 2025-10-02 16:00:00 - Initial deployment
```

#### Step 2: Apply previous revision
```bash
# Rollback to specific revision
cub unit rollback trade-service-deployment \
  --space mellow-muzzle-traderx-dev \
  --revision 4

# Apply the rollback
cub unit apply trade-service-deployment --space mellow-muzzle-traderx-dev
```

#### Step 3: Validate rollback
```bash
# Check deployment
kubectl rollout status deployment/trade-service -n traderx-dev

# Run health check
bin/health-check dev trade-service

# Verify version
kubectl get deployment trade-service -n traderx-dev -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### Emergency Rollback (Production)

```bash
# CRITICAL: Production rollback procedure

# 1. Alert team
echo "ALERT: Initiating production rollback for trade-service" | # notify team

# 2. Execute rollback
bin/rollback prod trade-service

# 3. Monitor closely
watch -n 2 'kubectl get pods -n traderx-prod -l app=trade-service'

# 4. Validate immediately
bin/validate-deployment prod

# 5. Check user impact
# - Monitor application metrics
# - Check error rates
# - Verify user transactions

# 6. Document incident
cat > incident-report-$(date +%Y%m%d-%H%M%S).md <<EOF
# Production Rollback Report
Date: $(date)
Service: trade-service
Reason: [FILL IN]
Previous Version: [FILL IN]
Rolled Back To: [FILL IN]
Impact: [FILL IN]
Root Cause: [FILL IN]
EOF
```

---

## Worker Management

### Install Worker
```bash
# Install worker in environment
bin/setup-worker dev

# Verify installation
kubectl get deployment confighub-worker -n traderx-dev
kubectl get pods -n traderx-dev -l app=confighub-worker
```

### Monitor Worker
```bash
# Check worker status
kubectl get pods -n traderx-dev -l app=confighub-worker

# View worker logs (real-time)
kubectl logs -n traderx-dev -l app=confighub-worker --follow

# View recent worker activity
kubectl logs -n traderx-dev -l app=confighub-worker --tail=100
```

### Restart Worker
```bash
# Delete worker pod (will automatically restart)
kubectl delete pod -n traderx-dev -l app=confighub-worker

# Wait for restart
kubectl wait --for=condition=ready pod \
  -l app=confighub-worker \
  -n traderx-dev \
  --timeout=60s

# Verify it's working
kubectl logs -n traderx-dev -l app=confighub-worker --tail=20
```

### Disable Worker
```bash
# Scale worker to 0 replicas
kubectl scale deployment confighub-worker -n traderx-dev --replicas=0

# Now deployments will require manual `cub unit apply`
```

### Re-enable Worker
```bash
# Scale worker back to 1 replica
kubectl scale deployment confighub-worker -n traderx-dev --replicas=1

# Verify it's running
kubectl get pods -n traderx-dev -l app=confighub-worker
```

---

## Common Error Resolutions

### Error: "space already exists"

**When**: Running `bin/install-base` multiple times

**Resolution**:
```bash
# This is expected behavior. ConfigHub spaces are persistent.
# Either:

# Option 1: Use existing space
cub space list | grep mellow-muzzle-traderx

# Option 2: Delete and recreate (CAUTION: Deletes all data)
cub space delete mellow-muzzle-traderx-base --force
bin/install-base
```

---

### Error: "unit not found"

**When**: Trying to apply non-existent unit

**Resolution**:
```bash
# List all units in space
cub unit list --space mellow-muzzle-traderx-dev

# Check if unit exists in base
cub unit list --space mellow-muzzle-traderx-base | grep trade-service

# Re-run install-base if units are missing
bin/install-base

# Re-run install-envs to recreate environment units
bin/install-envs
```

---

### Error: "context deadline exceeded"

**When**: Long-running operations timeout

**Resolution**:
```bash
# Increase timeout
export DEPLOYMENT_TIMEOUT=600  # 10 minutes

# Retry operation
bin/ordered-apply dev

# Or increase timeout in script directly
# Edit bin/ordered-apply and change timeout value
```

---

### Error: "ImagePullBackOff"

**When**: Kubernetes cannot pull container image

**Resolution**:
```bash
# Check image exists
docker pull finos/traderx-trade-service:latest

# If image doesn't exist, use different version
cub run set-image-reference \
  --container-name trade-service \
  --image-reference finos/traderx-trade-service:v1.0.0 \
  --space mellow-muzzle-traderx-dev

# Apply change
cub unit apply trade-service-deployment --space mellow-muzzle-traderx-dev
```

---

## Monitoring and Alerts

### Key Metrics to Monitor

#### Service Health
```bash
# Check all services are healthy
watch -n 5 'kubectl get pods -n traderx-dev'

# Expected: All pods in "Running" state with "1/1" ready
```

#### Resource Usage
```bash
# Check resource consumption
kubectl top pods -n traderx-dev
kubectl top nodes

# Alert if:
# - CPU usage > 80%
# - Memory usage > 80%
# - Disk usage > 80%
```

#### ConfigHub Sync Status
```bash
# Verify ConfigHub is in sync with Kubernetes
for service in reference-data people-service account-service position-service trade-service trade-processor trade-feed web-gui; do
  echo "Checking $service..."
  cub unit get ${service}-deployment \
    --space mellow-muzzle-traderx-dev \
    --show-live-state | jq -r '.live_state.status'
done

# Expected: All show "Applied" or "Healthy"
```

### Log Locations

```bash
# Script execution logs
ls -lh logs/

# Example logs:
# - logs/install-base-20251003-143000.log
# - logs/ordered-apply-dev-20251003-143500.log
# - logs/health-check-dev-20251003-144000.log
# - logs/rollback-dev-20251003-144500.log
```

### Recommended Alerts

#### Critical Alerts
1. Any pod in CrashLoopBackOff for > 5 minutes
2. Service unavailable for > 1 minute (production)
3. Rollback executed
4. Deployment failure

#### Warning Alerts
1. Resource usage > 80%
2. ConfigHub sync delay > 30 seconds
3. Health check failure (single occurrence)
4. Slow startup time (> 2 minutes)

---

## Incident Response

### Severity Levels

**SEV-1 (Critical)**: Production down, user-facing impact
- Response time: Immediate
- Escalation: All hands on deck
- Action: Immediate rollback if safe

**SEV-2 (High)**: Partial outage, degraded service
- Response time: < 15 minutes
- Escalation: On-call engineer
- Action: Investigate and fix or rollback

**SEV-3 (Medium)**: Non-critical issue, no user impact
- Response time: < 4 hours
- Escalation: Team lead
- Action: Fix in next deployment window

**SEV-4 (Low)**: Minor issue, informational
- Response time: Next business day
- Escalation: None
- Action: Create ticket for backlog

### Incident Response Procedure

#### Step 1: Assess and Triage (2 minutes)
```bash
# Quick health check
bin/health-check prod

# Check all pods
kubectl get pods -n traderx-prod

# Determine severity
# - All services down = SEV-1
# - One service down = SEV-2
# - Degraded performance = SEV-3
```

#### Step 2: Immediate Mitigation (5 minutes)
```bash
# For SEV-1/SEV-2: Rollback immediately
bin/rollback prod

# Verify rollback successful
bin/validate-deployment prod

# Monitor recovery
watch -n 2 'kubectl get pods -n traderx-prod'
```

#### Step 3: Root Cause Analysis (30-60 minutes)
```bash
# Collect logs
kubectl logs -n traderx-prod --all-containers --previous > incident-logs-$(date +%Y%m%d-%H%M%S).log

# Check ConfigHub history
cub unit history --space mellow-muzzle-traderx-prod --all > configub-history-$(date +%Y%m%d-%H%M%S).log

# Check Kubernetes events
kubectl get events -n traderx-prod --sort-by='.lastTimestamp' > k8s-events-$(date +%Y%m%d-%H%M%S).log

# Analyze and document root cause
```

#### Step 4: Create Post-Incident Report
```bash
cat > post-incident-$(date +%Y%m%d-%H%M%S).md <<EOF
# Post-Incident Report

**Date**: $(date)
**Severity**: [SEV-X]
**Duration**: [XX minutes]
**Services Affected**: [List services]

## Timeline
- HH:MM - Incident detected
- HH:MM - Rollback initiated
- HH:MM - Service restored
- HH:MM - Root cause identified

## Root Cause
[Description]

## Impact
[User impact, revenue impact, etc.]

## Resolution
[What fixed it]

## Action Items
- [ ] Fix underlying issue
- [ ] Add monitoring/alerts to prevent recurrence
- [ ] Update runbook
- [ ] Team review

EOF
```

---

## Appendix

### Useful Commands Quick Reference

```bash
# View project name
bin/proj

# List all spaces
cub space list | grep $(bin/proj)

# List all units in environment
cub unit list --space $(bin/proj)-dev

# View environment hierarchy
cub unit tree --node=space --filter $(bin/proj)/all --space '*'

# Check pod status
kubectl get pods -n traderx-dev

# View service logs
kubectl logs -n traderx-dev -l app=trade-service --tail=100

# Port-forward to service
kubectl port-forward -n traderx-dev svc/web-gui 18080:18080

# Execute command in pod
kubectl exec -it <pod-name> -n traderx-dev -- /bin/sh

# Get pod YAML
kubectl get pod <pod-name> -n traderx-dev -o yaml

# Describe resource
kubectl describe deployment trade-service -n traderx-dev
```

### Contact Information

**On-Call Engineer**: [Your contact]
**Team Slack**: #traderx-ops
**Escalation Path**: Engineer → Team Lead → Manager → VP Engineering

### Related Documentation

- [README.md](README.md) - Project overview
- [QUICKSTART.md](QUICKSTART.md) - Quick start guide
- [CHANGELOG.md](CHANGELOG.md) - Version history
- [SECURITY-REVIEW.md](SECURITY-REVIEW.md) - Security assessment
- [CODE-REVIEW.md](CODE-REVIEW.md) - Code quality review
- [TEST-RESULTS.md](TEST-RESULTS.md) - Test coverage

---

**End of Runbook**

For questions or improvements to this runbook, please submit a PR or contact the TraderX operations team.
