# When to Use Each ConfigHub Pattern

After reading the global-app documentation and understanding issue #2880 (private), I now see why global-app is complex - it solves real enterprise problems. Here's when to use each pattern.

---

## 📊 Pattern Comparison

| Scenario | Simplified Pattern | Global-App Pattern |
|----------|-------------------|-------------------|
| **Single region deployment** | ✅ Perfect | ❌ Overkill |
| **Multi-region (US, EU, Asia)** | ❌ Can't handle | ✅ Designed for this |
| **Single team ownership** | ✅ Perfect | ❌ Unnecessary complexity |
| **Multiple teams (app vs platform)** | ❌ No governance model | ✅ Separate spaces for teams |
| **Simple version updates** | ✅ Just update and apply | ✅ Works but complex |
| **Merge upstream with local changes** | ❌ Can't do this | ✅ Base unit pattern |
| **Lateral promotion** | ❌ No mechanism | ✅ Built-in support |
| **Atomic multi-unit changes** | ❌ Manual coordination | ✅ Changesets |
| **Bulk operations across envs** | ❌ Script it yourself | ✅ Filters + WHERE clauses |

---

## 🎯 Use Simplified Pattern When

### You Have:
- **Single region/datacenter**
- **Single team** managing everything
- **< 10 services** to manage
- **Simple promotion flow** (dev → staging → prod)
- **No need for local customizations** per environment

### Example Projects:
- Startup MVP
- Internal tools
- Small departmental apps
- Proof of concepts
- Learning ConfigHub

### Benefits You Get:
```bash
# Super simple structure
myapp-dev/
myapp-staging/
myapp-prod/

# Dead simple operations
cub unit create app-backend --space myapp-dev backend.yaml
cub unit apply app-backend --space myapp-dev
cub unit copy app-backend --from myapp-dev --to myapp-staging
```

**Time to understand: 5 minutes**

---

## 🏢 Use Global-App Pattern When

### You Have:
- **Multi-region deployments** (US, EU, Asia, etc.)
- **Multiple teams** with different responsibilities
  - Platform team owns infrastructure
  - Regional teams own their app deployments
  - Security team owns base configs
- **Need to merge updates** from upstream (e.g., new nginx version) with local customizations
- **Complex promotion strategies**
  - Lateral promotion (bypass hierarchy)
  - Phased rollouts by region
  - Conservative deployment strategies
- **Need atomic operations** across multiple units

### Example Projects:
- Global e-commerce platform
- Multi-tenant SaaS with regional isolation
- Banking systems with strict compliance
- Enterprise apps with SOX/PCI requirements

### Advanced Features You Get:

#### 1. Multi-Region Hierarchy
```
base → QA → us-staging → us-prod
         ↘ eu-staging → eu-prod
         ↘ asia-staging → asia-prod
```

#### 2. Lateral Promotion (Bypass Hierarchy)
```bash
# Test in US staging
cub run set-env-var --env-var MODEL=v2 --space us-staging

# Promote directly to EU staging (bypass QA)
cub unit update ollama --space eu-staging \
  --merge-unit us-staging/ollama \
  --merge-base=5 --merge-end=6
```

#### 3. Base Unit Pattern (Merge Updates)
```bash
# Update nginx base with new version
cub unit update nginx-base --data new-nginx.yaml

# Merge update while keeping local customizations
cub unit update nginx --upgrade --patch
```

#### 4. Bulk Operations with Filters
```bash
# Update all backend services in staging regions
cub run set-env-var \
  --space "*" \
  --env-var FEATURE_FLAG=true \
  --where "Slug = 'backend' AND Labels.role = 'staging'"
```

#### 5. Changesets for Atomic Operations
```bash
# Lock units for atomic change
cub changeset create memory-upgrade
cub unit update --patch --changeset memory-upgrade \
  --where "Labels.critical = 'true'"
```

**Time to understand: Hours/Days (but worth it for complex scenarios)**

---

## 🔄 Migration Path

### Starting Simple → Growing Complex

Start with simplified pattern:
```bash
myapp-dev/
myapp-staging/
myapp-prod/
```

When you need multi-region, migrate to global-app:
```bash
# Keep existing as base
myapp-base/ (was myapp-dev)

# Add regional environments
myapp-us-staging/
myapp-us-prod/
myapp-eu-staging/
myapp-eu-prod/

# Set up upstream relationships
cub unit create backend --space myapp-us-staging \
  --upstream-unit myapp-base/backend
```

---

## 💡 Key Insights

### The Complexity is Justified For:
1. **Governance** - Different teams need different spaces
2. **Inheritance** - Base configs with environment-specific overrides
3. **Safety** - Lateral promotion for conservative rollouts
4. **Scale** - Bulk operations across many environments
5. **Atomicity** - Changesets for multi-unit operations

### The Simplicity is Better For:
1. **Speed** - Get running in minutes
2. **Learning** - Understand ConfigHub quickly
3. **Debugging** - Everything is explicit
4. **Small teams** - Less cognitive overhead
5. **Single region** - No need for complex hierarchy

---

## 📝 Recommendations

### For ConfigHub Documentation
```markdown
## Quick Start (Simplified Pattern)
Perfect for: Single-region apps, small teams, learning ConfigHub
→ Use this if you're getting started

## Enterprise Pattern (Global-App)
Perfect for: Multi-region, multi-team, complex governance
→ Use this when you need the advanced features
```

### For TraderX
TraderX is a **single-region, learning example**, so the simplified pattern is perfect:
- 8 services, but single region
- No multi-team governance needed
- No lateral promotion needed
- No upstream merging needed

**Verdict: TraderX should use simplified pattern**

### For Real Enterprise Apps
If you're building a real multi-region app:
- Start with global-app pattern from day 1
- The complexity pays off immediately
- You'll need those features soon anyway

---

## 🏆 Conclusion

**Both patterns are valid!**

- **Simplified**: Perfect for 80% of use cases
- **Global-app**: Essential for the 20% that need it

The key is knowing which problems you're solving:
- **Simple problems → Simple patterns**
- **Complex problems → Complex patterns**

Don't use a sledgehammer to crack a nut, but don't use a nutcracker on a boulder either!