# ConfigHub Links: The Canonical Way to Handle Service Dependencies

**Date**: 2025-10-06
**Source**: https://docs.confighub.com/entities/link/
**Applies To**: TraderX service dependency management

---

## 🚨 Major Gap in Our Implementation

**What we're doing now**: Manual layer-based deployment with labels and `kubectl wait`

**What ConfigHub expects**: Links with needs/provides relationships

---

## The Problem We're Solving Wrong

### Current Approach (Incorrect) ❌

```bash
# bin/deploy-by-layer
# Layer 1: Infrastructure
cub unit apply --space $SPACE --where "Labels.order = '0'"
sleep 3

# Layer 2: Data (database must be ready first)
cub unit apply --space $SPACE --where "Labels.layer = 'data'"
kubectl wait --for=condition=ready pod -l app=database -n traderx-$ENV --timeout=120s

# Layer 3: Backend (depends on database)
cub unit apply --space $SPACE --where "Labels.layer = 'backend'"
sleep 10
```

**Problems**:
1. Manual ordering - we have to know the dependency graph
2. Hardcoded sleeps - unreliable timing
3. kubectl wait - breaks ConfigHub abstraction
4. No dependency tracking - ConfigHub doesn't know relationships
5. Can't auto-detect missing dependencies

### Canonical Approach (Correct) ✅

```bash
# Create links to express dependencies
cub link create trade-service-to-db trade-service-deployment database-deployment --space traderx-dev

# ConfigHub now knows:
# - trade-service NEEDS database connection info
# - database PROVIDES connection info
# - trade-service can't be applied until database provides values

# Apply respects dependencies automatically
cub unit apply trade-service-deployment --space traderx-dev
# ConfigHub: "Wait, this needs database. Let me check if database is ready..."
# ConfigHub: "Database is ready and provides connection info. Proceeding."
```

**Benefits**:
1. ConfigHub manages dependency ordering automatically
2. No manual sleeps or waits
3. Declarative - just express what depends on what
4. ConfigHub validates dependencies before apply
5. Can detect circular dependencies

---

## How Links Work

### Core Concepts

**Link**: A directed relationship from one unit to another
- **From Unit**: The unit that NEEDS something (e.g., trade-service)
- **To Unit**: The unit that PROVIDES something (e.g., database)

**Needs/Provides**:
- **Needs**: What a resource requires to be configured (indicated by placeholder values)
- **Provides**: What a resource offers to others (determined by ConfigHub functions)

**Placeholders**:
- String: `"confighubplaceholder"`
- Integer: `999999999`
- Indicates "this value must be filled in before apply"

### Example: Trade Service Needs Database

**Trade Service Deployment** (needs database connection):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trade-service
spec:
  template:
    spec:
      containers:
      - name: trade-service
        env:
        - name: DB_HOST
          value: "confighubplaceholder"  # NEEDS database hostname
        - name: DB_PORT
          value: "confighubplaceholder"  # NEEDS database port
        - name: DB_NAME
          value: "confighubplaceholder"  # NEEDS database name
```

**Database Deployment** (provides connection info):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
spec:
  template:
    spec:
      containers:
      - name: database
        ports:
        - containerPort: 18082
          name: tcp
---
apiVersion: v1
kind: Service
metadata:
  name: database
spec:
  ports:
  - port: 18082
    name: tcp
  selector:
    app: database
```

**ConfigHub Functions Extract**:
- `get-needed`: Scans trade-service, finds `confighubplaceholder` values
  - Needs: `DB_HOST`, `DB_PORT`, `DB_NAME`
- `get-provided`: Scans database, extracts what it provides
  - Provides: `service.database.svc.cluster.local` (hostname)
  - Provides: `18082` (port)
  - Provides: `traderx` (database name)

**Create Link**:
```bash
cub link create trade-to-db trade-service-deployment database-deployment --space traderx-dev
```

**ConfigHub Auto-Fills**:
When trade-service is applied, ConfigHub:
1. Detects placeholders (needs)
2. Follows link to database unit
3. Extracts provided values
4. Auto-fills placeholders
5. Validates all needs are satisfied
6. Applies with real values

---

## TraderX Service Dependencies

### Current Dependency Graph

#### Visual Representation

```
┌─────────────────────────────────────────────────────────────────┐
│                        TraderX Dependencies                      │
│              (Links connect NEEDS to PROVIDES)                   │
└─────────────────────────────────────────────────────────────────┘

Infrastructure Layer (order=0)
┌────────────────┐   ┌────────────────────┐
│   namespace    │   │  service-account   │
└────────────────┘   └────────────────────┘
        │                      │
        └──────────────┬───────┘
                       │
                       ▼
        ┌──────────────────────────┐
        │   All Pods Deploy Here   │
        └──────────────────────────┘

Data Layer (order=1)
┌──────────────────────────────────────────┐
│          database-deployment             │
│  PROVIDES:                                │
│    • DB_HOST: database.svc.cluster.local │
│    • DB_PORT: 18082                       │
│    • DB_NAME: traderx                     │
│    • DB_USER: sa                          │
│    • DB_PASS: sa                          │
└──────────────────────────────────────────┘
        │
        │ (6 services link to database)
        │
        ├───────────────┬──────────────┬──────────────┬──────────────┬──────────────┐
        ▼               ▼              ▼              ▼              ▼              ▼

Backend Layer (order=2-7)

┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ reference-   │ │ people-      │ │ account-     │ │ position-    │ │ trade-       │ │ trade-       │
│ data         │ │ service      │ │ service      │ │ service      │ │ service      │ │ processor    │
│              │ │              │ │              │ │              │ │              │ │              │
│ NEEDS: DB    │ │ NEEDS: DB    │ │ NEEDS: DB    │ │ NEEDS: DB    │ │ NEEDS: DB    │ │ NEEDS: DB,   │
│              │ │              │ │              │ │              │ │              │ │   trade-svc  │
│ Port: 18085  │ │ Port: 18089  │ │ Port: 18088  │ │ Port: 18090  │ │ Port: 18092  │ │ (async)      │
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
        │               │              │              │              │              │
        │               │              │              │              │              │
        └───────────────┴──────────────┴──────────────┴──────────────┴──────────────┘
                                         │
                                         │ (web-gui links to all backend services)
                                         ▼

Frontend Layer (order=8)
┌──────────────────────────────────────────────────────────────┐
│                     web-gui-deployment                        │
│  NEEDS (HTTP endpoints from backend services):                │
│    • reference-data:18085/api                                 │
│    • people-service:18089/api                                 │
│    • account-service:18088/api                                │
│    • position-service:18090/api                               │
│    • trade-service:18092/api                                  │
│    • trade-feed:18088/api                                     │
│                                                                │
│  Port: 18080 (User Interface)                                 │
└──────────────────────────────────────────────────────────────┘
```

#### Link Relationships (Directed Graph)

```
ConfigHub Links Express These Relationships:

Backend Services → Database:
  account-service-deployment     ──(needs DB)──>  database-deployment
  position-service-deployment    ──(needs DB)──>  database-deployment
  trade-service-deployment       ──(needs DB)──>  database-deployment
  trade-processor-deployment     ──(needs DB)──>  database-deployment

Service-to-Service Dependencies:
  trade-processor-deployment     ──(calls API)──>  trade-service-deployment

Frontend → Backend APIs:
  web-gui-deployment             ──(calls API)──>  reference-data-service
  web-gui-deployment             ──(calls API)──>  people-service-service
  web-gui-deployment             ──(calls API)──>  account-service-service
  web-gui-deployment             ──(calls API)──>  position-service-service
  web-gui-deployment             ──(calls API)──>  trade-service-service
  web-gui-deployment             ──(calls API)──>  trade-feed-service

Total Links: ~16
```

#### Placeholder Example

```yaml
# trade-service-deployment.yaml (NEEDS database)
env:
- name: SPRING_DATASOURCE_URL
  value: "jdbc:h2:tcp://confighubplaceholder:999999999/mem:traderx"
                        ▲             ▲
                        │             │
                    hostname        port
                    (NEEDS)       (NEEDS)

# After ConfigHub resolves via link:
env:
- name: SPRING_DATASOURCE_URL
  value: "jdbc:h2:tcp://database.traderx-dev.svc.cluster.local:18082/mem:traderx"
                        ▲                                          ▲
                        │                                          │
                    PROVIDED by                                 PROVIDED by
                    database-service                            database-service
```

#### Deployment Flow

```
Without Links (Current - Manual):
┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐
│  Apply   │──>   │  sleep   │──>   │  Apply   │──>   │  sleep   │
│ Database │      │    3s    │      │ Backend  │      │   10s    │
└──────────┘      └──────────┘      └──────────┘      └──────────┘
     Manual ordering            Unreliable timing        May fail

With Links (Canonical - Automatic):
┌──────────┐      ┌──────────────────────────────┐      ┌──────────┐
│  Apply   │──>   │  ConfigHub Analyzes Links    │──>   │ Success  │
│   All    │      │  - Computes dependency order │      │  All     │
│  Units   │      │  - Fills placeholders        │      │  Applied │
│          │      │  - Validates before deploy   │      │          │
└──────────┘      └──────────────────────────────┘      └──────────┘
     One command          Automatic                    Guaranteed order
```

### Links We Should Create

```bash
#!/bin/bash
# bin/create-links

PROJECT=$(cat .cub-project)
SPACE="${PROJECT}-dev"

# Backend services → Database
for service in reference-data people-service account-service position-service trade-service trade-processor; do
  cub link create ${service}-to-db \
    ${service}-deployment \
    database-deployment \
    --space $SPACE \
    --label relationship=dependency \
    --label type=database
done

# trade-processor → trade-service
cub link create trade-processor-to-trade-service \
  trade-processor-deployment \
  trade-service-deployment \
  --space $SPACE \
  --label relationship=dependency \
  --label type=service

# web-gui → all backend services
for service in reference-data people-service account-service position-service trade-service trade-feed; do
  cub link create web-gui-to-${service} \
    web-gui-deployment \
    ${service}-service \
    --space $SPACE \
    --label relationship=dependency \
    --label type=api
done
```

---

## Link Commands Reference

### Create Single Link

```bash
# Syntax
cub link create <link-slug> <from-unit> <to-unit> [<to-space>] --space <space>

# Example: trade-service depends on database
cub link create trade-to-db trade-service-deployment database-deployment --space traderx-dev

# Cross-space link (e.g., dev unit links to base namespace)
cub link create dev-to-base-ns my-deployment my-namespace base-space --space dev-space
```

### Bulk Link Creation

```bash
# Create links between all deployments and namespace
cub link create \
  --where-space "Slug = 'traderx-dev'" \
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
cub link list --space traderx-dev

# Links from a specific unit
cub link list --space traderx-dev --where "FromUnitID = '<unit-id>'"

# Links to a specific unit
cub link list --space traderx-dev --where "ToUnitID = '<unit-id>'"
```

### Delete Link

```bash
cub link delete trade-to-db --space traderx-dev
```

---

## Using Placeholders in TraderX

### Step 1: Update Unit Definitions with Placeholders

**Before** (current - hardcoded values):
```yaml
# confighub/base/trade-service-deployment.yaml
env:
- name: SPRING_DATASOURCE_URL
  value: "jdbc:h2:tcp://database:18082/mem:traderx"
- name: SPRING_DATASOURCE_USERNAME
  value: "sa"
- name: SPRING_DATASOURCE_PASSWORD
  value: "sa"
```

**After** (with placeholders):
```yaml
# confighub/base/trade-service-deployment.yaml
env:
- name: SPRING_DATASOURCE_URL
  value: "jdbc:h2:tcp://confighubplaceholder:confighubplaceholder/mem:traderx"
- name: SPRING_DATASOURCE_USERNAME
  value: "confighubplaceholder"
- name: SPRING_DATASOURCE_PASSWORD
  value: "confighubplaceholder"
```

### Step 2: Database Unit Provides Values

Database deployment doesn't need changes - ConfigHub's `get-provided` function automatically extracts:
- Service hostname from Service manifest
- Port from Service spec
- Database name from environment variables or config

### Step 3: Create Links

```bash
cub link create trade-service-to-db \
  trade-service-deployment \
  database-deployment \
  --space traderx-dev
```

### Step 4: Apply

```bash
# ConfigHub auto-fills placeholders from database unit
cub unit apply trade-service-deployment --space traderx-dev
```

**Result**: Deployed trade-service has actual values from database, not placeholders.

---

## Advantages vs Current Approach

| Aspect | Current (Labels + Sleep) | Links + Needs/Provides |
|--------|-------------------------|------------------------|
| **Dependency Expression** | Manual labels (layer, order) | Explicit links (declarative) |
| **Ordering** | Hardcoded in scripts | ConfigHub computes automatically |
| **Timing** | `sleep 10`, `kubectl wait` | ConfigHub knows when ready |
| **Configuration** | Hardcoded connection strings | Auto-filled from provider |
| **Validation** | Manual inspection | ConfigHub validates before apply |
| **Abstraction** | Leaks to kubectl | Pure ConfigHub |
| **Circular Deps** | Runtime failure | ConfigHub detects before apply |
| **Documentation** | README + comments | Links are self-documenting |
| **Changes** | Update multiple places | Update provider once, consumers auto-update |

---

## Migration Path for TraderX

### Phase 1: Add Placeholders (Low Risk)

```bash
# Update YAML files to use placeholders
# This doesn't break anything - just marks values as "should be dynamic"

for file in confighub/base/*-deployment.yaml; do
  # Replace hardcoded database URLs with placeholders
  sed -i 's/database:18082/confighubplaceholder:confighubplaceholder/g' "$file"
done
```

### Phase 2: Create Links (Medium Risk)

```bash
# Create links between units
bin/create-links  # New script

# Verify links created
cub link list --space traderx-dev --format json | jq '.[] | {from: .FromUnitSlug, to: .ToUnitSlug}'
```

### Phase 3: Test Apply with Links (High Risk)

```bash
# Apply one service to test
cub unit apply trade-service-deployment --space traderx-dev

# Verify placeholders were filled
cub unit get-live-state trade-service-deployment --space traderx-dev | grep DATASOURCE_URL
# Should show: jdbc:h2:tcp://database.traderx-dev.svc.cluster.local:18082/mem:traderx
```

### Phase 4: Remove Manual Ordering (Cleanup)

```bash
# Replace bin/deploy-by-layer with simple:
cub unit apply --space traderx-dev --where "*"

# ConfigHub handles dependencies automatically via links!
```

---

## Triggers for Validation

Add triggers to ensure placeholders are filled before apply:

```bash
# Prevent applying units with unfilled placeholders
cub trigger create \
  --space traderx-dev \
  validate-complete \
  Mutation \
  "Kubernetes/YAML" \
  no-placeholders

# Now if you try to apply a unit with placeholders (no link), it blocks:
# Error: Unit has unfilled placeholders - cannot apply
```

---

## How This Fixes Our Problems

### Problem 1: Database Not Ready
**Before**:
```bash
cub unit apply trade-service-deployment --space traderx-dev
# Pods crash: "Connection refused: database:18082"
```

**After**:
```bash
cub unit apply trade-service-deployment --space traderx-dev
# ConfigHub: "This needs database. Checking link..."
# ConfigHub: "Database unit exists and provides connection info."
# ConfigHub: "Filling placeholders with: database.traderx-dev.svc.cluster.local:18082"
# ConfigHub: "Applying with real values."
# Pods start successfully!
```

### Problem 2: Hardcoded Connection Strings
**Before**: Change database port → update 6 service deployments

**After**: Change database port → ConfigHub auto-updates all linked consumers

### Problem 3: Manual Dependency Tracking
**Before**: Maintain order in README, scripts, and mental model

**After**: Links ARE the dependency graph. Visual, queryable, validated.

---

## Query Examples

```bash
# What does trade-service depend on?
cub link list --space traderx-dev --where "FromUnitSlug = 'trade-service-deployment'" \
  --format json | jq '.[] | .ToUnitSlug'

# What depends on database?
cub link list --space traderx-dev --where "ToUnitSlug = 'database-deployment'" \
  --format json | jq '.[] | .FromUnitSlug'

# Visualize dependency graph
cub link list --space traderx-dev --format json | \
  jq -r '.[] | "\(.FromUnitSlug) → \(.ToUnitSlug)"' | \
  sort
```

**Output**:
```
account-service-deployment → database-deployment
people-service-deployment → database-deployment
position-service-deployment → database-deployment
reference-data-deployment → database-deployment
trade-processor-deployment → database-deployment
trade-processor-deployment → trade-service-deployment
trade-service-deployment → database-deployment
web-gui-deployment → account-service-service
web-gui-deployment → people-service-service
web-gui-deployment → position-service-service
web-gui-deployment → reference-data-service
web-gui-deployment → trade-feed-service
web-gui-deployment → trade-service-service
```

---

## Comparison with Other Tools

### Helm (Dependencies)
```yaml
# Chart.yaml
dependencies:
  - name: postgresql
    version: "11.x.x"
```
**Limitation**: Only works within Helm charts. Can't link to external resources.

### Terraform (Depends On)
```hcl
resource "aws_instance" "web" {
  depends_on = [aws_db_instance.database]
}
```
**Limitation**: Apply-time only. No runtime dependency tracking.

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

## Advanced: Cross-Space Links

```bash
# Dev trade-service links to base namespace
cub link create dev-trade-to-base-ns \
  trade-service-deployment \
  namespace \
  ${PROJECT}-base \
  --space ${PROJECT}-dev

# Now dev can inherit namespace config from base
```

**Use case**: Shared infrastructure units (namespace, RBAC) in base space, app units in env spaces.

---

## Recommendations

### Immediate Actions

1. **Create `bin/create-links`** - Script to establish all TraderX dependencies
2. **Add placeholders** - Update database connection strings to use `confighubplaceholder`
3. **Test single link** - Try trade-service → database link first
4. **Add validation trigger** - Prevent applying units with unfilled placeholders

### Medium-Term

5. **Replace layer-based deployment** - Let ConfigHub handle ordering via links
6. **Document link graph** - Generate visual dependency diagram
7. **Add link labels** - relationship=dependency, type=database/service/api

### Long-Term

8. **Cross-environment links** - Dev links to base infrastructure
9. **Functions for providers** - Custom functions to extract provided values
10. **Approval gates** - Require approval to change links in production

---

## Status in TraderX

**Current**: ❌ Not using links at all
- Pattern 12 in README claims "Link Management" but not implemented
- No `cub link create` commands in any scripts
- Dependencies managed manually via labels + sleep + kubectl wait

**Should be**: ✅ Links are the canonical pattern
- Replace layer-based deployment with link-driven dependencies
- Use placeholders for dynamic configuration
- Let ConfigHub compute topological sort for apply order

---

## References

- **ConfigHub Docs**: https://docs.confighub.com/entities/link/
- **Needs/Provides**: https://docs.confighub.com/concepts/needsprovides/
- **Placeholders**: https://docs.confighub.com/concepts/placeholders/
- **Link CLI Code**: `/Users/alexis/Public/github-repos/confighub-latest/public/cmd/cub/link_create.go`

---

**Document Created**: 2025-10-06
**Key Insight**: Links with needs/provides is the **canonical ConfigHub pattern** for dependencies, not manual ordering
**Action Required**: Implement links in TraderX to replace layer-based deployment
