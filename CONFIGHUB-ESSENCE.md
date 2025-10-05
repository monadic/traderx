# ConfigHub in 10 Minutes: The Essence

Start simple. Add power only when needed.

---

## The Core Pattern: Two Scripts Rule Everything

```bash
./setup-structure   # Creates spaces, units, relationships
./deploy           # Makes it real in Kubernetes
```

That's it. Everything else is details.

---

## Stage 1: Hello World (2 min)

```bash
# setup-structure
cub space create app
cub unit create web --space app --data nginx.yaml

# deploy
cub worker install worker --space app --wait
cub unit apply web --space app
```

```
app/
└── web (nginx)
```

✅ **Essence**: Space contains units. Worker deploys them.

---

## Stage 2: Three Environments (3 min)

```bash
# setup-structure
for env in dev staging prod; do
  cub space create $env
  cub unit copy web --from app --to $env
done

# deploy (just prod)
cub worker install worker --space prod --wait
cub unit apply web --space prod
```

```
dev/
├── web (copied)
staging/
├── web (copied)
prod/
└── web (deployed) ✓
```

✅ **Essence**: Spaces are environments. Copy promotes config.

---

## Stage 3: Three Regions, Three Variations (5 min)

**The Power Move**: Same app, different configs per region.

```bash
# setup-structure
for region in us eu asia; do
  cub space create prod-$region
  cub unit copy web --from prod --to prod-$region
done

# Customize per region (the magic!)
cub unit update web --space prod-us --patch '{"replicas": 3}'    # Normal
cub unit update web --space prod-eu --patch '{"replicas": 5}'    # GDPR needs more
cub unit update web --space prod-asia --patch '{"replicas": 2}'  # Cost savings

# deploy all regions
for region in us eu asia; do
  cub unit apply web --space prod-$region
done
```

```
prod-us/
└── web (replicas: 3) ✓

prod-eu/
└── web (replicas: 5) ✓  # Different!

prod-asia/
└── web (replicas: 2) ✓  # Different!
```

✅ **Essence**: Each region has custom config. No templates needed.

---

## Stage 4: Push Changes, Keep Customizations

**The Killer Feature**: Update base → flows everywhere, keeps local changes.

```bash
# Create base + regions with inheritance
cub space create base
cub unit create web --space base --data nginx-v1.yaml

for region in us eu asia; do
  cub unit create web --space prod-$region \
    --upstream-unit base/web  # Magic link!
done

# Regions customize
cub unit update web --space prod-eu --patch '{"replicas": 5}'

# Update base to v2
cub unit update web --space base --data nginx-v2.yaml

# Push upgrade (preserves EU's 5 replicas!)
cub unit update --upgrade --patch --space "prod-*"
```

```
Before upgrade:
base/
└── web (v1)
    ├── prod-us/web (v1, replicas: default)
    ├── prod-eu/web (v1, replicas: 5)
    └── prod-asia/web (v1, replicas: default)

After upgrade:
base/
└── web (v2)
    ├── prod-us/web (v2, replicas: default) ✓
    ├── prod-eu/web (v2, replicas: 5) ✓     # Kept customization!
    └── prod-asia/web (v2, replicas: default) ✓
```

✅ **Essence**: Inheritance + merge. Nobody else can do this.

---

## Stage 5: Find and Fix Problems Everywhere

```bash
# Find all high-replica services across ALL regions
cub unit list --space "*" \
  --where "Data CONTAINS 'replicas: 5'"

# Output:
# prod-eu/web  (replicas: 5)

# Fix them all at once
cub run set-replicas --replicas 3 \
  --where "Data CONTAINS 'replicas: 5'" \
  --space "*"
```

✅ **Essence**: SQL queries across everything. Bulk fixes.

---

## Stage 6: Atomic Multi-Service Updates

```bash
# Must update API + DB together
cub changeset create api-v2
cub unit update api --space prod --patch '{"image": "api:v2"}'
cub unit update db --space prod --patch '{"schema": "v2"}'
cub changeset apply api-v2  # Both or neither!
```

```
Changeset: api-v2
├── api (v1 → v2)
└── db (schema v1 → v2)
Apply: ✓ Atomic!
```

✅ **Essence**: Related changes succeed or fail together.

---

## Stage 7: Emergency Bypass (Lateral Promotion)

```bash
# Normal flow: dev → staging → us → eu → asia
# But EU has critical bug!

# Fix directly in EU
cub run fix-critical --space prod-eu

# Copy fix to Asia (skip US!)
cub unit update web --space prod-asia \
  --merge-unit prod-eu/web

# Backfill US later
cub unit update web --space prod-us \
  --merge-unit prod-eu/web
```

```
Normal:   dev → staging → us → eu → asia
Emergency:                 eu → asia
                           ↓
Backfill:                  us
```

✅ **Essence**: Skip the normal flow when needed.

---

## The Complete System (30 seconds to understand)

```
Structure (setup-structure):
base/                    # Shared configs
├── web-base            # Base web config
├── api-base            # Base API config
└── db-base             # Base DB config

dev/                    # Development
├── web (→base)         # Inherits + overrides
├── api (→base)
└── db (→base)

prod-us/ (replicas: 3)  # US production
prod-eu/ (replicas: 5)  # EU production (GDPR)
prod-asia/ (replicas: 2) # Asia production (cost)

Operations (deploy):
cub worker install      # One per cluster
cub unit apply         # Deploy everything
cub unit update --upgrade --patch  # Propagate changes
```

---

## Why This Matters: The 10-Second Pitch

**Traditional Tools**:
- Change base = lose customizations
- Update regions = edit 3 files
- Find problems = grep everything
- Emergency fix = follow the process

**ConfigHub**:
- Change base = keep customizations (push-upgrade)
- Update regions = one command (WHERE)
- Find problems = SQL query
- Emergency fix = lateral promotion

---

## The Two Scripts (Complete)

### setup-structure
```bash
#!/bin/bash
# Create base
cub space create base
cub unit create web --space base --data web.yaml
cub unit create api --space base --data api.yaml

# Create regions with inheritance
for region in us eu asia; do
  cub space create prod-$region
  cub unit create web --space prod-$region --upstream-unit base/web
  cub unit create api --space prod-$region --upstream-unit base/api
done

# Regional customizations
cub unit update web --space prod-eu --patch '{"replicas": 5}'
cub unit update web --space prod-asia --patch '{"replicas": 2}'
```

### deploy
```bash
#!/bin/bash
# Install workers (once per cluster)
for region in us eu asia; do
  cub worker install worker-$region --space prod-$region --wait
done

# Deploy everything
cub unit apply --space "prod-*" --where "*"
```

---

## Learn More When You Need It

Start here. When you hit limits, add:
- **Changesets** for atomic operations
- **Triggers** for policy enforcement
- **Approvals** for production gates
- **Links** for cross-app relationships
- **Sets** for logical grouping

But not before you need them. Simplicity first.