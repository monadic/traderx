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
./test-confighub-k8s
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

### Connected Services

All 9 services are running and connected:

| Service | Status | Function |
|---------|--------|----------|
| database | ✅ Running | H2 database storing trade data |
| account-service | ✅ Running | Managing accounts |
| people-service | ✅ Running | Managing users |
| position-service | ✅ Running | Tracking positions |
| reference-data | ✅ Running | Security reference data |
| trade-service | ✅ Running | Processing trades |
| trade-feed | ✅ Running | Real-time trade feed |
| trade-processor | ✅ Running | Background processing |
| web-gui | ✅ Running | Dashboard interface |

### Checking Service Health

```bash
# View all pods
kubectl get pods -n traderx-dev

# View all services
kubectl get svc -n traderx-dev

# Check specific service logs
kubectl logs -n traderx-dev deployment/trade-service --tail=50

# Run health check script
bin/health-check dev
```

## 📁 Repository Structure

```
traderx/
├── bin/                         # Deployment scripts
│   ├── install-base            # Create ConfigHub base structure
│   ├── install-envs            # Set up environment hierarchy
│   ├── apply-all               # Deploy all services to environment
│   ├── promote                 # Push-upgrade between environments
│   ├── setup-worker            # Install ConfigHub worker
│   ├── ordered-apply           # Apply services in dependency order
│   ├── health-check            # Comprehensive health validation (NEW)
│   ├── rollback                # Rollback to previous revision (NEW)
│   ├── validate-deployment     # Full deployment validation (NEW)
│   ├── blue-green-deploy       # Zero-downtime deployments (NEW)
│   └── proj                    # Get project name
│
├── confighub/
│   └── base/                   # ConfigHub unit definitions (17 units)
│       ├── namespace.yaml
│       ├── reference-data-deployment.yaml
│       ├── reference-data-service.yaml
│       ├── people-service-deployment.yaml
│       ├── people-service-service.yaml
│       ├── account-service-deployment.yaml
│       ├── account-service-service.yaml
│       ├── position-service-deployment.yaml
│       ├── position-service-service.yaml
│       ├── trade-service-deployment.yaml
│       ├── trade-service-service.yaml
│       ├── trade-processor-deployment.yaml
│       ├── trade-feed-deployment.yaml
│       ├── trade-feed-service.yaml
│       ├── web-gui-deployment.yaml
│       ├── web-gui-service.yaml
│       └── ingress.yaml
│
├── test/                        # Test suites
│   ├── unit/test-scripts.sh   # Unit tests (88.6% coverage)
│   └── integration/test-deployment.sh  # Integration tests
│
├── docs/                        # Documentation
│   ├── ADVANCED-CONFIGHUB-PATTERNS.md  # Production patterns
│   └── AUTOUPDATES-AND-GITOPS.md       # Two-state model
│
├── WORKING-STATUS.md            # Current deployment status (6/9)
├── PROJECT-SUMMARY.md           # Comprehensive project summary
└── archive/                     # Historical documentation
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

This deployment integrates with these [DevOps as Apps](https://github.com/monadic/devops-examples) tools:

### Drift Detection
```bash
# Deploy drift-detector to watch TraderX
cd ../devops-examples/drift-detector
bin/install-base
# Configure to watch traderx-* spaces
```

### Cost Optimization
```bash
# Deploy cost-optimizer to analyze TraderX costs
cd ../devops-examples/cost-optimizer
bin/install-base
# Shows cost breakdown for all 8 services
```

### Combined View
```bash
# See drift + cost for any service
bin/combined-view trade-service

# Output:
# 📊 Drift: replicas drifted (3 → 5)
# 💰 Cost: +$50/month
# 🔧 Fix: cub unit update trade-service --patch...
```

## 📚 ConfigHub Patterns Used

This deployment demonstrates core ConfigHub patterns:

### Actively Used ✅

1. **Unique Project Naming** - `cub space new-prefix` generates unique names
2. **Space Hierarchy** - base → dev → staging → prod
3. **Filter Creation** - Layer-based filters (backend, frontend, data)
4. **Filter-Based Deployment** - Deploy by layer using `--where` clauses
5. **Bulk Operations** - Update multiple units via filters
6. **Label-Based Organization** - Layer, order, tech, service labels
7. **Event-Driven** - Workers respond to ConfigHub changes
8. **Two-State Management** - Explicit update + apply workflow
9. **Link Management** ⭐ NEW - Dependency tracking via links + needs/provides

### Available But Not Demonstrated

10. **Sets for Grouping** - Not used (cub set command not available in current CLI)
11. **Version Promotion** - `cub run set-image-reference` (pattern exists, not used)
12. **Changesets** - Atomic multi-service updates (pattern exists, not used)
13. **Lateral Promotion** - Region-by-region rollout (pattern exists, not used)
14. **Revision Management** - Full history and rollback (available via ConfigHub)

See [docs/ADVANCED-CONFIGHUB-PATTERNS.md](docs/ADVANCED-CONFIGHUB-PATTERNS.md) for implementation details.

## 🧪 Testing

TraderX includes comprehensive test coverage with different infrastructure requirements.

### Test Types

**Unit Tests** (No infrastructure required - < 30 seconds):
- Script syntax validation
- YAML manifest validation
- Code quality checks
- ConfigHub-only command enforcement

**Integration Tests** (Infrastructure required - 2-5 minutes):
- ConfigHub API operations
- Worker apply operations
- Service connectivity
- Full deployment validation

**End-to-End Tests** (Full deployment required - 5-10 minutes):
- Complete user workflows
- Multi-environment promotion
- Rollback scenarios

### Option 1: Quick Validation (No Infrastructure)

Run unit tests only - validates code quality without requiring ConfigHub or Kubernetes:

```bash
# Quick unit tests
./test/run-all-tests.sh --quick

# Result: 70/70 tests in < 30 seconds
# - All scripts syntactically valid
# - YAML manifests valid
# - Best practices enforced
# - ConfigHub-only commands verified
```

### Option 2: Full Testing (Infrastructure Required)

Set up infrastructure first, then run complete test suite:

```bash
# 1. Authenticate with ConfigHub
cub auth login

# 2. Create ConfigHub structure
bin/install-base      # Creates spaces, units, filters
bin/install-envs      # Creates dev/staging/prod hierarchy

# 3. Set up Kubernetes (if not already available)
kind create cluster --name traderx-test
kubectl cluster-info

# 4. Install ConfigHub worker
bin/setup-worker dev

# 5. Deploy application
bin/ordered-apply dev

# 6. Run full test suite
./test/run-all-tests.sh

# Result: All tests including integration and E2E
# - Unit tests: 70/70
# - Integration tests: Full deployment validation
# - E2E tests: Complete workflows
```

### Test Suites

```bash
# Unit tests only
./test/unit/test-scripts.sh

# ConfigHub API tests
./test/unit/confighub-api/test-api.sh

# Integration tests (requires infrastructure)
./test/integration/test-deployment.sh dev

# End-to-end workflow tests
./test/e2e/test-full-workflow.sh

# All tests
./test/run-all-tests.sh
```

### CI/CD Testing

```bash
# CI mode (non-interactive)
./test/run-all-tests.sh --ci

# With coverage report
./test/run-all-tests.sh --coverage
```

For detailed testing documentation, see [test/README.md](test/README.md).

## 📈 Monitoring

### ConfigHub Dashboard
- Visit https://hub.confighub.com
- Navigate to your TraderX spaces
- View units, live state, and history

### Kubernetes Dashboard
```bash
# Port-forward to see all services
kubectl port-forward -n traderx-dev svc/web-gui 18080:18080
kubectl port-forward -n traderx-dev svc/trade-service 18092:18092
```

### Logs
```bash
# View logs for any service
kubectl logs -n traderx-dev -l app=trade-service --follow

# View worker logs
kubectl logs -n traderx-dev -l app=confighub-worker --follow
```

## 🔧 Troubleshooting

### Quick Fixes

**If you see "missing TargetID on Unit" error**
```bash
# Run the quick fix script
bin/quick-fix
```

**Docker not running**
```bash
# Start Docker Desktop on macOS
open -a Docker

# Verify Docker is running
docker info
```

**Services not starting**
```bash
# Check deployment order (reference-data must start first)
bin/ordered-apply dev

# Run health checks
bin/health-check dev

# Verify ConfigHub units
cub unit list --space mellow-muzzle-traderx-dev
```

**Worker not applying changes**
```bash
# Check worker status
kubectl get pods -n traderx-dev -l app=confighub-worker

# View worker logs
kubectl logs -n traderx-dev -l app=confighub-worker
```

**Deployment failed**
```bash
# Rollback to previous version
bin/rollback dev

# Validate rollback
bin/validate-deployment dev
```

**Cost too high**
```bash
# Deploy cost-optimizer to analyze
cd ../devops-examples/cost-optimizer
./cost-optimizer

# Output: Recommendations to reduce costs
```

## 🤝 Contributing

This is a demonstration of ConfigHub patterns applied to FINOS TraderX. Contributions welcome!

1. Fork the repository
2. Create a feature branch
3. Test with `bin/test-deployment.sh`
4. Submit a PR

## 📄 License

Apache 2.0 - See [LICENSE](LICENSE)

## 🔗 Related Projects

- [FINOS TraderX](https://github.com/finos/traderX) - Original application
- [DevOps as Apps](https://github.com/monadic/devops-as-apps-project) - Platform architecture
- [ConfigHub SDK](https://github.com/monadic/devops-sdk) - Go SDK for ConfigHub
- [DevOps Examples](https://github.com/monadic/devops-examples) - Drift detector, cost optimizer

---

**Built with ConfigHub** • **Part of DevOps as Apps Platform**
