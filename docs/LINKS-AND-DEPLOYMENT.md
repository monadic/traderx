# ConfigHub Links and Deployment Patterns

**Date**: 2025-10-09
**Pattern**: Hybrid approach combining Links + Multi-Environment Hierarchy
**Source**: https://docs.confighub.com/entities/link/

This document explains ConfigHub's canonical pattern for handling service dependencies using Links, and how it combines with multi-environment hierarchies for production deployments.

---

## Executive Summary

**ConfigHub's Canonical Pattern**: Links with needs/provides relationships
**Our Implementation**: Hybrid pattern combining links (chanwit) + multi-env hierarchy (ours)
**Benefits**: Automatic dependency resolution + environment promotion workflow

---

## Part 1: ConfigHub Links Fundamentals

### The Problem We're Solving

**Current Approach** (Manual - ❌ Not Canonical):
```bash
# Manual layer-based deployment
cub unit apply --space $SPACE --where "Labels.order = '0'"
sleep 3
cub unit apply --space $SPACE --where "Labels.layer = 'data'"
kubectl wait --for=condition=ready pod -l app=database
```

**Problems**:
- Manual ordering - we must know the dependency graph
- Hardcoded sleeps - unreliable timing
- kubectl wait - breaks ConfigHub abstraction
- No dependency tracking - ConfigHub doesn't know relationships

**Canonical Approach** (Links - ✅ ConfigHub Standard):
```bash
# Create links to express dependencies
cub link create trade-service-to-db trade-service-deployment database-deployment --space dev

# Apply respects dependencies automatically
cub unit apply trade-service-deployment --space dev
# ConfigHub: "This needs database. Checking..."
# ConfigHub: "Database ready. Filling placeholders. Applying."
```

**Benefits**:
- ConfigHub manages ordering automatically
- No manual sleeps or waits
- Declarative - express what depends on what
- ConfigHub validates dependencies before apply
- Detects circular dependencies

### How Links Work

**Core Concepts**:
- **Link**: Directed relationship from unit A (NEEDS) to unit B (PROVIDES)
- **Needs**: What a resource requires (indicated by `"confighubplaceholder"` or `999999999`)
- **Provides**: What a resource offers (extracted by ConfigHub functions)

**Example**:

Trade Service (NEEDS database):
```yaml
env:
- name: DB_HOST
  value: "confighubplaceholder"  # NEEDS database hostname
- name: DB_PORT
  value: "999999999"  # NEEDS database port
```

Database (PROVIDES connection info):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: database
spec:
  ports:
  - port: 18082
```

**Create Link**:
```bash
cub link create trade-to-db trade-service-deployment database-deployment --space dev
```

**ConfigHub Auto-Fills**:
1. Detects placeholders (needs)
2. Follows link to database unit
3. Extracts provided values (hostname, port)
4. Auto-fills placeholders
5. Validates all needs satisfied
6. Applies with real values

### TraderX Dependency Graph

**Total Links**: 20 per environment (based on chanwit/traderx pattern)

**Namespace Dependencies** (10 links):
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

**Database Dependencies** (2 links):
```
account-service → database
position-service → database
```

**Trade Processor Dependencies** (2 links):
```
trade-processor → database
trade-processor → trade-feed
```

**Trade Service Dependencies** (5 links):
```
trade-service → database
trade-service → people-service
trade-service → reference-data
trade-service → trade-feed
trade-service → account-service
```

**Ingress Dependencies** (1 link):
```
ingress → namespace
```

**Visual Graph**:
```
Infrastructure (order=0)
    namespace
        │
        ├─────────┬─────────┬─────────┐
        ▼         ▼         ▼         ▼
Data (order=1)
    database
        │
        ├────────┬────────┬────────┬────────┐
        ▼        ▼        ▼        ▼        ▼
Backend (order=2-7)
    reference-data  people-service  account-service  position-service  trade-service
        │               │               │                │                │
        └───────────────┴───────────────┴────────────────┴────────────────┘
                                        │
                                        ▼
Frontend (order=8)
                                    web-gui
```

---

## Part 2: Hybrid Pattern (Links + Multi-Environment)

### Why Hybrid Approach?

**Chanwit's Pattern** (Single Environment):
```bash
cub unit create --space traderx database ...
cub link create db-to-ns database namespace --space traderx
cub unit apply --space traderx --where "*"
```
- ✅ Simple, direct, automatic dependency ordering
- ❌ Single environment only, no promotion workflow

**Our Pattern** (Multi-Environment):
```bash
cub space create project-base
cub space create project-dev  # with upstream to base
cub unit update --patch --upgrade --space project-staging
```
- ✅ Full hierarchy, push-upgrade, env-specific overrides
- ❌ Manual dependency ordering, no automatic resolution

**Hybrid Approach** (Best of Both):
```
project-base (template units)
  └── project-dev (20 links)
      └── project-staging (20 links)
          └── project-prod (20 links)
```

**Benefits**:
- ✅ Links manage dependencies in each environment
- ✅ Multi-environment hierarchy for promotion
- ✅ Automatic dependency ordering via links
- ✅ Push-upgrade between environments
- ✅ Environment-specific customization
- ✅ Production-ready workflow

### Implementation

**1. Create Structure**:
```bash
bin/install-base      # Creates base space with template units
bin/install-envs      # Creates dev/staging/prod hierarchy
                      # Automatically creates 20 links in each environment
```

**2. Deploy Using Links**:
```bash
# Option A: Link-based bulk apply (recommended)
bin/apply-with-links dev

# Option B: Traditional ordered apply
bin/ordered-apply dev

# Option C: Layer-based deployment
bin/deploy-by-layer dev
```

**3. Promote Between Environments**:
```bash
bin/promote dev staging    # Push-upgrade propagates changes
bin/apply-with-links staging
```

---

## Part 3: Link Commands Reference

### Create Single Link
```bash
# Syntax
cub link create <link-slug> <from-unit> <to-unit> [<to-space>] --space <space>

# Example
cub link create trade-to-db trade-service-deployment database-deployment --space dev

# Cross-space link (dev links to base namespace)
cub link create dev-to-base-ns my-deployment namespace base-space --space dev-space
```

### Bulk Link Creation
```bash
# Using WHERE clauses
cub link create \
  --where-space "Slug = 'dev'" \
  --where-from "Labels.layer = 'backend'" \
  --where-to "Slug = 'database-deployment'"

# Using filters
cub link create \
  --filter-space prod-spaces \
  --filter-from backend-services \
  --filter-to database-services
```

### List Links
```bash
# All links in a space
cub link list --space dev

# Links from a specific unit
cub link list --space dev --where "FromUnitSlug = 'trade-service-deployment'"

# Links to a specific unit
cub link list --space dev --where "ToUnitSlug = 'database-deployment'"

# Pretty-print dependency graph
cub link list --space dev --format json | \
  jq -r '.[] | "\(.FromUnitSlug) → \(.ToUnitSlug)"'
```

### Delete Link
```bash
cub link delete trade-to-db --space dev
```

---

## Part 4: Using Placeholders

### Step 1: Add Placeholders to Unit Definitions

**Before** (hardcoded):
```yaml
env:
- name: SPRING_DATASOURCE_URL
  value: "jdbc:h2:tcp://database:18082/mem:traderx"
- name: SPRING_DATASOURCE_USERNAME
  value: "sa"
```

**After** (with placeholders):
```yaml
env:
- name: SPRING_DATASOURCE_URL
  value: "jdbc:h2:tcp://confighubplaceholder:confighubplaceholder/mem:traderx"
- name: SPRING_DATASOURCE_USERNAME
  value: "confighubplaceholder"
```

### Step 2: Provider Unit (No Changes Needed)

Database deployment doesn't need changes - ConfigHub's `get-provided` automatically extracts:
- Service hostname from Service manifest
- Port from Service spec
- Database name from environment variables

### Step 3: Create Link
```bash
cub link create trade-to-db trade-service-deployment database-deployment --space dev
```

### Step 4: Apply
```bash
cub unit apply trade-service-deployment --space dev
# ConfigHub auto-fills placeholders from database unit
```

**Result**: Deployed trade-service has actual values from database.

---

## Part 5: Advantages vs Current Approach

| Aspect | Labels + Sleep | Links + Needs/Provides |
|--------|---------------|------------------------|
| Dependency Expression | Manual labels | Explicit declarative links |
| Ordering | Hardcoded in scripts | ConfigHub computes automatically |
| Timing | `sleep 10`, `kubectl wait` | ConfigHub knows when ready |
| Configuration | Hardcoded strings | Auto-filled from provider |
| Validation | Manual inspection | ConfigHub validates before apply |
| Abstraction | Leaks to kubectl | Pure ConfigHub |
| Circular Deps | Runtime failure | Detected before apply |
| Documentation | README + comments | Links are self-documenting |
| Changes | Update multiple places | Update provider once, auto-propagate |

---

## Part 6: Deployment Comparison

### Single-Environment (Chanwit's Pattern)

```bash
# Setup
cub worker run --space traderx worker-traderx -t=kubernetes
cub unit create --space traderx database ...
cub link create ... --space traderx

# Deploy
cub unit apply --space traderx --where "*" --timeout 5m
```

**Use case**: Quick demos, single environment, no promotion

### Multi-Environment with Links (Hybrid Pattern)

```bash
# Setup
bin/install-base      # Base + filters
bin/install-envs      # Dev/staging/prod + 60 links (20 per env)
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

**Use case**: Production, multiple environments, controlled promotion

---

## Part 7: Query Examples

**What does trade-service depend on?**
```bash
cub link list --space dev --where "FromUnitSlug = 'trade-service-deployment'" \
  --format json | jq '.[] | .ToUnitSlug'
```

**What depends on database?**
```bash
cub link list --space dev --where "ToUnitSlug = 'database-deployment'" \
  --format json | jq '.[] | .FromUnitSlug'
```

**Visualize full dependency graph**:
```bash
cub link list --space dev --format json | \
  jq -r '.[] | "\(.FromUnitSlug) → \(.ToUnitSlug)"' | \
  sort
```

**Expected Output**:
```
account-service-deployment → database-deployment
people-service-deployment → database-deployment
position-service-deployment → database-deployment
trade-processor-deployment → database-deployment
trade-service-deployment → database-deployment
web-gui-deployment → account-service-service
web-gui-deployment → people-service-service
...
```

---

## Part 8: Verification

### Check Links
```bash
# Count links in each environment
cub link list --space $(bin/proj)-dev --format json | jq '. | length'    # Should be 20
cub link list --space $(bin/proj)-staging --format json | jq '. | length' # Should be 20
cub link list --space $(bin/proj)-prod --format json | jq '. | length'    # Should be 20
```

### View Dependency Graph
```bash
cub link list --space $(bin/proj)-dev --format json | \
  jq -r '.[] | "\(.FromUnitSlug) → \(.ToUnitSlug)"'
```

### Verify Deployment
```bash
kubectl get pods -n traderx-dev
bin/health-check dev
```

---

## Part 9: Migration Path

### Phase 1: Add Placeholders (Low Risk)
```bash
# Update YAML files to use placeholders
for file in confighub/base/*-deployment.yaml; do
  sed -i 's/database:18082/confighubplaceholder:confighubplaceholder/g' "$file"
done
```

### Phase 2: Create Links (Medium Risk)
```bash
bin/create-links  # Script to create all 20 links
cub link list --space dev --format json | jq '.[] | {from: .FromUnitSlug, to: .ToUnitSlug}'
```

### Phase 3: Test Apply (High Risk)
```bash
# Apply one service to test
cub unit apply trade-service-deployment --space dev

# Verify placeholders were filled
cub unit get-live-state trade-service-deployment --space dev | grep DATASOURCE_URL
```

### Phase 4: Remove Manual Ordering (Cleanup)
```bash
# Replace bin/deploy-by-layer with:
cub unit apply --space dev --where "*"
# ConfigHub handles dependencies automatically!
```

---

## Part 10: Comparison with Other Tools

### Helm (Dependencies)
```yaml
dependencies:
  - name: postgresql
    version: "11.x.x"
```
**Limitation**: Only within Helm charts, can't link external resources

### Terraform (Depends On)
```hcl
resource "aws_instance" "web" {
  depends_on = [aws_db_instance.database]
}
```
**Limitation**: Apply-time only, no runtime tracking

### ConfigHub Links
```bash
cub link create web-to-db web-instance database-instance --space prod
```
**Advantages**:
- Works across any resource type
- Tracks needs/provides relationship
- Auto-fills configuration values
- Validates before apply
- Cross-space links supported

---

## Status in TraderX

**Current**: ✅ Links implemented (20 per environment)
- Pattern based on chanwit/traderx canonical implementation
- Full multi-environment hierarchy (base → dev → staging → prod)
- Automatic dependency resolution via links
- Push-upgrade for environment promotion

**Script**: `bin/apply-with-links` - Recommended deployment method

---

## Recommendations

### Immediate Actions
1. Use `bin/apply-with-links` for deployments (automatic ordering)
2. Verify links: `cub link list --space $(bin/proj)-dev`
3. View dependency graph for documentation

### Medium-Term
4. Add placeholders for dynamic configuration
5. Create validation triggers for unfilled placeholders
6. Document link graph visually

### Long-Term
7. Cross-environment links (dev links to base infrastructure)
8. Custom functions for provider extraction
9. Approval gates for production link changes

---

## References

- **ConfigHub Links**: https://docs.confighub.com/entities/link/
- **Needs/Provides**: https://docs.confighub.com/concepts/needsprovides/
- **Chanwit's Pattern**: https://github.com/chanwit/traderx/blob/main/k8s-manifests/deploy-via-confighub.sh
- **Our Implementation**: https://github.com/monadic/traderx

---

**Key Insight**: Links with needs/provides is the **canonical ConfigHub pattern** for dependencies
**Action**: Use links for automatic dependency resolution, avoid manual ordering
**Status**: Implemented in TraderX with hybrid multi-environment approach

---

This document replaces:
- `docs/LINKS-DEPENDENCIES.md` (comprehensive links guide)
- `docs/LINKS-AND-HIERARCHY.md` (hybrid pattern explanation)

All links documentation is now consolidated in this authoritative reference.
