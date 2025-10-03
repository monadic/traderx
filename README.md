# TraderX - ConfigHub Deployment

A ConfigHub-native deployment of FINOS TraderX sample trading application, demonstrating the [DevOps as Apps](https://github.com/monadic/devops-as-apps-project) pattern.

## 🎯 Overview

This repository shows how to deploy the [FINOS TraderX](https://github.com/finos/traderX) sample trading application using ConfigHub instead of traditional kubectl/Tilt approaches. TraderX consists of 8 microservices that simulate a trading platform.

**Key Benefits:**
- ✅ **ConfigHub-native deployment** - No kubectl, pure `cub unit apply`
- ✅ **Environment hierarchy** - Dev → Staging → Prod with push-upgrade
- ✅ **ConfigHub workers** - Replace Tilt for auto-deployment
- ✅ **DevOps as Apps ready** - Integrates with drift-detector, cost-optimizer
- ✅ **Full audit trail** - Every config change tracked in ConfigHub

## 📦 Services

TraderX includes 8 microservices:

| Service | Language | Port | Purpose |
|---------|----------|------|---------|
| reference-data | Java/Spring | 18085 | Master data (securities, accounts) |
| people-service | Java/Spring | 18089 | User/trader management |
| account-service | Node.js/NestJS | 18091 | Account operations |
| position-service | Java/Spring | 18090 | Position tracking |
| trade-service | .NET/C# | 18092 | Trade execution |
| trade-processor | Python | N/A | Trade settlement (async) |
| trade-feed | Java/Spring | 18088 | Real-time trade feed |
| web-gui | Angular/React | 18080 | User interface |

## 🚀 Quick Start

### Prerequisites
- ConfigHub account ([sign up](https://confighub.com))
- ConfigHub CLI: `brew install confighubai/tap/cub`
- Kubernetes cluster (Kind, Minikube, or cloud)
- `cub auth login` completed

### Deploy to Development

```bash
# 1. Create ConfigHub structure
bin/install-base      # Creates spaces, units, filters
bin/install-envs      # Creates dev/staging/prod hierarchy

# 2. Deploy to Kubernetes
bin/apply-all dev     # Deploy all 8 services to dev

# 3. Access the application
kubectl port-forward -n traderx-dev svc/web-gui 18080:18080
open http://localhost:18080

# 4. View in ConfigHub
cub unit tree --node=space --filter traderx --space '*'
```

### Promote to Staging

```bash
# After testing in dev, promote to staging
bin/promote dev staging
bin/apply-all staging
```

## 📁 Repository Structure

```
traderx/
├── bin/
│   ├── install-base        # Create ConfigHub base structure
│   ├── install-envs        # Set up environment hierarchy
│   ├── apply-all           # Deploy all services to environment
│   ├── promote             # Push-upgrade between environments
│   ├── setup-worker        # Install ConfigHub worker
│   ├── ordered-apply       # Apply services in dependency order
│   └── proj                # Get project name
│
├── confighub/
│   └── base/               # ConfigHub unit definitions
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
└── docs/
    └── DEPLOYMENT-PATTERNS.md  # Detailed ConfigHub patterns
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

This deployment integrates with the [DevOps as Apps](https://github.com/monadic/devops-examples) platform:

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

This deployment demonstrates all 12 canonical ConfigHub patterns:

1. **Unique Project Naming** - `cub space new-prefix` generates unique names
2. **Space Hierarchy** - base → dev → staging → prod
3. **Filter Creation** - Backend vs frontend service filters
4. **Environment Cloning** - `--upstream-unit` relationships
5. **Version Promotion** - `cub run set-image-reference`
6. **Sets for Grouping** - Core services, trading services, UI
7. **Event-Driven** - Workers respond to ConfigHub changes
8. **ConfigHub Functions** - `cub run` commands for operations
9. **Changesets** - Atomic multi-service updates
10. **Lateral Promotion** - Region-by-region rollout
11. **Revision Management** - Full history and rollback
12. **Link Management** - Connect services to infrastructure

See [docs/DEPLOYMENT-PATTERNS.md](docs/DEPLOYMENT-PATTERNS.md) for details.

## 🧪 Testing

### Unit Tests
```bash
# Test deployment scripts
./test/test-deployment.sh
```

### Integration Tests
```bash
# Deploy to Kind cluster and verify
kind create cluster --name traderx-test
bin/install-base
bin/apply-all dev
./test/verify-deployment.sh
```

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

### Services not starting
```bash
# Check deployment order (reference-data must start first)
bin/ordered-apply dev

# Verify ConfigHub units
cub unit list --space traderx-dev
```

### Worker not applying changes
```bash
# Check worker status
kubectl get pods -n traderx-dev -l app=confighub-worker

# View worker logs
kubectl logs -n traderx-dev -l app=confighub-worker
```

### Cost too high
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

**Built with ConfigHub** • **Part of DevOps as Apps Platform** • **Better than kubectl/Tilt**