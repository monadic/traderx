# Advanced ConfigHub Patterns in TraderX

This document explains the production-grade ConfigHub patterns used in TraderX. These patterns go beyond basic ConfigHub usage and demonstrate enterprise-scale deployment capabilities.

**Note**: These are ADVANCED patterns. For learning ConfigHub basics, see [microtraderx](https://github.com/monadic/microtraderx) which uses simpler, tutorial-focused patterns.

---

## Table of Contents

1. [Filter-Based Deployment](#filter-based-deployment)
2. [Bulk Operations](#bulk-operations)
3. [Label-Based Organization](#label-based-organization)
4. [Two-State Management](#two-state-management)
5. [Layer-Based Deployment](#layer-based-deployment)

---

## Filter-Based Deployment

### What It Is

ConfigHub filters allow you to target multiple units using WHERE clauses, similar to SQL queries.

### Why Use It

- Deploy entire service layers at once
- Update configuration across multiple services simultaneously
- Organize deployments by characteristics (layer, tech stack, criticality)

### Example: Deploy All Backend Services

```bash
# Apply all backend services with a single command
cub unit apply --space traderx-dev --where "Labels.layer = 'backend'"

# vs. the basic pattern (one at a time):
cub unit apply account-service-deployment --space traderx-dev
cub unit apply position-service-deployment --space traderx-dev
cub unit apply trade-service-deployment --space traderx-dev
# ... 4 more services
```

### Implementation in TraderX

See `bin/deploy-by-layer`:

```bash
# Layer 1: Infrastructure
cub unit apply --space $SPACE --where "Labels.order = '0'"

# Layer 2: Data
cub unit apply --space $SPACE --where "Labels.layer = 'data'"

# Layer 3: Backend
cub unit apply --space $SPACE --where "Labels.layer = 'backend'"

# Layer 4: Frontend
cub unit apply --space $SPACE --where "Labels.layer = 'frontend'"
```

### ConfigHub Features Used

- `--where` flag for filtering
- Label-based queries
- Bulk apply operations

---

## Bulk Operations

### What It Is

Update or apply configuration changes to multiple units simultaneously.

### Why Use It

- Scale all services in a layer
- Update environment variables across service groups
- Restart multiple services together
- Manage configuration at scale

### Example: Scale All Backend Services

```bash
# Scale all backend services to 3 replicas
bin/bulk-update replicas backend 3 dev

# Under the hood:
# 1. Query all backend deployments
UNITS=$(cub unit list --space $SPACE --format json | \
  jq -r ".[] | select(.Labels.layer == \"backend\" and (.Slug | contains(\"deployment\"))) | .Slug")

# 2. Update each unit
for unit in $UNITS; do
  cub unit update $unit --space $SPACE --patch '{"spec":{"replicas":3}}'
  cub unit apply $unit --space $SPACE
done
```

### Implementation in TraderX

See `bin/bulk-update`:

```bash
# Scale services
bin/bulk-update replicas backend 3

# Restart services
bin/bulk-update restart backend

# Check status
bin/bulk-update status all
```

### ConfigHub Features Used

- Label-based unit selection
- JSON patch operations
- Update + Apply pattern

---

## Label-Based Organization

### What It Is

Organize units using descriptive labels that enable filtering and bulk operations.

### Why Use It

- Group related services
- Deploy in dependency order
- Query configuration by characteristics
- Support complex deployment patterns

### TraderX Label Schema

```yaml
labels:
  layer: "backend"           # data, backend, frontend
  order: "3"                 # Deployment order (0-8)
  tech: "java"              # java, dotnet, nodejs, python
  service: "account-service" # Service name
  criticality: "high"        # high, medium, low
  type: "app"               # app, infra, data
```

### Example: Query by Labels

```bash
# All Java services
cub unit list --space $SPACE | grep "tech=java"

# Critical backend services
kubectl get pods -n traderx-dev -l layer=backend,criticality=high

# Services in deployment order
for i in {0..8}; do
  cub unit apply --space $SPACE --where "Labels.order = '$i'"
done
```

### Implementation in TraderX

Labels are defined in unit YAMLs:

```yaml
# confighub/base/account-service-deployment.yaml
metadata:
  labels:
    app: account-service
    layer: backend
    order: "3"
    tech: nodejs
    service: account-service
```

And referenced in deployment scripts:

```bash
# bin/deploy-by-layer
cub unit apply --space $SPACE --where "Labels.layer = 'backend'"
```

---

## Two-State Management

### What It Is

ConfigHub maintains two separate states:
1. **Desired State** (ConfigHub database)
2. **Live State** (Kubernetes cluster)

Changes to desired state do NOT automatically update live state.

### Why It Matters

- Prevents accidental deployments
- Enables review before applying
- Supports approval workflows
- Controls change windows

### The Critical Pattern

```bash
# ❌ WRONG - Only updates ConfigHub, doesn't deploy
cub unit update account-service-deployment config.yaml

# ✅ CORRECT - Update ConfigHub AND deploy
cub unit update account-service-deployment config.yaml
cub unit apply account-service-deployment
```

### Implementation in TraderX

Every deployment script follows update + apply:

```bash
# bin/ordered-apply
for service in $SERVICES; do
  # 1. Update desired state in ConfigHub
  cub unit update ${service}-deployment --space $SPACE config.yaml

  # 2. Apply to Kubernetes (live state)
  cub unit apply ${service}-deployment --space $SPACE
done
```

### Verification

```bash
# Check desired state (ConfigHub)
cub unit get account-service-deployment --space $SPACE --data-only

# Check live state (Kubernetes)
cub unit get-live-state account-service-deployment --space $SPACE
# OR
kubectl get deployment account-service -n traderx-dev -o yaml
```

### Full Documentation

See [docs/AUTOUPDATES-AND-GITOPS.md](AUTOUPDATES-AND-GITOPS.md) for comprehensive explanation.

---

## Layer-Based Deployment

### What It Is

Deploy services in layers based on dependencies:
1. Infrastructure (service accounts, RBAC)
2. Data (databases, caches)
3. Backend (application services)
4. Frontend (web UI)

### Why Use It

- Respects service dependencies
- Reduces startup failures
- Enables phased rollouts
- Simplifies troubleshooting

### TraderX Layer Architecture

```
Layer 0: Infrastructure (order=0)
  └─ service-account

Layer 1: Data (order=1, layer=data)
  ├─ database (H2)
  └─ reference-data

Layer 2: Backend (order=2-7, layer=backend)
  ├─ people-service
  ├─ account-service
  ├─ position-service
  ├─ trade-feed
  ├─ trade-service
  └─ trade-processor

Layer 3: Frontend (order=8, layer=frontend)
  └─ web-gui
```

### Implementation

```bash
# bin/deploy-by-layer

# Layer 1: Infrastructure
info "Deploying infrastructure..."
cub unit apply --space $SPACE --where "Labels.order = '0'"
sleep 3

# Layer 2: Data
info "Deploying data layer..."
cub unit apply --space $SPACE --where "Labels.layer = 'data'"
kubectl wait --for=condition=ready pod -l app=database -n traderx-$ENV --timeout=120s

# Layer 3: Backend
info "Deploying backend services..."
cub unit apply --space $SPACE --where "Labels.layer = 'backend'"
sleep 10

# Layer 4: Frontend
info "Deploying frontend..."
cub unit apply --space $SPACE --where "Labels.layer = 'frontend'"
```

### Benefits

- **Automatic dependency resolution** - Database starts before services
- **Faster debugging** - Know which layer failed
- **Phased rollouts** - Deploy backend before frontend
- **Clearer operations** - "Backend is deployed" vs "37 pods deployed"

---

## Comparison: TraderX vs MicroTraderX

| Feature | TraderX (Advanced) | MicroTraderX (Tutorial) |
|---------|-------------------|------------------------|
| **Purpose** | Production deployment | Learning ConfigHub |
| **Services** | 9 full FINOS services | 1-2 simplified services |
| **Patterns** | Filters, bulk ops, layers | Basic create/update/apply |
| **Scripts** | `deploy-by-layer`, `bulk-update` | `setup-structure`, `deploy` |
| **Complexity** | High - real dependencies | Low - progressive stages |
| **Target Audience** | Experienced operators | ConfigHub beginners |
| **Documentation** | Production patterns | ConfigHub fundamentals |

---

## When to Use Each Pattern

### Use Filter-Based Deployment When:
- Deploying multiple related services
- Working with service groups (all backend, all Java services)
- Need repeatable deployment commands

### Use Bulk Operations When:
- Scaling multiple services
- Updating configuration across service groups
- Managing resources at scale

### Use Label-Based Organization When:
- Complex applications with many services
- Need to query/filter by characteristics
- Supporting multiple deployment strategies

### Use Two-State Management When:
- Need approval before deployment
- Testing configuration changes
- Implementing change control

### Use Layer-Based Deployment When:
- Services have dependencies
- Need phased rollouts
- Want clear deployment stages

---

## Next Steps

1. **Try basic deployment**: `bin/ordered-apply dev`
2. **Try layer-based**: `bin/deploy-by-layer dev`
3. **Try bulk operations**: `bin/bulk-update status all`
4. **Compare with tutorial**: See [microtraderx](https://github.com/monadic/microtraderx)

## Related Documentation

- [AUTOUPDATES-AND-GITOPS.md](AUTOUPDATES-AND-GITOPS.md) - Two-state model explained
- [WORKING-STATUS.md](../WORKING-STATUS.md) - Current deployment state (6/9 services working)
- [MicroTraderX README](https://github.com/monadic/microtraderx/README.md) - Tutorial version
