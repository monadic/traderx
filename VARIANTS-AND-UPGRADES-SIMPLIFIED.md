# Variants and Upgrades in the Simplified Pattern

Let's talk about how ConfigHub's powerful variant/upgrade features work in the simplified 80% use case.

---

## 🎯 Core Concepts

### What are Variants?
In ConfigHub, a "variant" is essentially a unit that has an **upstream unit** - it inherits from a base configuration and can have local customizations.

```bash
# Creating a variant (global-app pattern)
cub unit create nginx --upstream-unit nginx-base
```

### What are Upgrades?
"Upgrades" push changes from upstream units to their downstream variants, merging changes while preserving local customizations.

```bash
# Push changes downstream (global-app pattern)
cub unit update --patch --upgrade --space qa-staging
```

---

## 🤔 Do You Need Variants/Upgrades in Simple Cases?

### Short Answer: **Usually No**

For the 80% simplified pattern, you probably **DON'T need** variants and upgrades because:

1. **Single region = No variants needed**
   - You're not customizing nginx for US vs EU vs Asia
   - One configuration works everywhere

2. **Simple promotion = Direct copy**
   - Just copy the exact config from dev → staging → prod
   - No need to merge changes

3. **No local customizations per environment**
   - Your backend in staging is identical to prod (except maybe replicas)
   - No need for inheritance chains

---

## 📊 Comparison: With and Without Variants

### Scenario 1: Update Application Version

**Global-App (with variants):**
```bash
# Update base
cub run set-image-version --version 1.2.0 --space base

# Upgrade propagates through chain
cub unit update --patch --upgrade --space qa        # base → qa
cub unit update --patch --upgrade --space staging   # qa → staging
cub unit update --patch --upgrade --space prod      # staging → prod
```

**Simplified (no variants):**
```bash
# Update dev directly
cub run set-image-version --version 1.2.0 --space myapp-dev

# Explicit copy when ready
cub unit copy app-backend --from myapp-dev --to myapp-staging
cub unit copy app-backend --from myapp-staging --to myapp-prod
```

**Winner for simple case: Simplified** ✅
- More explicit and controlled
- No surprise propagations
- Clear audit trail

---

### Scenario 2: Update Nginx Version (Infrastructure)

**Global-App (with variants):**
```bash
# Update nginx-base with new version
cub unit update nginx-base --data new-nginx-2.0.yaml

# Merge upgrade preserves local customizations
cub unit update nginx --upgrade --patch  # Keeps your custom headers!
```

**Simplified (no variants):**
```bash
# Manual merge required
curl -O https://nginx.org/nginx-2.0.yaml
# Edit manually to add your customizations
vi nginx-2.0.yaml  # Add custom headers back
cub unit update infra-nginx --space myapp-dev nginx-2.0.yaml
```

**Winner for infrastructure updates: Global-App** ✅
- Automatic merge of upstream changes
- Preserves local customizations
- Less error-prone

---

## 💡 When Variants Make Sense (Even in Simple Cases)

### 1. External Dependencies You Don't Control

If you use external configs (nginx, prometheus, grafana dashboards), variants help:

```bash
# This makes sense even in simplified pattern
nginx-base (upstream nginx config from vendor)
└── nginx (your customized version)

# When vendor updates, you can merge
cub unit update nginx --upgrade --patch
```

### 2. Shared Base Configs Across Teams

Even in single region, if multiple teams share configs:

```bash
company-logging-base (platform team owns)
└── myapp-logging (your customizations)
```

### 3. Compliance/Security Templates

When security team provides base configs:

```bash
security-baseline-deployment (security team)
└── myapp-backend-deployment (your app)
```

---

## 🛠️ Hybrid Approach: Selective Variants

**Use variants ONLY where they add value:**

```bash
# Simplified structure with selective variants
myapp-dev/
├── namespace                 # Simple unit (no variant needed)
├── service-account          # Simple unit
├── app-backend              # Simple unit (you control this)
├── app-frontend             # Simple unit
├── infra-nginx              # VARIANT of nginx-base
└── infra-prometheus         # VARIANT of prometheus-base

# Create base units for external configs only
myapp-bases/
├── nginx-base               # Upstream nginx configs
└── prometheus-base          # Upstream prometheus configs
```

**Setup:**
```bash
# Create bases space for external configs
cub space create myapp-bases

# Import external configs
cub unit create nginx-base --space myapp-bases nginx-ingress-v1.2.yaml
cub unit create prometheus-base --space myapp-bases prometheus-v2.45.yaml

# Create variants in your dev space
cub unit create infra-nginx --space myapp-dev \
  --upstream-unit myapp-bases/nginx-base

cub unit create infra-prometheus --space myapp-dev \
  --upstream-unit myapp-bases/prometheus-base
```

**Benefits:**
- ✅ Simple for your code
- ✅ Variants for external dependencies
- ✅ Best of both worlds

---

## 📈 Migration Path

### Start without variants:
```bash
myapp-dev/
├── app-backend
├── app-frontend
└── infra-nginx
```

### Add variants later when needed:
```bash
# When nginx 2.0 comes out and you need to merge updates
cub space create myapp-bases
cub unit create nginx-base --space myapp-bases nginx-2.0.yaml

# Convert existing to variant
cub unit delete infra-nginx --space myapp-dev
cub unit create infra-nginx --space myapp-dev \
  --upstream-unit myapp-bases/nginx-base \
  --data your-customizations.yaml
```

---

## 🎯 Recommendations for the 80% Case

### Default: No Variants
Start simple. Don't use variants/upgrades unless you have a specific need.

### Consider Variants For:
- [ ] External configs (nginx, istio, prometheus)
- [ ] Shared platform configs
- [ ] Security/compliance baselines
- [ ] Multi-team shared resources

### Keep Simple For:
- [x] Your application code
- [x] Your custom services
- [x] Environment-specific configs
- [x] Simple infrastructure

---

## 🔑 Key Insight

**Variants and upgrades are powerful but not always necessary.**

In the simplified 80% case:
- **Your code**: Direct management (no variants)
- **External dependencies**: Consider variants for easier updates
- **Promotion**: Explicit copy is clearer than upgrade chains

The power of ConfigHub is that you can start simple and add variants later when you discover you need them. You're not locked into either approach!

---

## 📝 Practical Example for TraderX

```bash
# TraderX simplified - NO variants needed
traderx-dev/
├── namespace
├── service-account
├── app-reference-data    # Your code - no variant
├── app-trade-service     # Your code - no variant
├── app-web-gui          # Your code - no variant
└── infra-ingress        # Could be a variant if using nginx-ingress

# Only if using external nginx-ingress:
traderx-bases/
└── nginx-ingress-base   # Upstream from nginx project
```

**Verdict**: TraderX doesn't need variants for its core services. Maybe for nginx if using external nginx-ingress controller.

---

## 🏁 Conclusion

For the 80% simplified case:
1. **Start without variants** - Keep it simple
2. **Use explicit copy** for promotion - More control
3. **Add variants selectively** - Only for external dependencies
4. **Don't over-engineer** - You can always add complexity later

Remember: The goal is to get your app deployed, not to use every ConfigHub feature!