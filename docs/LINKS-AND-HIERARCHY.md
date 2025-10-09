# Links + Multi-Environment Hierarchy Pattern

This document describes TraderX's hybrid ConfigHub deployment pattern that combines:
1. **Links** (from chanwit/traderx) for dependency management
2. **Multi-environment hierarchy** (our pattern) for dev → staging → prod promotion

## Why This Hybrid Approach?

### Chanwit's Pattern (Single Environment)
```bash
# Single space with links
cub unit create --space traderx database ...
cub link create db-to-ns database namespace --space traderx
cub unit apply --space traderx --where "Labels.Project = 'traderx'"
```

**Strengths:**
- Simple and direct
- Links express dependencies clearly
- Bulk apply with automatic ordering
- No manual dependency management

**Limitations:**
- Single environment only
- No dev → staging → prod promotion
- No environment-specific customization

### Our Pattern (Multi-Environment)
```bash
# Multiple spaces with upstream/downstream
cub space create project-base
cub space create project-dev
cub unit create --dest-space project-dev --space project-base --filter all
cub unit update --patch --upgrade --space project-staging  # Push-upgrade
```

**Strengths:**
- Full environment hierarchy
- Push-upgrade for promotion
- Environment-specific overrides
- Production-ready workflow

**Limitations:**
- More complex
- Manual dependency ordering
- No automatic dependency resolution

### Hybrid Approach (Best of Both)

We combine both patterns to get all benefits:

```
project-base (template units)
  └── project-dev (with 20 links)
      └── project-staging (with 20 links)
          └── project-prod (with 20 links)
```

**Benefits:**
- ✅ Links manage dependencies in each environment
- ✅ Multi-environment hierarchy for promotion
- ✅ Automatic dependency ordering via links
- ✅ Push-upgrade between environments
- ✅ Environment-specific customization
- ✅ Production-ready workflow

## Implementation

### 1. Create Base Structure
```bash
bin/install-base      # Creates base space with template units
bin/install-envs      # Creates dev/staging/prod hierarchy
                      # Automatically creates 20 links in each environment
```

### 2. Deploy Using Links
```bash
# Option A: Link-based bulk apply (recommended)
bin/apply-with-links dev

# Option B: Traditional ordered apply
bin/ordered-apply dev

# Option C: Layer-based deployment
bin/deploy-by-layer dev
```

### 3. Promote Between Environments
```bash
bin/promote dev staging    # Push-upgrade propagates changes
bin/apply-with-links staging
```

## Dependency Graph (20 Links per Environment)

Based on chanwit/traderx canonical pattern:

### Namespace Dependencies (10 links)
```
database → namespace
people-service → namespace
reference-data → namespace
trade-feed → namespace
account-service → namespace
position-service → namespace
trade-processor → namespace
trade-service → namespace
web-gui → namespace
ingress → namespace
```

### Database Dependencies (2 links)
```
account-service → database
position-service → database
```

### Trade Processor Dependencies (2 links)
```
trade-processor → database
trade-processor → trade-feed
```

### Trade Service Dependencies (5 links)
```
trade-service → database
trade-service → people-service
trade-service → reference-data
trade-service → trade-feed
trade-service → account-service
```

### Ingress Dependencies (1 link)
```
ingress → namespace
```

## Deployment Comparison

### Single-Environment (Chanwit's Pattern)
```bash
# One-time setup
cub worker run --space traderx worker-traderx -t=kubernetes
cub unit create --space traderx database ...
cub link create ... --space traderx

# Deploy
cub unit apply --space traderx --where "Labels.Project = 'traderx'" --timeout 5m
```

**Use case:** Quick demos, single environment, no promotion workflow

### Multi-Environment with Links (Our Pattern)
```bash
# One-time setup
bin/install-base      # Creates base + filters
bin/install-envs      # Creates dev/staging/prod + 60 links (20 per env)
bin/setup-worker dev

# Deploy to dev
bin/apply-with-links dev

# Promote to staging
bin/promote dev staging
bin/apply-with-links staging

# Promote to prod
bin/promote staging prod
bin/apply-with-links prod
```

**Use case:** Production deployments, multiple environments, controlled promotion

## Benefits of Hybrid Approach

### 1. Automatic Dependency Resolution
ConfigHub uses links to determine correct apply order:
```bash
# No need for manual ordering or sleep commands
cub unit apply --space project-dev --where "Labels.Component = 'service'"
# ConfigHub applies in correct order based on links
```

### 2. Self-Documenting Dependencies
```bash
# View complete dependency graph
cub link list --space project-dev
```

### 3. Environment Promotion
```bash
# Changes in dev automatically flow to staging/prod
cub unit update --patch --data '{"spec":{"replicas":3}}' --space project-dev
bin/promote dev staging  # Propagates replica change
```

### 4. Environment-Specific Overrides
```bash
# Override replicas in prod without affecting dev
cub unit update trade-service --patch --data '{"spec":{"replicas":5}}' --space project-prod
```

## Verification

### Check Links
```bash
# Count links in each environment
cub link list --space $(bin/proj)-dev --format json | jq '. | length'    # Should be 20
cub link list --space $(bin/proj)-staging --format json | jq '. | length' # Should be 20
cub link list --space $(bin/proj)-prod --format json | jq '. | length'    # Should be 20
```

### View Dependency Graph
```bash
# Pretty-print dependency graph
cub link list --space $(bin/proj)-dev --format json | \
  jq -r '.[] | "\(.FromUnitSlug) → \(.ToUnitSlug)"'
```

### Verify Deployment
```bash
# Check all pods running
kubectl get pods -n traderx-dev

# Run health check
bin/health-check dev
```

## References

- **Chanwit's pattern**: https://github.com/chanwit/traderx/blob/main/k8s-manifests/deploy-via-confighub.sh
- **ConfigHub Links**: https://docs.confighub.com/features/links
- **Push-upgrade pattern**: See docs/DEPLOYMENT-PATTERNS.md
