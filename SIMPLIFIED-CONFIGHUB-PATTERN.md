# Simplified ConfigHub Pattern

A simpler ConfigHub pattern for single-region deployments and small teams. This is an alternative to global-app, not a replacement.

---

## 📌 Important Context

After reviewing the global-app documentation and understanding its design goals (issue #2880), I now understand that **global-app's complexity is justified for enterprise scenarios** like:
- Multi-region deployments (US, EU, Asia)
- Multi-team governance (app teams vs platform teams)
- Lateral promotion strategies
- Merging upstream updates with local customizations
- Atomic changesets across multiple units

**This simplified pattern is for the OTHER 80% of use cases** - single-region apps, small teams, and projects like TraderX.

---

## 🚨 When Global-App is Too Complex

For simple deployments, the global-app pattern has unnecessary complexity:

```
Project: chubby-paws
├── Space: chubby-paws (just for filters??)
├── Space: chubby-paws-base (base configs)
├── Space: chubby-paws-infra (infrastructure)
├── Space: chubby-paws-qa (environment)
├── Space: chubby-paws-staging (environment)
└── Space: chubby-paws-prod (environment)

Plus:
- Labels on spaces (project=chubby-paws, base=true)
- Labels on units (type=app, type=infra, targetable=true)
- Complex filters with WHERE clauses
- Upstream/downstream relationships
```

**This is confusing because:**
- Why is there a space just for filters?
- What's the difference between base and infra?
- Too many labels doing similar things
- Unit names vs space names vs labels - which matters when?

---

## ✅ Simplified Pattern: "One Space Per Environment"

### Core Principle
**One space = One deployment target**. That's it.

### Naming Convention
```
myapp-dev       # Development environment
myapp-staging   # Staging environment
myapp-prod      # Production environment
```

No separate base/infra/filter spaces. Everything for an environment goes IN that environment's space.

### Units = Kubernetes Resources
Each unit is just a Kubernetes resource with a clear name:
```
namespace           # The namespace
service-account     # Service account
postgres            # PostgreSQL deployment + service
backend-api         # Backend API deployment + service
frontend-web        # Frontend deployment + service
ingress             # Ingress controller
```

### No Complex Labels
Instead of labels everywhere, use simple prefixes in unit names:
```
app-backend         # Application service
app-frontend        # Application service
db-postgres         # Database
db-redis            # Cache
infra-nginx         # Infrastructure
infra-monitoring    # Infrastructure
```

---

## 📝 Implementation

### Step 1: Create Your Environments
```bash
#!/bin/bash
# Simplified install script

PROJECT="myapp"  # Simple, readable name

# Create environments (no prefix generation!)
cub space create ${PROJECT}-dev
cub space create ${PROJECT}-staging
cub space create ${PROJECT}-prod

# That's it! No filter space, no base space
```

### Step 2: Create Units Directly
```bash
# Add units to dev (no complex cloning)
cub unit create namespace --space myapp-dev namespace.yaml
cub unit create service-account --space myapp-dev service-account.yaml
cub unit create app-backend --space myapp-dev backend.yaml
cub unit create app-frontend --space myapp-dev frontend.yaml
cub unit create db-postgres --space myapp-dev postgres.yaml
```

### Step 3: Copy to Other Environments
```bash
# Simple copy from dev to staging (no upstream/downstream complexity)
for unit in $(cub unit list --space myapp-dev --format json | jq -r '.[].Slug'); do
  cub unit copy $unit --from myapp-dev --to myapp-staging
done
```

### Step 4: Promote Changes
```bash
# When ready to promote a change from dev to staging
cub unit get app-backend --space myapp-dev > /tmp/backend.yaml
cub unit update app-backend --space myapp-staging /tmp/backend.yaml
```

---

## 🎯 Simplified Filters

Instead of complex WHERE clauses, use simple name patterns:

```bash
# Get all app units (starts with "app-")
cub unit list --space myapp-dev | grep "^app-"

# Get all database units (starts with "db-")
cub unit list --space myapp-dev | grep "^db-"

# Get all units in production
cub unit list --space myapp-prod
```

If you really need filters, keep them simple:
```bash
# One filter per type (in the environment space, not separate)
cub filter create apps Unit --where "Slug LIKE 'app-%'" --space myapp-dev
cub filter create databases Unit --where "Slug LIKE 'db-%'" --space myapp-dev
```

---

## 🚀 Simplified Deployment Script

```bash
#!/bin/bash
# deploy.sh - Dead simple deployment

PROJECT="myapp"
ENV=${1:-dev}
SPACE="${PROJECT}-${ENV}"

# Define order (simple array, no complex dependencies)
units=(
  "namespace"
  "service-account"
  "db-postgres"      # Databases first
  "db-redis"
  "app-backend"      # Then backend
  "app-frontend"     # Then frontend
  "infra-nginx"      # Then infrastructure
)

# Deploy in order
for unit in "${units[@]}"; do
  echo "Deploying $unit..."
  cub unit apply $unit --space $SPACE || exit 1
done

echo "✅ Deployment complete!"
```

---

## 📊 Comparison

| Aspect | Global-App Pattern | Simplified Pattern |
|--------|-------------------|-------------------|
| **Spaces per project** | 6+ spaces | 3 spaces (dev/staging/prod) |
| **Naming** | Generated prefix (chubby-paws) | Simple name (myapp) |
| **Base configs** | Separate base space + cloning | Direct creation in each env |
| **Filters** | Complex WHERE clauses | Simple name patterns |
| **Labels** | Labels everywhere | Prefixes in unit names |
| **Promotion** | upstream/downstream chain | Simple copy between spaces |
| **Mental model** | Complicated hierarchy | One space = one environment |

---

## 🔄 Migration from Global-App

To migrate existing global-app deployments:

```bash
# 1. List all your units
OLD_PREFIX=$(cat .cub-project)
cub unit list --space ${OLD_PREFIX}-qa

# 2. Create new simplified structure
PROJECT="myapp"  # Choose a simple name
cub space create ${PROJECT}-dev
cub space create ${PROJECT}-staging
cub space create ${PROJECT}-prod

# 3. Copy units with simplified names
cub unit get backend --space ${OLD_PREFIX}-qa > /tmp/backend.yaml
cub unit create app-backend --space ${PROJECT}-dev /tmp/backend.yaml

# 4. Delete old complex structure (after testing!)
cub space delete ${OLD_PREFIX} --recursive
cub space delete ${OLD_PREFIX}-base --recursive
cub space delete ${OLD_PREFIX}-infra --recursive
```

---

## 💡 Key Principles

1. **One space = One environment** - No confusion about what goes where
2. **Simple names** - `myapp-dev` not `chubby-paws-qa`
3. **Prefixes over labels** - `app-backend` tells you it's an app
4. **Direct operations** - No complex cloning or upstream/downstream
5. **Explicit over implicit** - Write what you mean, don't rely on magic

---

## 🎓 Teaching ConfigHub

With this simplified pattern, explaining ConfigHub becomes easy:

**"ConfigHub has spaces (environments) and units (configs). You put your Kubernetes YAML into units, organize them in spaces for each environment, and deploy with `cub unit apply`. That's it!"**

Compare to global-app:

**"ConfigHub has spaces for projects, filters, base configs, infrastructure, and environments. You create units with labels, define filters with WHERE clauses, set up upstream/downstream relationships, use generated prefixes..."** 😵

---

## Example: TraderX with Simplified Pattern

Instead of the complex TraderX setup, we'd have:

```bash
# Simple structure
traderx-dev/
  ├── namespace
  ├── service-account
  ├── app-reference-data
  ├── app-people-service
  ├── app-account-service
  ├── app-position-service
  ├── app-trade-service
  ├── app-trade-processor
  ├── app-trade-feed
  ├── app-web-gui
  └── infra-ingress

# Simple deployment
for unit in namespace service-account app-* infra-*; do
  cub unit apply $unit --space traderx-dev
done

# Simple promotion
cub unit copy app-trade-service --from traderx-dev --to traderx-staging
```

No `mellow-muzzle-traderx-base`, no filters space, no complex labels!

---

## Conclusion

The global-app pattern tries to be too clever with its abstractions. The simplified pattern:
- ✅ Reduces cognitive load
- ✅ Makes ConfigHub approachable
- ✅ Still provides all needed functionality
- ✅ Easier to debug and maintain
- ✅ New users understand it immediately

**Remember: The best pattern is the one your team understands and can use effectively.**