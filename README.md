# TraderX - ConfigHub Deployment

A ConfigHub-native deployment of FINOS TraderX sample trading application, using the patterns tested in [DevOps as Apps](https://github.com/monadic/devops-as-apps-project).

## 🎯 Overview

This repository shows how to deploy the [FINOS TraderX](https://github.com/finos/traderX) sample trading application using **advanced ConfigHub patterns**. TraderX consists of 9 microservices that simulate a trading platform.

### Two Versions:

**🏢 traderx (This Repo)** - Production-Grade Deployment
- Full 9-service FINOS TraderX application
- Advanced ConfigHub patterns: filters, bulk operations, layer-based deployment
- Complex dependency management
- Production-ready scripts and automation
- **Use this to learn advanced ConfigHub features**

**📚 microtraderx** - Tutorial Version
- Simplified progressive tutorial (7 stages)
- Basic ConfigHub operations: create, update, apply
- Clear separation: `./setup-structure` vs `./deploy`
- Educational focus on ConfigHub fundamentals
- **Use this to learn ConfigHub basics**

---

## Advanced ConfigHub Patterns Used in TraderX

This deployment demonstrates production-grade ConfigHub capabilities:

- ✅ **Filter-based deployment** - Deploy by layer: `--where "Labels.layer = 'backend'"`
- ✅ **Bulk operations** - Update multiple units simultaneously
- ✅ **Label-based organization** - Layer (data/backend/frontend) + order (0-8)
- ✅ **Environment hierarchy** - Dev → Staging → Prod with push-upgrade
- ✅ **ConfigHub workers** - Kubernetes integration with auto-deployment
- ✅ **Two-state management** - Explicit update + apply workflow
- ✅ **Full audit trail** - Every config change tracked in ConfigHub

## 📦 Services

TraderX includes 9 microservices:

| Service | Language | Port | Purpose |
|---------|----------|------|---------|
| database | Java/H2 | 18082 | In-memory database |
| reference-data | Java/Spring | 18085 | Master data (securities, accounts) |
| trade-feed | Java/Spring | 18086 | Real-time trade feed |
| account-service | Java/Spring | 18088 | Account operations |
| people-service | Java/Spring | 18089 | User/trader management |
| position-service | Java/Spring | 18090 | Position tracking |
| trade-service | .NET/C# | 18092 | Trade execution |
| trade-processor | Python | N/A | Trade settlement (async) |
| web-gui | Angular | 18093 | User interface |

## 📊 Current Status

**✅ 9/9 Services Running (100%)** - Full TraderX deployment with all ConfigHub patterns

**Project Name**: `sweet-growl-traderx`
**ConfigHub Spaces**: 5 (base, dev, staging, prod, filters)
**Units Deployed**: 68 across all environments
**Worker Status**: ✅ Running and connected
**Dashboard**: ✅ Accessible and functional

### ✅ All Services Running (9/9)

| Service | Status | Purpose |
|---------|--------|---------|
| database | ✅ Running | H2 in-memory database |
| reference-data | ✅ Running | Master data service |
| people-service | ✅ Running | User management |
| account-service | ✅ Running | Account operations |
| position-service | ✅ Running | Position tracking |
| trade-feed | ✅ Running | Real-time trade feed |
| trade-service | ✅ Running | Trade execution |
| trade-processor | ✅ Running | Settlement processing |
| web-gui | ✅ Running | Dashboard interface |

**Note**: All services fully operational after fixes based on [chanwit/traderx](https://github.com/chanwit/traderx) working reference. See **[TRADERX-FIX-SUMMARY.md](TRADERX-FIX-SUMMARY.md)** for details.

## 🚀 Quick Start

### Prerequisites
- ConfigHub account ([sign up](https://confighub.com))
- ConfigHub CLI: `brew install confighubai/tap/cub`
- Kubernetes cluster (Kind, Minikube, or cloud) **running**
- Docker daemon **running**
- `cub auth login` completed

### Pre-Flight Check

Before deploying, verify your ConfigHub + Kubernetes environment:

```bash
curl -fsSL https://raw.githubusercontent.com/monadic/devops-sdk/main/test-confighub-k8s | bash
```

This runs the [ConfigHub + Kubernetes Mini TCK](https://github.com/monadic/devops-sdk/blob/main/TCK.md) to verify your setup is working correctly. Expected output: `🎉 SUCCESS! ConfigHub + Kubernetes integration verified`

### Option 1: Simple Sequential Deployment

```bash
# 1. Create ConfigHub structure
bin/install-base      # Creates spaces, units, filters
bin/install-envs      # Creates dev/staging/prod hierarchy

# 2. Install ConfigHub Worker
bin/setup-worker dev  # Installs worker and creates target

# 3. Deploy to Kubernetes (basic pattern)
bin/ordered-apply dev # Deploy all 9 services in dependency order

# 4. Check deployment status
kubectl get pods -n traderx-dev
```

### Option 2: Links + Multi-Environment (Hybrid Pattern) ⭐ RECOMMENDED

```bash
# Prerequisites: Same as above (install-base, install-envs, setup-worker)

# Deploy using ConfigHub Links (automatic dependency management)
bin/apply-with-links dev

# This demonstrates the HYBRID ConfigHub pattern:
# - 20 dependency links per environment (based on chanwit/traderx)
# - Multi-environment hierarchy (base → dev → staging → prod)
# - ConfigHub auto-orders deployment based on links
# - Push-upgrade for environment promotion
# - Automatic dependency ordering (no manual sleeps!)
# - Validation before apply (catches missing dependencies)

# View dependency graph (20 links)
cub link list --space $(cat .cub-project)-dev
```

**Why This Hybrid Approach is Best:**
- ✅ Links: ConfigHub handles dependency ordering automatically
- ✅ Links: Self-documenting dependency graph
- ✅ Links: Placeholders auto-filled from providers
- ✅ Hierarchy: Full dev → staging → prod promotion
- ✅ Hierarchy: Environment-specific customization
- ✅ Hierarchy: Production-ready workflow

**Pattern Source:** Based on [chanwit/traderx canonical pattern](https://github.com/chanwit/traderx/blob/main/k8s-manifests/deploy-via-confighub.sh)

See [docs/LINKS-AND-HIERARCHY.md](docs/LINKS-AND-HIERARCHY.md) for full explanation.

### Option 3: Advanced Layer-Based Deployment

```bash
# Prerequisites: Same as above (install-base, install-envs, setup-worker)

# Deploy by layer using ConfigHub filters
bin/deploy-by-layer dev

# This demonstrates:
# - Layer-based deployment (infra → data → backend → frontend)
# - Filter-based targeting with WHERE clauses
# - Bulk apply operations
# - Dependency-aware deployment order

# View services by layer
kubectl get pods -n traderx-dev -l layer=backend
kubectl get pods -n traderx-dev -l layer=data
```

### Option 4: Bulk Configuration Management

```bash
# Scale all backend services to 3 replicas
bin/bulk-update replicas backend 3 dev

# Restart all backend services
bin/bulk-update restart backend dev

# Check status of data layer
bin/bulk-update status data dev

# This demonstrates ConfigHub bulk operations
```

### Promote to Staging

```bash
# After testing in dev, promote to staging
bin/promote dev staging
bin/apply-all staging
bin/validate-deployment staging  # Validate staging
```

## 🌐 Accessing the TraderX Dashboard

Once deployed, access the TraderX web interface:

```bash
# Port-forward the web-gui service
kubectl port-forward -n traderx-dev deployment/web-gui 8080:18093

# Open in browser
open http://localhost:8080
```

The dashboard should now be accessible at **http://localhost:8080**

### Making a Trade

1. **View the dashboard** - You should see the TraderX trading interface
2. **Navigate to trades section** - Look for trade creation/execution options
3. **Create a trade** - Enter trade details (security, quantity, price, etc.)
4. **Submit** - Execute the trade

## 📝 Deployment Status

### ✅ All Services Operational (9/9)

All TraderX services are running with ConfigHub-managed deployment:
- ✅ Account management working (create/view accounts, H2 database persistence)
- ✅ API routing via Ingress (backend + frontend paths)
- ✅ Health probes configured (liveness + readiness)
- ✅ Resource limits optimized for local clusters

### ⚠️ Known Limitation

**People Service**: Uses development profile with in-memory storage. User search in UI is unavailable. Accounts work without user assignment.

**For full deployment details and workarounds**, see [TRADERX-FIX-SUMMARY.md](TRADERX-FIX-SUMMARY.md).

```bash
# Check all services
kubectl get pods -n traderx-dev
bin/health-check dev
```

## 📁 Repository Structure

```
traderx/
├── bin/                         # Deployment scripts
├── confighub/base/              # ConfigHub unit definitions (17 units)
├── test/                        # Test suites (unit, integration, e2e)
├── docs/                        # Documentation
└── migration-notes/             # Implementation history
```

## 🔄 ConfigHub Workers (Replace Tilt)

Instead of using Tilt for development, ConfigHub workers provide automatic deployment:

```bash
# Install worker in dev environment
bin/setup-worker dev

# Now any ConfigHub unit change auto-deploys
cub run set-image-reference \
  --container-name web-gui \
  --image-reference :v1.2.3 \
  --space traderx-dev

# Worker applies changes in ~10 seconds
```

## 🤖 DevOps as Apps Integration

Integrates with [DevOps as Apps](https://github.com/monadic/devops-examples) tools:
- **drift-detector**: Watches TraderX spaces for configuration drift
- **cost-optimizer**: Analyzes costs for all services with AI recommendations

## 📚 ConfigHub Patterns

This deployment demonstrates 9 of 12 canonical ConfigHub patterns:
- ✅ Unique naming, space hierarchy, filters, bulk operations
- ✅ Label-based organization, event-driven workers
- ✅ Two-state management (update + apply)
- ✅ Link management for dependencies

See [docs/ADVANCED-CONFIGHUB-PATTERNS.md](docs/ADVANCED-CONFIGHUB-PATTERNS.md) for details.

## 🧪 Testing

```bash
# Quick validation (no infrastructure)
./test/run-all-tests.sh --quick

# Full test suite (requires ConfigHub + K8s)
./test/run-all-tests.sh
```

**Test Coverage**: Unit tests (70/70), integration tests, end-to-end workflows. See [test/README.md](test/README.md) for details.

## 📈 Monitoring

- **ConfigHub Dashboard**: https://hub.confighub.com (view units, live state, history)
- **Service Logs**: `kubectl logs -n traderx-dev -l app=<service> --follow`
- **Worker Logs**: `kubectl logs -n traderx-dev -l app=confighub-worker --follow`

## 🔧 Troubleshooting

For detailed troubleshooting, see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

**Quick Fixes:**
- Missing TargetID: `bin/quick-fix`
- Docker not running: `open -a Docker`
- Services not starting: `bin/ordered-apply dev` then `bin/health-check dev`
- Worker issues: Check logs with `kubectl logs -n traderx-dev -l app=confighub-worker`
- Deployment failed: `bin/rollback dev`

## 🤝 Contributing

This is a demonstration of ConfigHub patterns applied to FINOS TraderX. Contributions welcome!

1. Fork the repository
2. Create a feature branch
3. Test with `bin/test-deployment.sh`
4. Submit a PR

## 📄 License

Apache 2.0 - See [LICENSE](LICENSE)

## 📚 Documentation

- [QUICKSTART.md](QUICKSTART.md) - 15-minute deployment guide
- [RUNBOOK.md](RUNBOOK.md) - Operational procedures
- [docs/ADVANCED-CONFIGHUB-PATTERNS.md](docs/ADVANCED-CONFIGHUB-PATTERNS.md) - Production patterns
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues and fixes
- [migration-notes/](migration-notes/) - Implementation history and multi-agent development
- [test/README.md](test/README.md) - Testing documentation

## 🔗 Related Projects

- [FINOS TraderX](https://github.com/finos/traderX) - Original application
- [DevOps as Apps](https://github.com/monadic/devops-as-apps-project) - Platform architecture
- [ConfigHub SDK](https://github.com/monadic/devops-sdk) - Go SDK for ConfigHub
- [DevOps Examples](https://github.com/monadic/devops-examples) - Drift detector, cost optimizer

---

**Built with ConfigHub** • **Part of DevOps as Apps Platform**
