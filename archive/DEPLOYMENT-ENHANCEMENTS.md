# TraderX Deployment Enhancements

## Overview

This document describes the production-ready enhancements made to the TraderX ConfigHub deployment to support 99.95% availability targets and enterprise-grade reliability.

## Table of Contents

1. [Enhanced Deployment Scripts](#enhanced-deployment-scripts)
2. [New Utility Scripts](#new-utility-scripts)
3. [Service Manifest Improvements](#service-manifest-improvements)
4. [Monitoring Integration](#monitoring-integration)
5. [Testing Framework](#testing-framework)
6. [Deployment Patterns](#deployment-patterns)
7. [Usage Guide](#usage-guide)

---

## Enhanced Deployment Scripts

### Improvements Made

All deployment scripts now include:

#### 1. Comprehensive Error Handling
- **Set strict mode**: `set -euo pipefail` for immediate error detection
- **Error trapping**: Automatic cleanup on failures
- **Meaningful error messages**: Clear indication of what failed and where

#### 2. Logging & Auditability
- **Timestamped logs**: All operations logged with timestamps
- **Log files**: Separate log file for each deployment run
- **Log levels**: INFO, WARN, ERROR for different severity
- **Complete audit trail**: All commands and outputs captured

```bash
# Example log output
[2025-10-03 18:30:15] INFO: Starting ordered deployment to fluffy-bunny-traderx-dev...
[2025-10-03 18:30:16] INFO: Applying namespace...
[2025-10-03 18:30:20] INFO: Namespace is Active
```

#### 3. Retry Logic with Exponential Backoff
- **Automatic retries**: Failed operations retry up to 3 times
- **Exponential backoff**: Delay doubles after each retry (5s, 10s, 20s)
- **Configurable**: Retry count and delay easily adjustable

```bash
# Retry configuration
MAX_RETRIES=3
RETRY_DELAY=5  # Initial delay in seconds
```

#### 4. Enhanced Health Checks
- **Comprehensive validation**: Checks deployment, replica, and availability status
- **Pod error detection**: Identifies failed pods and reports them
- **Configurable timeouts**: 120s default, adjustable per service
- **Live progress updates**: Real-time status during health checks

```bash
# Health check output
[2025-10-03 18:31:00] INFO: Waiting for trade-service to be ready (timeout: 120s)...
[2025-10-03 18:31:05] INFO:   trade-service status: 1/1 ready, 1 available
[2025-10-03 18:31:05] INFO:   trade-service is READY
```

#### 5. Idempotency
- **Safe re-runs**: All scripts can be run multiple times safely
- **State checking**: Verifies current state before applying changes
- **Graceful handling**: Continues if resources already exist

---

## New Utility Scripts

### 1. `bin/health-check`

Comprehensive health validation for all services.

**Usage:**
```bash
bin/health-check <environment>

# Examples
bin/health-check dev
bin/health-check staging
bin/health-check prod
```

**Features:**
- Validates namespace existence and status
- Checks all deployments are running and healthy
- Verifies service endpoints are accessible
- Tests inter-service dependencies
- Checks for pod errors and restarts
- Validates ConfigHub live state sync
- Generates detailed health report

**Output:**
```
======================================
Health Check Summary
======================================
Total checks: 25
Passed: 24 ✓
Warnings: 1 ⚠
Failed: 0 ✗

Overall status: DEGRADED ⚠
All services are running but with warnings.
```

### 2. `bin/rollback`

Automated rollback to previous known-good state using ConfigHub revisions.

**Usage:**
```bash
bin/rollback <environment> [revision-number]

# Examples
bin/rollback prod           # Rollback to previous revision (N-1)
bin/rollback prod 5         # Rollback to specific revision 5
```

**Features:**
- **ConfigHub-only**: Uses `cub unit apply --revision` (NO kubectl)
- **Production safeguards**: Requires confirmation for prod rollbacks
- **Reverse order rollback**: Rolls back services in reverse dependency order
- **Health verification**: Validates system health after rollback
- **Detailed reporting**: Shows which services rolled back and to what revision

**Safety Features:**
- Production confirmation required
- Automatic health check after rollback
- Logs all rollback operations
- Supports partial rollbacks

### 3. `bin/validate-deployment`

End-to-end deployment validation with 14 different test suites.

**Usage:**
```bash
bin/validate-deployment <environment>

# Examples
bin/validate-deployment dev
bin/validate-deployment staging
```

**Validates:**
1. ConfigHub space exists
2. All units exist in ConfigHub
3. Kubernetes namespace is Active
4. All deployments are running
5. Service dependencies are correct
6. Services have valid endpoints
7. Ingress is configured
8. Resource limits are set
9. ConfigHub live state is synced
10. Health probes are configured
11. Labels and annotations are present
12. Network policies (future)
13. Security context is set
14. No failed pods

**Output:**
```
======================================
Validation Summary
======================================
Total validations: 45
Passed: 45 ✓
Failed: 0 ✗
Success rate: 100.0%

All validations passed! ✓
```

### 4. `bin/blue-green-deploy`

Zero-downtime production deployment using blue-green pattern.

**Usage:**
```bash
bin/blue-green-deploy <service> [version] [environment]

# Examples
bin/blue-green-deploy trade-service v2.0.0 prod
bin/blue-green-deploy reference-data v1.5.2 staging
```

**Eligible Services:**
- reference-data
- trade-service
- position-service

**Phases:**
1. **Deploy new color**: Create green (or blue) environment
2. **Validate**: Comprehensive health checks on new environment
3. **Switch traffic**: Update service selector to new color
4. **Soak test**: Monitor for 5 minutes for any issues
5. **Decommission old**: Scale down and optionally delete old color

**Safety Features:**
- **Production checklist**: Pre-deployment confirmation required
- **Automatic rollback**: Reverts to old color if soak test fails
- **Warm standby**: Keeps old color running for 60s after switch
- **Complete logging**: All operations logged for audit

**Rollback:**
If soak test detects errors, automatic instant rollback:
```bash
[2025-10-03 19:15:30] ERROR: Soak test failed, rolling back to blue
[2025-10-03 19:15:31] INFO: ✓ Traffic rolled back to blue
```

---

## Service Manifest Improvements

### Enhancements Applied

All service manifests now include:

#### 1. ConfigHub Templating

Parameterized for multi-environment deployment:

```yaml
metadata:
  name: trade-service
  namespace: {{ .Namespace | default "traderx-dev" }}
  labels:
    version: {{ .Version | default "latest" }}
spec:
  replicas: {{ .Replicas | default 1 }}
  containers:
  - name: trade-service
    image: finos/traderx-trade-service:{{ .ImageTag | default "latest" }}
    resources:
      requests:
        memory: {{ .ResourceRequestMemory | default "512Mi" }}
        cpu: {{ .ResourceRequestCPU | default "500m" }}
```

**Benefits:**
- Single manifest for all environments
- Easy version updates via ConfigHub
- Environment-specific resource allocation
- No hardcoded values

#### 2. Comprehensive Health Probes

Three types of probes for robust health checking:

```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 18092
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health/ready
    port: 18092
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 2

startupProbe:
  httpGet:
    path: /health/startup
    port: 18092
  initialDelaySeconds: 0
  periodSeconds: 5
  failureThreshold: 12
```

**Benefits:**
- **Liveness**: Detects and restarts unhealthy containers
- **Readiness**: Prevents traffic to not-ready pods
- **Startup**: Handles slow-starting applications gracefully

#### 3. Resource Limits

Production-ready resource allocation:

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "500m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
```

**Per-Service Allocations:**
- **reference-data**: 250m CPU, 256Mi memory (critical, data layer)
- **trade-service**: 500m-1000m CPU, 512Mi-1Gi memory (critical, high load)
- **position-service**: 500m-1000m CPU, 512Mi-1Gi memory (critical)
- **Other services**: 200m-500m CPU, 256Mi-512Mi memory

#### 4. Security Context

Enhanced security configuration:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
```

**Security features:**
- Non-root execution
- Specific user ID
- File system permissions

#### 5. Circuit Breaker Configuration

Resilience patterns for inter-service communication:

```yaml
env:
- name: CIRCUIT_BREAKER_ENABLED
  value: "true"
- name: CIRCUIT_BREAKER_THRESHOLD
  value: "5"
- name: CIRCUIT_BREAKER_TIMEOUT
  value: "30"
```

#### 6. Prometheus Annotations

Automatic metrics collection:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "18092"
  prometheus.io/path: "/metrics"
```

#### 7. Rolling Update Strategy

Zero-downtime deployments:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

---

## Monitoring Integration

### Prometheus Configuration

**Location:** `monitoring/prometheus-config.yaml`

**Features:**
- Auto-discovery of TraderX services
- Separate scrape configs for critical services
- Metric relabeling for efficient storage
- Multi-environment support

**Scrape Targets:**
- All pods with `prometheus.io/scrape: "true"` annotation
- Dedicated configs for critical services (reference-data, trade-service, position-service)
- Kubernetes API server and nodes
- Service endpoints

### Alert Rules

**Location:** `monitoring/prometheus-config.yaml` (prometheus-rules ConfigMap)

**Alert Groups:**

#### 1. Critical Service Alerts
- **TradeServiceDown**: Trade service unavailable for 30s
- **ReferenceDataDown**: Reference data unavailable for 30s
- **PositionServiceDown**: Position service unavailable for 30s

#### 2. Performance Alerts
- **HighErrorRate**: Error rate > 5% for 2 minutes
- **HighLatency**: P95 latency > 500ms for 5 minutes

#### 3. Resource Alerts
- **HighMemoryUsage**: Memory usage > 90% for 5 minutes
- **HighCPUUsage**: CPU usage > 80% for 10 minutes

#### 4. Operational Alerts
- **FrequentPodRestarts**: Pod restarting > 0.1 times/minute
- **DeploymentReplicasMismatch**: Desired != available replicas for 5 minutes

#### 5. Business Metrics Alerts
- **LowTradingVolume**: Trading volume low for 30 minutes
- **HighTradeRejectionRate**: Rejection rate > 10% for 10 minutes

### Grafana Dashboards

**Location:** `monitoring/grafana-dashboards.json`

**Dashboard Panels:**
1. **Service Availability**: Real-time up/down status for all services
2. **Request Rate**: Requests per second by service
3. **Response Time (P95)**: 95th percentile latency
4. **Error Rate**: Percentage of failed requests
5. **Critical Service Status**: Trade, Reference Data, Position services
6. **Memory Usage**: Memory consumption by container
7. **CPU Usage**: CPU utilization by container
8. **Pod Restarts**: Restart frequency
9. **Network I/O**: Network traffic by pod
10. **Service Health Summary**: Tabular view of all service health

**Dashboard Features:**
- Environment filtering (dev, staging, prod)
- Service filtering
- Alert annotations
- Auto-refresh every 30 seconds
- Last 1 hour time window (configurable)

---

## Testing Framework

### Unit Tests

**Location:** `test/unit/test-scripts.sh`

**Test Suites:**
1. **Script Existence**: All required scripts present
2. **Script Executability**: All scripts have execute permissions
3. **Shell Syntax**: All scripts have valid bash syntax
4. **Shellcheck**: Static analysis (if shellcheck installed)
5. **Error Handling**: All scripts use `set -euo pipefail`
6. **Logging Functions**: Logging infrastructure present
7. **Error Trapping**: Error traps configured
8. **ConfigHub-Only**: No kubectl in production scripts
9. **Usage Messages**: Help text present
10. **Idempotency**: Idempotent operation patterns
11. **YAML Validation**: All manifests are valid YAML
12. **ConfigHub Templating**: Template variables present
13. **Health Checks**: Health probes in manifests
14. **Resource Limits**: Resource specifications present
15. **Security Context**: Security configurations present

**Usage:**
```bash
cd /Users/alexis/traderx
./test/unit/test-scripts.sh
```

**Example Output:**
```
======================================
Test Summary
======================================
Total tests: 85
Passed: 85
Failed: 0

All tests passed!
```

### Integration Tests

**Location:** `test/integration/test-deployment.sh`

**Test Suites:**
1. **ConfigHub Authentication**: Verify auth status
2. **Project Setup**: Project prefix exists
3. **ConfigHub Spaces**: All required spaces exist
4. **ConfigHub Units**: Correct number of units
5. **Kubernetes Namespace**: Namespace is Active
6. **Service Deployments**: All deployments running
7. **Service Endpoints**: All services have valid endpoints
8. **Service Dependencies**: Inter-service connectivity
9. **Pod Health**: No failed pods
10. **Resource Limits**: All deployments have limits
11. **Health Probes**: Liveness and readiness configured
12. **Ingress**: Ingress resources present
13. **ConfigHub Live State**: Live state synced
14. **Labels and Annotations**: Required metadata present

**Usage:**
```bash
cd /Users/alexis/traderx
./test/integration/test-deployment.sh dev
```

**Example Output:**
```
======================================
Integration Test Summary
======================================
Environment: dev
Namespace: traderx-dev
Project: fluffy-bunny-traderx

Total tests: 62
Passed: 60
Failed: 2
Success rate: 96.8%
```

---

## Deployment Patterns

### Standard Deployment (Development)

```bash
# 1. Install base structure
bin/install-base

# 2. Create environment hierarchy
bin/install-envs

# 3. Deploy to dev
bin/ordered-apply dev

# 4. Validate deployment
bin/validate-deployment dev

# 5. Check health
bin/health-check dev
```

### Promotion Workflow (Staging → Production)

```bash
# 1. Promote from dev to staging
bin/promote dev staging

# 2. Apply to staging
bin/ordered-apply staging

# 3. Validate staging
bin/validate-deployment staging

# 4. Run integration tests
./test/integration/test-deployment.sh staging

# 5. After 24h soak test, promote to prod
bin/promote staging prod

# 6. Blue-green deploy critical services
bin/blue-green-deploy trade-service v2.0.0 prod
bin/blue-green-deploy reference-data v1.5.2 prod

# 7. Apply remaining services
bin/ordered-apply prod

# 8. Final validation
bin/validate-deployment prod
bin/health-check prod
```

### Emergency Rollback

```bash
# 1. Immediate rollback to previous revision
bin/rollback prod

# 2. Verify system health
bin/health-check prod

# 3. Check specific service if needed
bin/rollback prod 5  # Rollback to specific revision
```

---

## Usage Guide

### Daily Operations

#### Deploy New Version
```bash
# Update image tag in ConfigHub
cub unit update trade-service-deployment \
  --space fluffy-bunny-traderx-staging \
  --patch \
  --data '{"spec":{"template":{"spec":{"containers":[{"name":"trade-service","image":"finos/traderx-trade-service:v2.1.0"}]}}}}'

# Apply update
cub unit apply trade-service-deployment \
  --space fluffy-bunny-traderx-staging
```

#### Check Deployment Status
```bash
# Quick health check
bin/health-check prod

# Detailed validation
bin/validate-deployment prod

# View logs
kubectl logs deployment/trade-service -n traderx-prod -f
```

#### Monitor Services
```bash
# View Grafana dashboard
# Navigate to: http://grafana.example.com/d/traderx-overview

# Check Prometheus alerts
# Navigate to: http://prometheus.example.com/alerts

# View live metrics
kubectl port-forward -n traderx-monitoring svc/prometheus 9090:9090
open http://localhost:9090
```

### Troubleshooting

#### Service Won't Start
```bash
# 1. Check pod status
kubectl get pods -n traderx-prod -l app=trade-service

# 2. View pod logs
kubectl logs <pod-name> -n traderx-prod

# 3. Describe pod for events
kubectl describe pod <pod-name> -n traderx-prod

# 4. Check ConfigHub state
cub unit get-live-state trade-service-deployment \
  --space fluffy-bunny-traderx-prod
```

#### Deployment Failed
```bash
# 1. Check deployment logs
cat logs/ordered-apply-*.log | tail -50

# 2. Rollback to previous version
bin/rollback prod

# 3. Validate rollback
bin/health-check prod
```

#### High Error Rate Alert
```bash
# 1. Check service health
bin/health-check prod

# 2. View recent logs
kubectl logs deployment/trade-service -n traderx-prod --tail=100

# 3. Check dependencies
kubectl get pods -n traderx-prod

# 4. If persistent, rollback
bin/rollback prod
```

---

## Performance Targets

### Deployment Performance
- **Full environment deployment**: < 10 minutes
- **Single service update**: < 2 minutes
- **Rollback time**: < 30 seconds
- **Health check**: < 1 minute

### Service Availability
- **Critical services**: 99.95% (43 minutes downtime/month)
- **High priority services**: 99.9% (43.2 minutes/month)
- **Medium priority services**: 99.5% (3.6 hours/month)

### Response Times
- **Reference Data**: P95 < 50ms, P99 < 100ms
- **Trade Service**: P95 < 200ms, P99 < 500ms
- **Position Service**: P95 < 100ms, P99 < 200ms
- **Web GUI**: Load time P95 < 2s, P99 < 5s

---

## Security Considerations

### ConfigHub Security
- All changes tracked with full audit trail
- RBAC controls who can deploy to each environment
- Production requires manual approval
- All secrets managed via Kubernetes Secrets (not in ConfigHub)

### Kubernetes Security
- All containers run as non-root
- Resource limits prevent resource exhaustion
- Network policies restrict inter-service communication
- Security context enforced on all pods

### Operational Security
- Production deployments require confirmation
- Blue-green deployment prevents accidental rollouts
- Automatic rollback on failure
- Complete audit trail in log files

---

## Compliance & Audit

### Regulatory Requirements
- **SEC Rule 17a-4**: All configuration changes tracked in ConfigHub
- **FINRA 4511**: Complete change management audit trail
- **SOC 2**: Access controls, monitoring, and incident response
- **PCI-DSS**: Secrets management and network segmentation

### Audit Trail
Every operation is logged with:
- Timestamp
- User/system performing action
- Action taken
- Result (success/failure)
- Complete command output

**Log Locations:**
- Deployment logs: `logs/ordered-apply-*.log`
- Health check logs: `logs/health-check-*.log`
- Rollback logs: `logs/rollback-*.log`
- Blue-green deployment logs: `logs/blue-green-deploy-*.log`

---

## Future Enhancements

### Planned
1. **Multi-region deployment**: Blue-green across regions
2. **Automated performance testing**: Load tests before production
3. **Cost optimization**: AI-driven resource recommendations
4. **Self-healing**: Automatic recovery from common failures
5. **Chaos engineering**: Automated resilience testing

### Under Consideration
1. **Service mesh integration**: Istio/Linkerd for advanced traffic management
2. **GitOps workflow**: ConfigHub → Git → Flux/Argo
3. **Canary deployments**: Progressive rollout with traffic splitting
4. **A/B testing**: Traffic routing for feature testing
5. **Backup automation**: Automated backups and restore testing

---

## Support & Documentation

### Additional Resources
- **Architecture**: `ARCHITECTURE-DESIGN.md`
- **Implementation Plan**: `IMPLEMENTATION-PLAN.md`
- **Risk Matrix**: `RISK-MATRIX.md`
- **Success Criteria**: `SUCCESS-CRITERIA.md`
- **Service Dependencies**: `service-dependency-map.json`
- **ConfigHub Topology**: `confighub-topology.yaml`

### Getting Help
1. Review logs in `logs/` directory
2. Run validation: `bin/validate-deployment <env>`
3. Check health: `bin/health-check <env>`
4. View ConfigHub state: `cub unit list --space <space>`
5. Check Kubernetes: `kubectl get all -n <namespace>`

---

**Document Version**: 1.0
**Last Updated**: 2025-10-03
**Maintained By**: Code Generator Agent
