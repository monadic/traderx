# TraderX Troubleshooting Guide

Common issues and solutions for TraderX ConfigHub deployment.

## Quick Fixes

### Missing TargetID on Unit

```bash
# Run the quick fix script
bin/quick-fix
```

This sets targets on all units that need them.

### Docker Not Running

```bash
# Start Docker Desktop on macOS
open -a Docker

# Verify Docker is running
docker info
```

### Services Not Starting

```bash
# Check deployment order (reference-data must start first)
bin/ordered-apply dev

# Run health checks
bin/health-check dev

# Verify ConfigHub units
cub unit list --space $(cat .cub-project)-dev
```

### Worker Not Applying Changes

```bash
# Check worker status
kubectl get pods -n traderx-dev -l app=confighub-worker

# View worker logs
kubectl logs -n traderx-dev -l app=confighub-worker

# Reinstall worker if needed
bin/setup-worker dev
```

### Deployment Failed

```bash
# Rollback to previous version
bin/rollback dev

# Validate rollback
bin/validate-deployment dev
```

### Cost Too High

```bash
# Deploy cost-optimizer to analyze
cd ../devops-examples/cost-optimizer
./cost-optimizer

# Output: Recommendations to reduce costs
```

## People Service Issues

### No User Data in Development Mode

**Symptom**: Cannot search for users in the UI, user database appears empty.

**Root Cause**: `people-service` uses `ASPNETCORE_ENVIRONMENT: Development` which:
- Starts with empty in-memory user database
- Doesn't load seed data
- Doesn't connect to shared H2 database

**Workarounds**:
1. **Skip user assignment** - Accounts function without assigned users
2. **Use production profile** - Set `ASPNETCORE_ENVIRONMENT: Production` (requires additional configuration)
3. **Manual database insert** - Not available (H2 Shell tools not in container)

## Configuration Issues

### Ingress Not Working

```bash
# Verify ingress controller is installed
kubectl get pods -n ingress-nginx

# Check ingress resources
kubectl get ingress -n traderx-dev

# View ingress logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Database Connection Issues

```bash
# Check database pod
kubectl get pods -n traderx-dev -l app=database

# View database logs
kubectl logs -n traderx-dev -l app=database

# Verify database initialization
kubectl exec -n traderx-dev -it deployment/database -- ls -la /app/_data/
```

### Service Can't Connect to Database

```bash
# Check service logs for connection errors
kubectl logs -n traderx-dev -l app=account-service

# Verify database service is running
kubectl get svc -n traderx-dev database

# Test connectivity from pod
kubectl exec -n traderx-dev -it deployment/account-service -- curl http://database:18082
```

## Resource Issues

### Pods Failing with OOMKilled

```bash
# Check memory limits
kubectl describe pod -n traderx-dev <pod-name>

# Increase memory limits for service
cub unit update <service>-deployment \
  --space $(cat .cub-project)-dev \
  --patch '{"spec":{"template":{"spec":{"containers":[{"name":"<service>","resources":{"limits":{"memory":"1Gi"}}}]}}}}'

cub unit apply <service>-deployment --space $(cat .cub-project)-dev
```

### Insufficient Cluster Resources

```bash
# Check cluster resources
kubectl top nodes
kubectl top pods -n traderx-dev

# Scale down replicas if needed
bin/bulk-update replicas backend 1 dev
```

## ConfigHub Issues

### Unit Not Applying

```bash
# Check unit status
cub unit get <unit-name> --space $(cat .cub-project)-dev

# Check live state
cub unit get <unit-name> --space $(cat .cub-project)-dev --show-live

# Force reapply
cub unit apply <unit-name> --space $(cat .cub-project)-dev --force
```

### Push-Upgrade Not Working

```bash
# Verify upstream relationships
cub unit get <unit-name> --space $(cat .cub-project)-dev

# Check for UpstreamUnitID
# If missing, recreate with --upstream-unit

# Force upgrade
cub unit update <unit-name> \
  --space $(cat .cub-project)-staging \
  --upgrade
```

### Links Not Resolving

```bash
# List all links
cub link list --space $(cat .cub-project)-dev

# Check specific link
cub link get <link-id>

# Verify needs/provides match
# - Provider must have matching provides
# - Consumer must have matching needs
```

## Health Check Failures

### Liveness Probe Failing

```bash
# Check pod events
kubectl describe pod -n traderx-dev <pod-name>

# View service logs around failure time
kubectl logs -n traderx-dev <pod-name> --previous

# Test health endpoint manually
kubectl exec -n traderx-dev -it <pod-name> -- curl http://localhost:<port>/health
```

### Readiness Probe Failing

```bash
# Service may still be starting
# Check logs for initialization messages
kubectl logs -n traderx-dev -l app=<service>

# Increase initialDelaySeconds if needed
# Edit deployment and increase from 30s to 60s
```

## Getting Help

If you're still stuck:

1. **Check logs**: `kubectl logs -n traderx-dev -l app=<service>`
2. **Run health check**: `bin/health-check dev`
3. **Validate deployment**: `bin/validate-deployment dev`
4. **Review migration notes**: See `migration-notes/` for implementation history
5. **Check ConfigHub patterns**: See `docs/ADVANCED-CONFIGHUB-PATTERNS.md`

## Diagnostic Commands

```bash
# Full system status
kubectl get all -n traderx-dev

# Check all service endpoints
kubectl get svc -n traderx-dev

# View all ConfigHub units
cub unit list --space $(cat .cub-project)-dev

# Check worker status
kubectl logs -n traderx-dev -l app=confighub-worker --tail=100

# Export all pod logs
for pod in $(kubectl get pods -n traderx-dev -o name); do
  echo "=== $pod ===" >> /tmp/traderx-logs.txt
  kubectl logs -n traderx-dev $pod >> /tmp/traderx-logs.txt 2>&1
done
```
