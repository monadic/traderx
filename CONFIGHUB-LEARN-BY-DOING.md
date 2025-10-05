# Learn ConfigHub by Building: TraderX Progressive Tutorial

A hands-on journey from simple deployment to advanced ConfigHub mastery.

---

## Part 1: The 10 Killer Features (Simplified)

### What Makes ConfigHub Unique

1. **ConfigHub IS the Source of Truth (Not Git)**
   Direct operations with no pipeline latency - solves the "waiting for GitOps" problem

2. **Push Changes While Keeping Customizations**
   Update base → flows everywhere preserving local overrides (nobody else can do this)

3. **See Desired vs Actual State Together**
   LiveState tracking shows drift instantly across all environments

4. **Atomic Multi-Service Updates**
   Changesets ensure related changes succeed or fail together

5. **SQL Queries Across Everything**
   `WHERE "Labels.critical = true"` searches ALL spaces/configs at once

6. **Workers Deploy to Kubernetes (No kubectl)**
   ConfigHub manages the deployment agents - you never touch kubectl

7. **Emergency Bypass Routes**
   Lateral promotion skips the normal dev→staging→prod flow when needed

8. **Component-Level Time Travel**
   Rollback individual services to specific revisions, not whole releases

9. **Policy Enforcement at Config Time**
   Triggers with CEL validate changes before they deploy (shift left)

10. **Reusable Filters as Saved Queries**
    Define complex WHERE clauses once, use everywhere as filters

---

## Part 2: Progressive Tutorial - Learn ConfigHub with TraderX

### 📚 What You'll Build

Starting from zero, you'll deploy TraderX (a trading platform) while learning ConfigHub's features progressively. Each stage introduces exactly one new concept.

---

## Stage 1: Just Deploy Something (5 min)

**Goal**: Deploy one service. That's it.

```bash
# Create a space (like a namespace for configs)
cub space create traderx-dev

# Install a Worker (ConfigHub's deployment agent)
# This is CRITICAL - Worker manages Kubernetes for you
cub worker install traderx-worker \
  --space traderx-dev \
  --namespace default \
  --wait

# Create a unit (one piece of configuration)
cat > reference-data.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reference-data
spec:
  replicas: 1
  selector:
    matchLabels:
      app: reference-data
  template:
    metadata:
      labels:
        app: reference-data
    spec:
      containers:
      - name: app
        image: ghcr.io/finos/traderx/reference-data:latest
        ports:
        - containerPort: 8080
EOF

cub unit create reference-data --space traderx-dev reference-data.yaml

# Associate unit with the Worker's target
TARGET=$(cub target list --space traderx-dev --json | jq -r '.[0].TargetID')
cub unit set-target "$TARGET" --space traderx-dev --unit reference-data

# Apply it (Worker deploys to Kubernetes - no kubectl!)
cub unit apply reference-data --space traderx-dev
```

✅ **You learned**: ConfigHub Workers deploy to Kubernetes. You never use kubectl. ConfigHub is the source of truth.

---

## Stage 2: Add Environments (5 min)

**Goal**: Create staging and production environments.

```bash
# Create more spaces
cub space create traderx-staging
cub space create traderx-prod

# Copy unit to staging (explicit copy, simple to understand)
cub unit copy reference-data --from traderx-dev --to traderx-staging

# Copy to prod when ready
cub unit copy reference-data --from traderx-staging --to traderx-prod

# Deploy to each environment
cub unit apply reference-data --space traderx-staging
cub unit apply reference-data --space traderx-prod
```

✅ **You learned**: Each environment is a space, copy units between them.

---

## Stage 3: Change Multiple Services at Once (10 min)

**Goal**: Update all services together.

```bash
# Add more services
cub unit create trade-service --space traderx-dev trade-service.yaml
cub unit create web-gui --space traderx-dev web-gui.yaml

# Create a set to group them
cub set create traderx-core
cub set add-unit traderx-core reference-data trade-service web-gui

# Update all at once using WHERE
cub run set-image-version --version v1.2 \
  --where "SetID = 'traderx-core'" \
  --space traderx-dev

# Apply all together
cub unit apply --where "SetID = 'traderx-core'" --space traderx-dev
```

✅ **You learned**: Sets group units, WHERE clauses target them, bulk operations save time.

---

## Stage 4: See Desired vs Actual State (5 min)

**Goal**: Understand LiveState - ConfigHub tracks both configs AND deployments.

```bash
# View desired configuration (Data) and actual state (LiveState)
cub unit list --space traderx-dev --columns Slug,Data,LiveState

# LiveState shows what's ACTUALLY running in Kubernetes
# Data shows what you WANT to be running

# Make a manual change in Kubernetes (bad practice but for demo)
kubectl scale deployment reference-data --replicas=5

# ConfigHub immediately sees the drift!
cub unit get reference-data --space traderx-dev --json | \
  jq '.Data.spec.replicas, .LiveState.spec.replicas'
# Output: 1 (desired), 5 (actual) - DRIFT DETECTED!

# Fix drift by re-applying from ConfigHub (source of truth)
cub unit apply reference-data --space traderx-dev
# Now back to 1 replica as configured
```

✅ **You learned**: ConfigHub tracks both desired (Data) and actual (LiveState). It's the source of truth.

---

## Stage 5: Search Across Everything (5 min)

**Goal**: Find resources using SQL-like queries.

```bash
# Find all services with high replica counts across ALL environments
cub unit list --space "*" \
  --where "Data CONTAINS 'replicas:' AND Data CONTAINS '5'" \
  --columns Space,Slug

# Find services with specific labels
cub unit update reference-data --space traderx-dev \
  --patch '{"Labels":{"tier":"backend","critical":"true"}}'

cub unit list --space "*" \
  --where "Labels.critical = 'true'"

# Find services using old image versions
cub unit list --space "*" \
  --where "Data CONTAINS 'image:' AND Data CONTAINS 'v1.0'"
```

✅ **You learned**: ConfigHub can query across all spaces with SQL-like WHERE.

---

## Stage 6: Atomic Changes with Changesets (10 min)

**Goal**: Update database and API together atomically.

```bash
# Scenario: API v2 needs database schema v2 (must change together!)

# Create a changeset
cub changeset create api-v2-upgrade

# Lock both units to the changeset
cub changeset associate-unit api-v2-upgrade \
  trade-service \
  database-migration

# Make changes (they're locked together now)
cub run set-image-version --version v2.0 \
  --unit trade-service \
  --space traderx-dev

cub run set-env-var --env-var SCHEMA_VERSION=v2 \
  --unit database-migration \
  --space traderx-dev

# Apply atomically (both succeed or both fail)
cub changeset apply api-v2-upgrade
```

✅ **You learned**: Changesets ensure related changes happen atomically.

---

## Stage 7: Time Travel and Rollback (5 min)

**Goal**: See history, rollback bad changes.

```bash
# See what changed
cub revision list trade-service --space traderx-prod

# Diff specific versions
cub unit diff trade-service --space traderx-prod --from=10 --to=11

# Something broke? Instant rollback!
cub unit apply trade-service --space traderx-prod --revision=10

# Rollback entire changeset if needed
cub changeset rollback api-v2-upgrade
```

✅ **You learned**: Every change is versioned and instantly reversible.

---

## Stage 8: Inheritance for Shared Configs (10 min)

**Goal**: Share common configuration with local overrides.

```bash
# Create base configuration space
cub space create traderx-base

# Create base monitoring config
cat > monitoring-base.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: monitoring
data:
  prometheus: "enabled"
  grafana: "enabled"
  retention: "7d"
EOF

cub unit create monitoring-base --space traderx-base monitoring-base.yaml

# Create environment-specific versions with inheritance
cub unit create monitoring --space traderx-dev \
  --upstream-unit traderx-base/monitoring-base

# Override just retention in prod
cub unit update monitoring --space traderx-prod \
  --patch '{"data":{"retention":"30d"}}'

# Update base (changes flow to all environments!)
cub unit update monitoring-base --space traderx-base \
  --patch '{"data":{"alerting":"enabled"}}'

# Push upgrade (preserves the "30d" override in prod!)
cub unit update --upgrade --patch --space "*"
```

✅ **You learned**: Inheritance lets you share configs while keeping overrides.

---

## Stage 9: Approvals and Compliance (10 min)

**Goal**: Require approval before production changes.

```bash
# Create an approval trigger
cub trigger create require-approval \
  Mutation Kubernetes/YAML \
  vet-approvedby 1 \
  --space traderx-prod

# Try to apply without approval (will fail)
cub unit apply trade-service --space traderx-prod
# Error: Unit requires approval

# Approve the change
cub unit approve trade-service --space traderx-prod

# Now it works
cub unit apply trade-service --space traderx-prod

# Create policy enforcement
cub trigger create replica-limit \
  Mutation Kubernetes/YAML \
  vet-celexpr 'r.kind != "Deployment" || r.spec.replicas <= 10' \
  --space traderx-prod
```

✅ **You learned**: Triggers enforce policies, approvals gate production.

---

## Stage 10: Cross-App Integration (15 min)

**Goal**: Add cost optimization that discovers TraderX automatically.

```bash
# Add labels to make TraderX discoverable
cub unit update --patch \
  --where "SetID = 'traderx-core'" \
  --space "*" \
  --data '{"Labels":{"app":"traderx","cost-optimizable":"true"}}'

# Deploy cost optimizer (separate app!)
cub space create cost-optimizer
cat > cost-optimizer.yaml << 'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cost-optimizer
spec:
  schedule: "0 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: optimizer
            image: cost-optimizer:latest
            env:
            - name: QUERY
              value: "Labels.cost-optimizable = 'true'"
EOF

cub unit create cost-optimizer --space cost-optimizer cost-optimizer.yaml
cub unit apply cost-optimizer --space cost-optimizer

# Cost optimizer discovers TraderX services dynamically!
cub unit list --space "*" --where "Labels.cost-optimizable = 'true'"

# Create link between apps
cub link create cost-tracking \
  traderx-dev/trade-service \
  cost-optimizer/analyzer
```

✅ **You learned**: Apps discover each other dynamically without hardcoding.

---

## Bonus Stage: Advanced - Lateral Promotion (5 min)

**Goal**: Emergency fix to prod-asia, bypassing normal flow.

```bash
# Normal flow: dev → staging → prod-us → prod-asia
# But prod-asia has critical bug!

# Fix directly in prod-asia
cub run set-image-version --version v1.2-hotfix \
  --unit trade-service \
  --space traderx-prod-asia

# Promote fix laterally to prod-eu (skip prod-us)
cub unit update trade-service --space traderx-prod-eu \
  --merge-unit traderx-prod-asia/trade-service \
  --merge-base=15 --merge-end=16

# Later, backfill to maintain consistency
cub unit update trade-service --space traderx-prod-us \
  --merge-unit traderx-prod-asia/trade-service
```

✅ **You learned**: Lateral promotion enables emergency workflows.

---

## Part 3: What You've Built

After completing all stages, you have:

### Architecture
```
traderx-base/          # Shared configs
├── monitoring-base    # Common monitoring

traderx-dev/          # Development
├── reference-data    # Inherits from base
├── trade-service     # Inherits from base
├── web-gui          # Inherits from base
└── monitoring       # Override: retention=7d

traderx-staging/      # Staging
└── (same structure)

traderx-prod/         # Production
└── monitoring       # Override: retention=30d

cost-optimizer/       # Separate app
└── analyzer         # Discovers TraderX via queries
```

### Capabilities Learned
1. **Workers manage Kubernetes** (ConfigHub is source of truth, no kubectl)
2. **Multi-environment** (copy between spaces)
3. **Bulk operations** (Sets and WHERE clauses)
4. **LiveState tracking** (see desired vs actual)
5. **Discovery** (SQL queries across everything)
6. **Atomic updates** (changesets)
7. **Time travel** (revisions, rollback)
8. **Inheritance** (base + overrides)
9. **Compliance** (approvals, policies)
10. **Loose coupling** (dynamic discovery)
Plus: **Lateral promotion** (emergency bypass flows)

---

## Part 4: Why This is Hard Without ConfigHub

Try doing this with other tools:

| What You Did | Helm | Kustomize | GitOps | Terraform |
|-------------|------|-----------|---------|-----------|
| WHERE across all envs | ❌ Can't query | ❌ Can't query | ❌ grep repos | ❌ Can't cross workspaces |
| Atomic multi-service | ❌ Separate releases | ❌ No changesets | ❌ Hope Git syncs | ❌ No changesets |
| Push upgrades + overrides | ❌ Values overwrite | ❌ Patches only | ❌ Manual merge | ❌ No inheritance |
| Lateral promotion | ❌ No concept | ❌ Rigid hierarchy | ❌ Branch locked | ❌ No lateral |
| Dynamic discovery | ❌ Hardcoded deps | ❌ Static patches | ❌ Configure repos | ❌ Data sources only |
| Instant rollback | ⚠️ Per release | ❌ New commit | ❌ New commit | ⚠️ State issues |
| Native approvals | ❌ External tool | ❌ External tool | ⚠️ PR approvals | ❌ External tool |

---

## Part 5: Next Steps

### You're Ready For:
1. **Production use** - You know enough to manage real apps
2. **Building DevOps apps** - Use discovery to build tools that integrate automatically
3. **Complex workflows** - Combine features for advanced patterns

### Advanced Patterns to Explore:
- **GitOps integration** - ConfigHub → Git → Flux/Argo
- **Multi-cluster** - Manage across clusters
- **Disaster recovery** - Instant rollback everything
- **Compliance automation** - Triggers + approvals + audit

---

## Summary: As Simple as Possible, But No Simpler

**Start**: One space, one unit, one apply command
**Grow**: Add environments as spaces, copy between them
**Scale**: Use WHERE queries and sets for bulk operations
**Mature**: Add inheritance, changesets, approvals as needed

**The beauty**: Each stage works completely. You don't need all features day one. But when you need them, they're there and they compose naturally.

ConfigHub grows with you from simple deployments to enterprise-scale operations, and you only pay the complexity cost when you need the capability.