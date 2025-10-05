# ConfigHub's Killer Features

These are the powerful capabilities that are genuinely hard (or impossible) to replicate without ConfigHub. All features listed here are CONFIRMED to exist in the ConfigHub source code.

---

## 🚀 1. Push-Upgrade Through Inheritance Chains

### The Power
Change once at the base, propagate everywhere through UpstreamUnitID relationships while preserving local customizations.

### Real Example (Confirmed)
```bash
# You have 50 microservices inheriting from a base config
# Security team updates TLS settings in base

# Update the base unit
cub unit update tls-base --space base --data new-tls-config.yaml

# Push changes to all downstream units (preserves customizations!)
cub unit update --patch --upgrade --space "*"
```

### Why It's Hard Without ConfigHub
- Helm: Can't preserve local overrides during upgrades
- Kustomize: No propagation mechanism
- GitOps: Would need 500 PRs
- Scripts: Complex custom merge logic needed

**Source:** Confirmed in `unit_push_upgrade.go` and global-app example

---

## 🎯 2. Bulk Operations with WHERE Clauses

### The Power
Target arbitrary sets of units across all spaces using SQL-like filters.

### Real Example (Confirmed)
```bash
# Create a filter to target specific units
cub filter create java-prod Unit \
  --where-field "Labels.runtime = 'java' AND Labels.env = 'prod'"

# Bulk update memory for all matching units
cub run set-memory --memory 4Gi --filter myproject/java-prod --space "*"

# Or use WHERE directly in some commands
cub unit list --where "Labels.team = 'platform'" --space "*"
```

### Why It's Hard Without ConfigHub
- Kubectl: Can only filter running resources, not configs
- Helm: Would need custom scripts per chart
- Terraform: No cross-workspace queries
- GitOps: Manual grep and edit

**Source:** Confirmed in `internal/models/filter.go` with WhereData field

---

## 🔄 3. Lateral Promotion (Bypass Hierarchy)

### The Power
Promote changes directly between environments, skipping the normal promotion flow.

### Real Example (Confirmed)
```bash
# Normal flow: dev → staging → prod-us → prod-eu
# But EU needs urgent fix from US without waiting for staging

# Promote directly from prod-us to prod-eu (skip staging)
cub unit update service --space prod-eu \
  --merge-unit prod-us/service \
  --merge-base=10 --merge-end=11
```

### Why It's Hard Without ConfigHub
- GitOps: Locked to branch strategy
- Helm: No lateral relationships
- Kustomize: Would break overlay hierarchy

**Source:** Confirmed in global-app lateral promotion example

---

## 🔒 4. Changesets for Atomic Operations

### The Power
Group multiple units for atomic changes - all succeed or all fail together.

### Real Example (Confirmed)
```bash
# Create changeset for coordinated update
cub changeset create api-v2-migration

# Associate units with changeset
cub changeset associate-unit api-v2-migration api-service database-schema cache-config

# Make changes (locked together)
cub run update-schema --changeset api-v2-migration
cub run update-api --changeset api-v2-migration

# Apply atomically
cub changeset apply api-v2-migration  # All or nothing!
```

### Why It's Hard Without ConfigHub
- No other tool has changesets
- Would need distributed locking
- GitOps: Can't guarantee atomic deployment

**Source:** Confirmed in ConfigHub API and global-app examples

---

## ⏰ 5. Unit-Level Revision History

### The Power
Every unit change is versioned with full history, diff, and rollback capabilities.

### Real Example (Confirmed)
```bash
# List revisions for a unit
cub revision list api-service --space prod

# See what changed between revisions
cub unit diff api-service --space prod --from=45 --to=46

# Rollback to specific revision
cub unit apply api-service --space prod --revision=45

# Rollback entire changeset
cub changeset rollback api-v2-migration
```

### Why It's Hard Without ConfigHub
- Git: Has history but can't rollback deployed resources
- Helm: Rollback is per-release, not per-component
- Flux/Argo: Rollback requires new commit

**Source:** Confirmed - revision operations exist in CLI

---

## 🎹 6. ConfigHub Functions (cub run)

### The Power
Pre-built, tested operations that work on any Kubernetes manifest structure.

### Real Examples (Confirmed from global-app)
```bash
# These 5 functions are CONFIRMED in global-app:
cub run set-image-version --version 1.2.0 --space dev
cub run set-env-var --env-var FEATURE_FLAG=true --space prod
cub run set-resource --cpu 2000m --memory 4Gi --space staging
cub run set-hostname --hostname api.example.com --space prod
cub run set-yaml-path --path spec.replicas --value 5 --space dev

# Work across multiple units with filters
cub run set-image-version --version 2.0 --filter myapp/backend --space "*"
```

### Why It's Hard Without ConfigHub
- Every team writes fragile jq/yq scripts
- Scripts break when YAML structure changes
- No standardization across teams

**Source:** Confirmed in global-app `bin/test-functions`

---

## 🏢 7. Multi-Space Governance with Teams

### The Power
Different teams own different spaces with controlled inheritance and propagation.

### Real Example (Confirmed)
```bash
# Platform team owns base configurations
platform-base/
  ├── monitoring-base
  └── logging-base

# App teams inherit but customize
team-alpha-prod/ (Alpha team controls)
  ├── monitoring (upstream: platform-base/monitoring-base)
  └── app-service

team-beta-prod/ (Beta team controls)
  ├── monitoring (upstream: platform-base/monitoring-base)
  └── app-service

# Platform updates base, teams pull when ready
cub unit update monitoring-base --space platform-base --data security-fix.yaml
cub unit update monitoring --space team-alpha-prod --upgrade --patch
```

### Why It's Hard Without ConfigHub
- GitOps: Complex repo permissions
- Helm: No inheritance model
- Terraform: Workspace isolation

**Source:** Confirmed - spaces and upstream relationships are core features

---

## 📦 8. Sets for Logical Grouping

### The Power
Group related units across spaces for coordinated operations.

### Real Example (Confirmed)
```bash
# Create a set for critical services
cub set create critical-services

# Add units to the set
cub set add-unit critical-services payment-api auth-service database

# Operate on the entire set
cub filter create critical Unit --where-field "SetID = 'critical-services'"
cub unit apply --filter myapp/critical --space "*"
```

### Why It's Hard Without ConfigHub
- Would need external tagging system
- No native grouping in other tools
- Manual tracking of relationships

**Source:** Confirmed in `internal/models/set.go`

---

## ⚡ 9. Triggers for Policy Enforcement

### The Power
Automated policy validation and enforcement using triggers that run on mutations and clones.

### Real Examples (Confirmed)
```bash
# Require approval before any changes can be applied
cub trigger create require-approval Mutation Kubernetes/YAML \
  vet-approvedby 1  # Requires 1 approval

# Enforce resource limits policy
cub trigger create resource-limits Mutation Kubernetes/YAML \
  vet-celexpr 'r.kind != "Deployment" || r.spec.replicas < 20'

# Prevent placeholder leaks to production
cub trigger create no-placeholders Mutation Kubernetes/YAML \
  vet-placeholders  # Blocks resources with {{ placeholders }}

# Ensure compliance annotations
cub trigger create compliance-check Mutation Kubernetes/YAML \
  ensure-context true  # Forces context annotations

# Bulk create triggers across environments
cub trigger create --where "Event = 'Mutation'" \
  --name-prefix prod- --dest-space prod-*
```

### Why It's Hard Without ConfigHub
- Need separate admission controllers
- Complex OPA policies
- No unified enforcement across environments
- Can't enforce on config changes (only on deployment)

**Source:** Confirmed in `trigger_create.go`, supports CEL expressions and approval gates

---

## ✅ 10. Approval Workflows

### The Power
Built-in approval mechanism for changes before they can be applied, with revision-specific approvals.

### Real Examples (Confirmed)
```bash
# Approve a specific unit
cub unit approve my-service

# Approve a specific revision
cub unit approve my-service --revision 45

# Approve the currently live revision
cub unit approve my-service --revision LiveRevisionNum

# Approve a tagged version
cub unit approve my-service --revision Tag:release-v1.0

# Bulk approve matching units
cub unit approve --where "Labels.tier = 'backend'" --space "*"

# Approve all units in a changeset
cub unit approve --where "ChangeSetID = 'api-v2-migration'"

# Combine with triggers to enforce approvals
cub trigger create require-approval Mutation Kubernetes/YAML \
  vet-approvedby 1  # Won't apply without approval
```

### Why It's Hard Without ConfigHub
- Need separate approval systems (ServiceNow, etc.)
- No native integration with config changes
- Can't track approval state per revision
- Manual approval tracking

**Source:** Confirmed in `unit_approve.go` with revision-specific approval support

---

## 💡 The Bottom Line

### Truly Unique to ConfigHub:
1. **Push-upgrade with customization preservation** - Nobody else does this
2. **Changesets** - Atomic multi-unit operations
3. **Lateral promotion** - Bypass hierarchy when needed
4. **Approval workflows** - Built-in revision-specific approvals
5. **Policy triggers** - CEL-based validation and enforcement

### Very Hard to Replicate:
1. **WHERE clause filtering** - SQL-like queries across configs
2. **Unit revision history** - Per-component versioning
3. **ConfigHub Functions** - Standardized operations
4. **Multi-space governance** - Team-based inheritance
5. **Sets for grouping** - Logical unit collections

### Built-in Compliance & Audit:
- **Mutation tracking** - Complete audit trail of all changes (`cub mutation list`)
- **Invocations** - Reusable policy definitions
- **Triggers** - Automated enforcement on every change
- **Approvals** - Revision-specific approval tracking

### The Killer Combo:
It's not just individual features - it's how they work together. The combination of inheritance, bulk operations, atomic changes, and revision history in one unified API is ConfigHub's competitive moat.

---

## 🚀 What This Means for You

### Use ConfigHub When You Have:
- Multi-region deployments with local customizations
- Multiple teams needing controlled autonomy
- Complex promotion requirements (lateral, conditional)
- Need for atomic multi-service updates
- Bulk operations across many environments

### ConfigHub Might Be Overkill For:
- Simple single-region apps
- Single team, single namespace
- No customization requirements
- Static configurations

**The value of ConfigHub scales with complexity.** The more complex your deployment topology, the more these features become essential rather than nice-to-have.