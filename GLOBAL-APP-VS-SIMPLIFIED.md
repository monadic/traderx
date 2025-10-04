# Global-App vs Simplified Pattern - Visual Comparison

## 🔴 Global-App Pattern (Confusing)

```
cub space new-prefix → "chubby-paws"  (What? Why not just "myapp"?)
│
├── Space: chubby-paws (filter storage??)
│   └── Filters: all, app, infra (complex WHERE clauses)
│
├── Space: chubby-paws-base (base configs)
│   ├── Unit: backend (label: type=app)
│   ├── Unit: frontend (label: type=app)
│   └── Unit: postgres (label: type=app)
│
├── Space: chubby-paws-infra (infrastructure)
│   ├── Unit: nginx-base (label: type=infra)
│   ├── Unit: nginx (upstream: nginx-base, label: targetable=true)
│   └── Unit: ns-base (label: type=infra)
│
├── Space: chubby-paws-qa (cloned from base)
│   ├── Unit: backend (upstream: backend in base)
│   ├── Unit: frontend (upstream: frontend in base)
│   └── Unit: namespace (upstream: ns-base in infra)
│
├── Space: chubby-paws-staging (cloned from qa)
│   └── [All units with upstream to qa]
│
└── Space: chubby-paws-prod (cloned from staging)
    └── [All units with upstream to staging]

Filters:
- WHERE Space.Labels.project = 'chubby-paws'
- WHERE Labels.type='app'
- WHERE Labels.type='infra'
```

### Problems:
- 🤯 **6+ spaces** - Which one does what?
- 🤯 **Random prefix** - "chubby-paws"? Really?
- 🤯 **Labels everywhere** - On spaces AND units
- 🤯 **Upstream/downstream** - Complex inheritance chain
- 🤯 **Filter syntax** - SQL-like WHERE clauses
- 🤯 **Separate filter space** - Why??

---

## ✅ Simplified Pattern (Clear)

```
Project: traderx (Just pick a name!)
│
├── Space: traderx-dev
│   ├── namespace
│   ├── service-account
│   ├── app-backend      (prefix tells you it's an app)
│   ├── app-frontend
│   ├── db-postgres      (prefix tells you it's a database)
│   ├── svc-backend      (prefix tells you it's a service)
│   └── infra-nginx      (prefix tells you it's infrastructure)
│
├── Space: traderx-staging
│   └── [Copy from dev when ready]
│
└── Space: traderx-prod
    └── [Copy from staging when ready]

No filters needed! Just use prefixes:
- app-* = applications
- svc-* = services
- db-*  = databases
- infra-* = infrastructure
```

### Benefits:
- ✅ **3 spaces** - One per environment, that's it!
- ✅ **Clear names** - "traderx", not "chubby-paws"
- ✅ **No labels needed** - Prefixes are self-documenting
- ✅ **Simple copy** - No upstream/downstream complexity
- ✅ **No filter syntax** - Just grep for prefixes
- ✅ **Self-contained** - Everything in environment spaces

---

## 📊 Side-by-Side Code Comparison

### Creating the Project

**Global-App (Complex):**
```bash
# Generate random prefix
project=$(cub space new-prefix)  # → "chubby-paws"

# Create filter space (??)
cub space create $project --label project=$project

# Create complex filters
cub filter create all Unit \
  --where-field "Space.Labels.project = '$project'" \
  --space $project

# Create base space
cub space create $project-base \
  --label base=true \
  --label project=$project

# Create infra space
cub space create $project-infra \
  --label project=$project
```

**Simplified (Clear):**
```bash
# Pick a readable name
PROJECT="traderx"

# Create environment spaces
cub space create ${PROJECT}-dev
cub space create ${PROJECT}-staging
cub space create ${PROJECT}-prod

# That's it! No filters, no labels, no confusion
```

---

### Adding a Service

**Global-App (Complex):**
```bash
# Add to base with label
cub unit create --space $project-base backend \
  baseconfig/backend.yaml \
  --label type=app

# Clone to qa with upstream
cub unit create backend \
  --dest-space $project-qa \
  --space $project-base \
  --upstream-unit backend \
  --label targetable=true

# Clone to staging with upstream to qa
cub unit create backend \
  --dest-space $project-staging \
  --space $project-qa \
  --upstream-unit backend
```

**Simplified (Clear):**
```bash
# Add to dev
cub unit create app-backend \
  --space traderx-dev \
  backend.yaml

# Copy to staging when ready
cub unit copy app-backend \
  --from traderx-dev \
  --to traderx-staging
```

---

### Finding Services

**Global-App (Complex):**
```bash
# Need to use filters with WHERE clauses
cub unit list --filter $project/app

# Or complex queries
cub unit list --space $project-qa \
  --where "Labels.type='app' AND Labels.targetable='true'"
```

**Simplified (Clear):**
```bash
# Just use grep!
cub unit list --space traderx-dev | grep "^app-"

# Or list everything (it's all in one space)
cub unit list --space traderx-dev
```

---

### Promoting Changes

**Global-App (Complex):**
```bash
# Use push-upgrade through chain
cub unit update backend \
  --space $project-base \
  --patch --upgrade

# This propagates: base → qa → staging → prod
# But only if upstream relationships are correct!
```

**Simplified (Clear):**
```bash
# Explicit copy (you control exactly what happens)
cub unit get app-backend --space traderx-dev > /tmp/backend.yaml
cub unit update app-backend --space traderx-staging /tmp/backend.yaml

# Or batch copy
for unit in app-backend app-frontend; do
  cub unit copy $unit --from traderx-dev --to traderx-staging
done
```

---

## 🎯 Mental Models

### Global-App Mental Model
"I have a project with a generated prefix that contains spaces for filters, base configs, and infrastructure, plus environment spaces that clone from each other with upstream relationships, and units have labels that match filter WHERE clauses..."

**Time to understand: Hours/Days**

### Simplified Mental Model
"I have one space per environment. Units go in spaces. Deploy with apply."

**Time to understand: 5 minutes**

---

## 🔄 Migration Path

If you're stuck with global-app, here's how to simplify:

```bash
# 1. Find your prefix
OLD_PREFIX=$(cat .cub-project)

# 2. Create simplified structure
PROJECT="myapp"  # Choose a clear name
./bin/install-simplified

# 3. Copy your units with better names
cub unit get backend --space ${OLD_PREFIX}-qa > /tmp/backend.yaml
cub unit create app-backend --space ${PROJECT}-dev /tmp/backend.yaml

# 4. Test the simplified version
./bin/deploy-simplified dev

# 5. Delete the complex structure (after verifying!)
for space in $OLD_PREFIX ${OLD_PREFIX}-base ${OLD_PREFIX}-infra \
             ${OLD_PREFIX}-qa ${OLD_PREFIX}-staging ${OLD_PREFIX}-prod; do
  cub space delete $space --recursive
done
```

---

## 📈 Complexity Metrics

| Metric | Global-App | Simplified | Reduction |
|--------|-----------|------------|-----------|
| **Spaces** | 6+ | 3 | -50% |
| **Concepts** | 8+ (spaces, units, labels, filters, WHERE, upstream, prefix...) | 3 (space, unit, apply) | -63% |
| **Lines to deploy** | 50+ | 10 | -80% |
| **Time to understand** | Hours | Minutes | -95% |
| **Documentation needed** | Pages | Paragraph | -90% |

---

## 🏆 Winner: Simplified Pattern

The simplified pattern:
- ✅ **Easier to learn** - New users productive in minutes
- ✅ **Easier to debug** - Everything is explicit
- ✅ **Easier to maintain** - No hidden relationships
- ✅ **Easier to automate** - Simple scripts, no magic
- ✅ **Easier to document** - "One space per environment"

**The best abstraction is often no abstraction.**