# ConfigHub CLI (cub) Testing Strategy

## Overview

The **cub Command Analyzer** is a comprehensive validation tool for ConfigHub `cub` CLI commands. It scans scripts/folders/URLs containing cub operations and provides per-file, per-command analysis including:

1. **Syntax validation** - Command structure correctness
2. **Grammar validation** - WHERE clause EBNF compliance
3. **Unit test compliance** - Follows standard patterns
4. **Semantic explanation** - English description with pre/post conditions

This is a **general-purpose tool** that can be used with any ConfigHub project and will eventually be moved to devops-sdk.

## Motivation

Based on feedback from Brian Grant (ConfigHub maintainer), several common errors occur in cub command usage:

1. **Syntax errors**: Using `--patch` without required companion flags
2. **Positional argument errors**: Passing inline JSON as `'{"spec":{"replicas":3}}'` where unit slug expected
3. **WHERE clause errors**: Using unsupported operators like `CONTAINS` or attempting to query Data fields
4. **Wildcard errors**: Using `*` in invalid contexts

**Brian's key insight:**
> "You're passing that data patch (which isn't a thing you can pass to update) as the unit slug. And there's no specification of what to update."

The analyzer prevents these errors by validating commands before execution.

## Architecture

```
cub-command-analyzer.sh              # Main analyzer tool
test/lib/cub-test-framework.sh       # Validation functions
test/strategies/cub-tests.md         # This document
```

## Understanding Unit Data vs Metadata

**CRITICAL CONCEPT** (from Brian's feedback):

ConfigHub Units have two distinct parts:

### 1. METADATA
Unit-level fields: `Slug`, `Labels`, `Annotations`, `Description`, `UpstreamUnitID`, etc.

**How to update metadata:**
```bash
# ✅ Update labels
cub unit update myunit --patch --label version=2.0 --space dev

# ✅ Push-upgrade (propagate metadata changes)
cub unit update --patch --upgrade --space staging
```

### 2. DATA
The actual config content (YAML/JSON/HCL/etc.) stored as an **opaque blob**.

**How to update Data - Monolithic (replace entire blob):**
```bash
# ✅ Replace from file
cub unit update myunit myfile.yaml --space dev

# ✅ Pipe via stdin
echo '{"spec":{"replicas":3}}' | cub unit update myunit --from-stdin --space dev

# ✅ Use filename flag
cub unit update myunit --filename newdata.yaml --space dev
```

**How to update Data - Fine-Grained (specific fields):**
```bash
# ✅ Use functions for granular changes
cub function do --space dev --where "Slug = 'myunit'" set-replicas 3
cub function do --space dev set-image nginx nginx:1.21
cub function do --space dev yq '.spec.replicas = 3'
```

### INVALID Patterns

```bash
# ❌ WRONG - Inline JSON as positional argument
cub unit update --patch '{"spec":{"replicas":3}}'
# Brian: "You're passing that data patch as the unit slug"

# ❌ WRONG - --patch without required companion flags
cub unit update --patch
# Needs: --from-stdin, --filename, --restore, --upgrade, --merge-source,
#        --label, --delete-gate, --destroy-gate, or --changeset

# ❌ WRONG - Query Data fields in WHERE clause
cub unit list --space dev --where "Data.spec.replicas > 2"
# Data is opaque - WHERE clauses can't query contents
```

## Usage

### Analyze Single File
```bash
./cub-command-analyzer.sh bin/install-base
```

### Analyze Directory
```bash
./cub-command-analyzer.sh bin/
./cub-command-analyzer.sh /Users/alexis/traderx/bin/
```

### Analyze Entire Project
```bash
# TraderX
./cub-command-analyzer.sh /Users/alexis/traderx/bin/

# MicroTraderX
./cub-command-analyzer.sh /path/to/microtraderx/
```

## Output Format

For each cub command found, the analyzer outputs:

```
FILE: bin/install-base
LINE 10: cub space create myspace --label app=test

SYNTAX VALIDATION:
  ✓ Valid

GRAMMAR VALIDATION:
  ⊘ No WHERE clause (N/A)

COMMON ERRORS CHECK:
  ✓ No common errors detected

SEMANTIC EXPLANATION:
  📝 Creates a new ConfigHub space named 'myspace'
    Pre-condition: Space 'myspace' does not exist
    Post-condition: Space 'myspace' exists and is accessible

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Example: Invalid Command

```
FILE: bin/bulk-update
LINE 62: cub unit update --space dev --patch '{"spec":{"replicas":3}}'

SYNTAX VALIDATION:
  ✗ Invalid
    Error: Cannot pass inline JSON with --patch. Use --from-stdin (with pipe/heredoc)
           or --filename. For fine-grained Data changes, use 'cub function do' instead

GRAMMAR VALIDATION:
  ⊘ No WHERE clause (N/A)

COMMON ERRORS CHECK:
  ⚠ Common errors found:
    - Inline JSON with --patch is invalid. Use --from-stdin (with pipe) or use
      'cub function do' for fine-grained changes

  💡 CORRECTION:
    For monolithic Data update:
      echo '{...}' | cub unit update <unit> --from-stdin --space <space>
    For fine-grained Data update:
      cub function do --space <space> --where "Slug = '<unit>'" set-replicas 3

SEMANTIC EXPLANATION:
  📝 INTENDED to update replicas to 3
    CORRECT: cub function do --space dev --where "Slug = 'myunit'" set-replicas 3

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Summary Output

```
══════════════════════════════════════════════════════════════
ANALYSIS SUMMARY
══════════════════════════════════════════════════════════════
Files analyzed:       15
Commands found:       142
Valid commands:       138
Invalid commands:     4
══════════════════════════════════════════════════════════════

⚠ Found 4 invalid command(s). See details above.
```

## Validation Framework

The analyzer uses `test/lib/cub-test-framework.sh` which provides:

### Syntax Validation
- Command structure (entity + verb)
- Required flags and combinations
- Invalid patterns (inline JSON, missing companions)

### Grammar Validation
- WHERE clause EBNF compliance
- Valid operators: `=`, `!=`, `<`, `>`, `<=`, `>=`, `LIKE`, `ILIKE`, `IN`, `NOT IN`, `?`
- Valid attributes: `Slug`, `Labels.key`, `Space.Labels.key`, `CreatedAt`, `UpdatedAt`
- String literals must use single quotes
- Conjunctions: AND only (OR not supported)
- Array operations: `?` (contains), `LEN()` (length)

### Common Error Detection
Catches 7 common mistake patterns:
1. `--patch` without required flags
2. Inline JSON as positional argument
3. Wildcards in invalid contexts
4. `CONTAINS` operator (not supported)
5. Data field queries (Data is opaque)
6. Double quotes for string literals (should be single)
7. Missing required `--space` flag

### Semantic Explanation
For each command, generates:
- **English description** of what the operation does
- **Pre-condition**: Required state before operation
- **Post-condition**: Expected state after operation

## WHERE Clause Grammar Rules

From `CONFIGHUB_AGENT=1 cub --help-overview`:

### Valid Operators
- Comparison: `<`, `>`, `<=`, `>=`, `=`, `!=`
- String patterns: `LIKE`, `ILIKE` (case-insensitive), `~~`, `!~~`
- Regex: `~`, `~*` (case-insensitive), `!~`, `!~*`
- Lists: `IN`, `NOT IN`
- Arrays: `?` (contains element)

### Valid Attributes
- `Slug`, `DisplayName`, `CreatedAt`, `UpdatedAt`
- `Labels.key` (dot notation for label access)
- `Space.Labels.key` (space label access)
- `ApprovedBy`, `Tags` (arrays)
- `ApplyGates.slug/function` (map access)

### Valid Literals
- Strings: `'value'` (single quotes only)
- Integers: `42`, `100`
- Booleans: `true`, `false`
- Timestamps: `'2025-01-01T00:00:00'`
- UUIDs: `'7c61626f-ddbe-41af-93f6-b69f4ab6d308'`

### Conjunctions
- `AND` supported (multiple conditions)
- `OR` **NOT** supported

### Array Operations
```bash
# Contains element
ApprovedBy ? '7c61626f-ddbe-41af-93f6-b69f4ab6d308'

# Array length
LEN(ApprovedBy) > 0
```

### Examples

**Valid:**
```bash
--where "Slug = 'myunit'"
--where "Labels.type = 'app'"
--where "Slug = 'backend' AND Labels.env = 'prod'"
--where "Slug LIKE 'app-%'"
--where "Slug IN ('unit1', 'unit2', 'unit3')"
--where "CreatedAt >= '2025-01-01T00:00:00'"
```

**Invalid:**
```bash
--where "Slug = \"myunit\""           # Double quotes
--where "Slug = '*'"                  # Wildcard as value
--where "Data CONTAINS 'replicas'"    # CONTAINS not supported
--where "Data.spec.replicas > 2"      # Can't query Data fields
--where "Slug = 'a' OR Slug = 'b'"    # OR not supported
```

## Common Patterns (Correct Usage)

### Space Operations
```bash
# Create with unique prefix (canonical)
prefix=$(cub space new-prefix)
cub space create ${prefix}-myspace --label project=$prefix

# List spaces
cub space list --json
```

### Unit Operations

**Create:**
```bash
# From file
cub unit create myunit config.yaml --space dev

# With upstream (clone)
cub unit create myunit --space dev \
  --upstream-unit base-unit --upstream-space base

# Bulk clone with filter
cub unit create --dest-space qa --space base \
  --filter myproject/app --label targetable=true
```

**Update Metadata:**
```bash
# Labels
cub unit update --patch --label version=2.0 --space dev

# Push-upgrade
cub unit update --patch --upgrade --space staging
```

**Update Data (Monolithic):**
```bash
# From file
cub unit update myunit newdata.yaml --space dev

# From stdin
echo '{"spec":{"replicas":3}}' | \
  cub unit update myunit --from-stdin --space dev
```

**Update Data (Fine-Grained):**
```bash
# Set replicas (CORRECT way)
cub function do --space dev \
  --where "Slug = 'myunit'" set-replicas 3

# Set image
cub function do --space dev set-image nginx nginx:1.21

# Custom yq
cub function do --space dev yq '.spec.replicas = 5'
```

**Apply:**
```bash
# Single unit
cub unit apply myunit --space dev

# With filter
cub unit apply --space dev \
  --where "Labels.layer = 'backend'"

# With wait
cub unit apply --space dev --wait
```

### Filter Operations
```bash
# Create filter
cub filter create all Unit \
  --where-field "Space.Labels.project = 'myproject'" \
  --space filters

# Use filter in queries
cub unit list --space dev --filter myproject/all
```

### Function Operations
```bash
# Set replicas (instead of patching Data)
cub function do --space dev \
  --where "Slug = 'backend'" set-replicas 3

# List available functions
cub function list

# Get function help
cub function explain --toolchain Kubernetes/YAML set-replicas
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Validate cub Commands

on: [push, pull_request]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Analyze cub commands
        run: |
          ./cub-command-analyzer.sh bin/
      - name: Check for invalid commands
        run: |
          if [ $? -ne 0 ]; then
            echo "Found invalid cub commands"
            exit 1
          fi
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Analyzing cub commands..."
./cub-command-analyzer.sh bin/

if [ $? -ne 0 ]; then
    echo "❌ Found invalid cub commands. Commit aborted."
    exit 1
fi

echo "✅ All cub commands valid"
exit 0
```

## Development Workflow

### Before Committing
```bash
# Analyze your changes
./cub-command-analyzer.sh bin/my-new-script.sh

# Fix any issues found
# Re-analyze
./cub-command-analyzer.sh bin/my-new-script.sh
```

### During Code Review
```bash
# Analyze entire project
./cub-command-analyzer.sh bin/

# Generate report for reviewer
./cub-command-analyzer.sh bin/ > cub-analysis-report.txt
```

### Migration to SDK

This tool is designed to be general-purpose and will be moved to `devops-sdk`:

**Migration plan:**
1. Move `cub-command-analyzer.sh` to `devops-sdk/bin/`
2. Move `cub-test-framework.sh` to `devops-sdk/test/lib/`
3. Create SDK-level tests
4. Update projects to use SDK version
5. Maintain project-specific customizations in project repos

## Limitations

1. **Multiline commands**: Analyzer handles backslash continuations but complex heredocs may not parse correctly
2. **Variable expansion**: Does not expand shell variables (e.g., `$SPACE` shown as-is)
3. **Conditional logic**: Analyzes all cub commands regardless of if/then/case logic
4. **URL support**: Not yet implemented (future enhancement)

## Troubleshooting

### Analyzer Not Finding Commands
```bash
# Enable debug mode
CUB_TEST_DEBUG=true ./cub-command-analyzer.sh bin/my-script.sh
```

### False Positives
If analyzer incorrectly flags a valid command:
1. Check if command follows documented patterns
2. Verify with `cub <entity> <verb> --help`
3. Report issue with example command

### False Negatives
If analyzer misses an invalid command:
1. Add test case to `cub-test-framework.sh`
2. Update validation logic
3. Re-run analysis

## Resources

### Documentation
- **ConfigHub CLI Help**: `CONFIGHUB_AGENT=1 cub --help-overview`
- **Command Help**: `cub <entity> <verb> --help`
- **WHERE Grammar**: Included in `--help-overview` (EBNF)

### Examples
- **Global-app**: `/Users/alexis/Public/github-repos/confighub-examples/global-app/`
- **TraderX**: `/Users/alexis/traderx/`
- **Validation Framework**: `/Users/alexis/traderx/test/lib/cub-test-framework.sh`

### Issues
- **Brian's Feedback**: See "alexis brian vibe testing notes.pdf"
- **Report Issues**: Document in test comments and update validation logic

## Summary

The cub Command Analyzer provides:

✅ **Per-file, per-command analysis** - Every cub operation validated
✅ **Syntax validation** - Correct command structure
✅ **Grammar validation** - Valid WHERE clauses
✅ **Error detection** - Common mistakes caught
✅ **Semantic explanation** - English description with pre/post conditions
✅ **Correction suggestions** - Fixes for invalid patterns
✅ **CI/CD ready** - Automated validation

**Goal**: Ensure 100% correct cub CLI usage at all times through comprehensive static analysis.
