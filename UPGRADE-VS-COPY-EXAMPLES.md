# Upgrade vs Copy: Real Examples

Concrete examples showing when to use ConfigHub's upgrade feature vs simple copy operations.

---

## 🎬 Scenario 1: Your Application Code

You're updating your backend from v1.0 to v1.1.

### ❌ Overkill: Using Upgrades
```bash
# Global-app style with unnecessary complexity
backend-base (v1.0)
├── backend-qa (v1.0)
│   ├── backend-staging (v1.0)
│   └── backend-prod (v1.0)

# Update base
cub run set-image --version v1.1 --space base

# Cascade through 3 upgrades
cub unit update --patch --upgrade --space qa
cub unit update --patch --upgrade --space staging
cub unit update --patch --upgrade --space prod
```

### ✅ Better: Direct Copy
```bash
# Simple and explicit
myapp-dev/backend (v1.1)
myapp-staging/backend (v1.0)
myapp-prod/backend (v1.0)

# Test in dev
cub run set-image --version v1.1 --space myapp-dev
# ... test thoroughly ...

# Copy to staging when ready
cub unit copy backend --from myapp-dev --to myapp-staging
# ... test in staging ...

# Copy to prod when ready
cub unit copy backend --from myapp-staging --to myapp-prod
```

**Why copy is better here:**
- You control exactly when each environment updates
- No accidental cascade if someone runs upgrade
- Clear audit trail of who copied when
- Your backend has no "local customizations" to preserve

---

## 🎬 Scenario 2: Nginx Ingress Controller

You need to update nginx-ingress from 1.9 to 1.10, but you have custom headers and rate limiting.

### ❌ Pain: Manual Merge with Copy
```bash
# You have customizations
myapp-dev/nginx:
  - Custom headers: X-Company-Auth
  - Rate limiting: 100 req/sec
  - Custom error pages
  - CORS settings

# Vendor releases 1.10 with security fixes
# Download new version
curl -O https://nginx.org/nginx-1.10.yaml

# Now you have to:
# 1. Diff the versions to see what changed
# 2. Manually merge your customizations
# 3. Test that nothing broke
# 4. Repeat for EVERY environment

# This is error-prone and time-consuming!
```

### ✅ Better: Using Variants & Upgrade
```bash
# Setup (one time)
nginx-base: Stock nginx 1.9 from vendor
└── nginx: Your customized version

# When 1.10 comes out
# 1. Update base with vendor's new version
cub unit update nginx-base --space myapp-bases nginx-1.10.yaml

# 2. Review what changed
cub unit diff nginx-base --space myapp-bases --from HEAD~1

# 3. Merge upgrade (preserves your customizations!)
cub unit update nginx --space myapp-dev --upgrade --patch

# Your custom headers, rate limits, etc. are preserved!
# The security fixes from 1.10 are merged in!
```

**Why upgrade is better here:**
- Automatic merge of vendor updates
- Preserves your customizations
- See exactly what vendor changed
- Reusable across all environments

---

## 🎬 Scenario 3: Environment-Specific Settings

Your backend needs different database URLs per environment.

### ❌ Overkill: Using Variants
```bash
backend-base:
  DATABASE_URL: "postgres://localhost/dev"
├── backend-staging:
│     DATABASE_URL: "postgres://staging.db/app"  # Override
└── backend-prod:
      DATABASE_URL: "postgres://prod.db/app"     # Override

# This is too complex for a simple env var!
```

### ✅ Better: Direct Configuration
```bash
# Each environment has its own complete config
myapp-dev/backend:
  DATABASE_URL: "postgres://localhost/dev"

myapp-staging/backend:
  DATABASE_URL: "postgres://staging.db/app"

myapp-prod/backend:
  DATABASE_URL: "postgres://prod.db/app"

# When updating app version, copy everything except env-specific
cub unit get backend --space myapp-dev > /tmp/backend.yaml
# Edit to change DATABASE_URL for staging
cub unit update backend --space myapp-staging /tmp/backend.yaml
```

**Or even better: Use ConfigMaps/Secrets for env-specific config!**

---

## 📋 Decision Matrix

| What's Changing? | Who Owns It? | Local Customizations? | Use Upgrade? | Use Copy? |
|-----------------|--------------|----------------------|-------------|-----------|
| Your app code | You | No | ❌ | ✅ |
| Your app code | You | Yes (why?) | Maybe | Maybe |
| External tool | Vendor | No | ❌ | ✅ |
| External tool | Vendor | Yes | ✅ | ❌ |
| Platform config | Platform team | No | ❌ | ✅ |
| Platform config | Platform team | Yes | ✅ | ❌ |
| Env variables | You | N/A | ❌ | ❌ |

---

## 🏆 Real World Examples

### Use COPY For:
- ✅ Deploying your microservices
- ✅ Updating your frontend
- ✅ Changing your API endpoints
- ✅ Updating your business logic
- ✅ Rolling out feature flags

### Use UPGRADE For:
- ✅ Nginx/Istio/Envoy updates with custom config
- ✅ Prometheus rules with team additions
- ✅ Grafana dashboards with custom panels
- ✅ Base Docker images with company certificates
- ✅ Kubernetes operators with custom resources

---

## 💡 The Key Question

**"Do I need to merge vendor/platform updates while preserving my customizations?"**

- **Yes** → Use variants and upgrades
- **No** → Use simple copy

---

## 🚀 Practical TraderX Decision

```yaml
# TraderX services - USE COPY (you own these)
app-reference-data: COPY
app-trade-service: COPY
app-web-gui: COPY
app-people-service: COPY

# Infrastructure - DEPENDS
namespace: COPY (no customization needed)
service-account: COPY (simple)
ingress:
  - If using stock ingress: COPY
  - If customizing vendor ingress: UPGRADE
```

---

## 📝 Implementation Guide

### Setting up selective variants (only where needed):

```bash
# 1. Most units are simple (no variants)
cub unit create app-backend --space myapp-dev backend.yaml
cub unit create app-frontend --space myapp-dev frontend.yaml

# 2. Create bases space for external configs only
cub space create myapp-bases

# 3. Add base for things you customize but don't own
cub unit create nginx-base --space myapp-bases \
  vendor-nginx-1.9.yaml

# 4. Create variant with your customizations
cub unit create infra-nginx --space myapp-dev \
  --upstream-unit myapp-bases/nginx-base

# 5. Add your customizations
cub run add-custom-headers --space myapp-dev --unit infra-nginx

# Now you can upgrade nginx while keeping customizations!
cub unit update nginx-base --space myapp-bases vendor-nginx-1.10.yaml
cub unit update infra-nginx --space myapp-dev --upgrade --patch
```

---

## 🎯 Final Wisdom

**Start with COPY. Add UPGRADE only when you feel the pain of manual merging.**

Most teams never need variants/upgrades for their own code. They're invaluable for customized external dependencies. Don't add complexity until you need it!