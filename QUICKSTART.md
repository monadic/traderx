# TraderX Quick Start Guide

Deploy TraderX with ConfigHub in under 10 minutes.

## Prerequisites

| Requirement | Check Command |
|-------------|---------------|
| Docker running | `docker info` |
| Kind cluster | `kubectl cluster-info` |
| ConfigHub CLI | `cub version` |
| ConfigHub login | `cub auth status` |
| nginx-ingress | `kubectl get svc -n ingress-nginx` |

**If missing prerequisites**, see [README.md prerequisites section](README.md#prerequisites).

### Pre-Flight Check

Before deploying, verify your ConfigHub + Kubernetes environment:

```bash
curl -fsSL https://raw.githubusercontent.com/monadic/devops-sdk/main/test-confighub-k8s | bash
```

Expected output: `🎉 SUCCESS! ConfigHub + Kubernetes integration verified`

## One-Time Setup: /etc/hosts

Add `traderx.local` to your hosts file (required for ingress routing):

```bash
# Check if already configured
grep traderx.local /etc/hosts

# If not present, add it:
sudo sh -c 'echo "127.0.0.1 traderx.local" >> /etc/hosts'
```

## Deploy TraderX

```bash
# 1. Create ConfigHub structure
bin/install-base      # Creates project prefix, spaces, filters, base units
bin/install-envs      # Creates dev/staging/prod hierarchy

# 2. Install worker (connects ConfigHub to Kubernetes)
bin/setup-worker dev

# 3. Deploy all services
bin/ordered-apply dev

# 4. Verify deployment
kubectl get pods -n traderx-dev
# Should show 9 pods running
```

## Access TraderX

```bash
# Automated setup (recommended)
bin/local-access

# Or manual steps:
kubectl port-forward svc/ingress-nginx-controller -n ingress-nginx 8080:80 &
open http://traderx.local:8080
```

The `bin/local-access` script:
- Verifies /etc/hosts is configured
- Checks ingress-nginx is installed
- Starts port-forward to ingress
- Opens browser to TraderX

## Verify Everything Works

```bash
# Check status
bin/local-access --status

# Test APIs through ingress
curl -s http://traderx.local:8080/account-service/account/ | head -c 200
```

## Important: Port-Forward Timeout

The port-forward to ingress-nginx **times out after a few minutes of inactivity**. This is normal Kubernetes behavior.

**Symptoms:** Browser shows "connection refused" or APIs stop responding.

**Fix:** Just run `bin/local-access` again to restart it.

## Troubleshooting

### "Connection refused" on port 8080
```bash
# Restart port-forward (most common fix)
bin/local-access
```

### APIs return 404
```bash
# Check ingress is deployed
kubectl get ingress -n traderx-dev

# If missing, apply it
cub unit apply ingress --space $(cat .cub-project)-dev
```

### Services not starting
```bash
# Check pod status
kubectl get pods -n traderx-dev

# View logs
kubectl logs -n traderx-dev deployment/database

# Re-apply all units
bin/ordered-apply dev
```

### nginx-ingress not installed
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s
```

## Clean Up

```bash
# Stop port-forward
bin/local-access --stop

# Delete from Kubernetes (keeps ConfigHub units)
kubectl delete namespace traderx-dev

# Or full cleanup including ConfigHub
cub space delete $(cat .cub-project)-dev
```

## Next Steps

- [README.md](README.md) - Full documentation
- [docs/ADVANCED-CONFIGHUB-PATTERNS.md](docs/ADVANCED-CONFIGHUB-PATTERNS.md) - Production patterns
- [RUNBOOK.md](RUNBOOK.md) - Operations procedures
