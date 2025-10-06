# TraderX Coverage Requirements

## Overview

This document defines the minimum coverage requirements for all test categories in the TraderX project.

## Coverage Metrics

### Overall Project Coverage
- **Minimum Required**: 85%
- **Target**: 95%
- **Current**: To be measured on first full test run

### Measurement Method
- Line coverage for scripts
- API operation coverage for ConfigHub
- Command coverage for CLI
- Feature coverage for workflows

## Category-Specific Requirements

### 1. Script Coverage

**Requirement**: 85% minimum

**Measured By**: Lines executed during test runs

**Coverage Areas**:
```
bin/install-base                   Required: 90%
bin/install-envs                   Required: 90%
bin/apply-all                      Required: 95%
bin/ordered-apply                  Required: 100%
bin/promote                        Required: 90%
bin/setup-worker                   Required: 100%
bin/health-check                   Required: 100%
bin/rollback                       Required: 100%
bin/validate-deployment            Required: 100%
bin/blue-green-deploy              Required: 100%
bin/proj                           Required: 100%
bin/set-version                    Required: 90%
```

**Exemptions**:
- Error handling branches (documented)
- Rarely-used maintenance scripts
- Debug-only code paths

### 2. ConfigHub API Coverage

**Requirement**: 100%

**All Operations Must Be Tested**:

**Space Operations**:
- ✓ Create space
- ✓ Get space
- ✓ List spaces
- ✓ Delete space
- ✓ Update space labels

**Unit Operations**:
- ✓ Create unit
- ✓ Get unit
- ✓ List units
- ✓ Update unit
- ✓ Delete unit
- ✓ Apply unit
- ✓ Destroy unit
- ✓ Get unit data
- ✓ Get live state

**Filter Operations**:
- ✓ Create filter
- ✓ Get filter
- ✓ List filters
- ✓ Delete filter
- ✓ Query with filter

**Set Operations**:
- ✓ Create set
- ✓ Get set
- ✓ List sets
- ✓ Delete set
- ✓ Add unit to set
- ✓ Remove unit from set

**Bulk Operations**:
- ✓ Bulk patch units
- ✓ Bulk apply units
- ✓ Bulk patch with upgrade (push-upgrade)

**Worker Operations**:
- ✓ Create worker
- ✓ Get worker status
- ✓ Delete worker
- ✓ Associate target with worker

**Target Operations**:
- ✓ Create target
- ✓ Get target
- ✓ Update target
- ✓ Delete target
- ✓ Set unit target

### 3. CLI Command Coverage

**Requirement**: 90%

**Critical Commands** (100% required):
```bash
cub auth login
cub auth status
cub space create
cub space get
cub space list
cub space delete
cub space new-prefix
cub unit create
cub unit get
cub unit list
cub unit update
cub unit apply
cub unit get-data
cub unit set-target
cub filter create
cub filter list
cub set create
cub set get
cub worker create
cub worker run
cub target create
cub run set-image-reference
```

**Important Commands** (90% required):
```bash
cub unit tree
cub unit get-live-state
cub revision list
cub link create
cub changeset create
```

**Optional Commands** (no requirement):
- Debug commands
- Experimental features

### 4. SDK Coverage

**Requirement**: 85% (if using SDK)

Note: TraderX primarily uses CLI, minimal SDK usage

**Areas to Test** (if applicable):
- ConfigHub client initialization
- API call wrappers
- Helper functions
- Error handling

### 5. Worker Coverage

**Requirement**: 100%

**Scenarios to Test**:
- ✓ Worker installation
- ✓ Worker status check
- ✓ Target creation
- ✓ Target association with units
- ✓ Apply operation success
- ✓ Apply operation failure handling
- ✓ Worker logs access
- ✓ Worker restart
- ✓ Multiple units apply
- ✓ Apply with dependencies

### 6. Kubernetes Resource Coverage

**Requirement**: 100%

**All Services Must Be Tested**:
```
✓ reference-data        (Deployment + Service)
✓ people-service        (Deployment + Service)
✓ account-service       (Deployment + Service)
✓ position-service      (Deployment + Service)
✓ trade-service         (Deployment + Service)
✓ trade-processor       (Deployment only)
✓ trade-feed            (Deployment + Service)
✓ web-gui               (Deployment + Service)
```

**Resource Types**:
- ✓ Namespace
- ✓ Deployments (8)
- ✓ Services (7)
- ✓ ServiceAccount (1)
- ✓ Ingress (1)

**Validation Points**:
- Resource creation
- Readiness status
- Health probes
- Resource limits
- Labels and annotations
- Service connectivity
- Pod logs availability

### 7. Workflow Coverage

**Requirement**: 100%

**Critical Workflows**:
- ✓ Fresh install (install-base → install-envs → apply-all)
- ✓ Environment promotion (dev → staging)
- ✓ Push-upgrade propagation
- ✓ Worker-driven apply
- ✓ Health check validation
- ✓ Rollback execution
- ✓ Blue-green deployment
- ✓ Validation workflow

**Workflow Steps**:
Each workflow must test:
- Pre-conditions
- Execution steps
- Post-conditions
- Error scenarios
- Cleanup

### 8. UI/Output Coverage

**Requirement**: 100%

**ASCII Tables**:
- ✓ Space listing tables
- ✓ Unit listing tables
- ✓ Filter listing tables
- ✓ Deployment status tables
- ✓ Health check tables
- ✓ Validation summary tables

**Dashboard Output**:
- ✓ Health check dashboard format
- ✓ Validation dashboard format
- ✓ Status indicators
- ✓ Color coding (if applicable)

**CLI Output**:
- ✓ Success messages
- ✓ Error messages
- ✓ Warning messages
- ✓ Progress indicators
- ✓ Help text

### 9. Error Handling Coverage

**Requirement**: 85%

**Error Scenarios**:
- ✓ ConfigHub API errors
- ✓ Kubernetes API errors
- ✓ Worker unavailable
- ✓ Network failures
- ✓ Invalid YAML
- ✓ Missing prerequisites
- ✓ Quota limits
- ✓ Authentication failures
- ✓ Permission denied
- ✓ Resource conflicts

### 10. Documentation Coverage

**Requirement**: 100%

**Documentation Must Match Implementation**:
- ✓ README.md commands work
- ✓ QUICKSTART.md steps succeed
- ✓ RUNBOOK.md procedures valid
- ✓ Script usage messages accurate
- ✓ Error messages helpful

## Coverage Reporting

### Report Format

```
TraderX Coverage Report
Generated: <timestamp>
=======================

Overall Coverage: 92.5%
Status: ✓ PASS (>= 85% required)

Category Breakdown:
-------------------
Scripts:              89.2%  ✓ (85% required)
ConfigHub API:       100.0%  ✓ (100% required)
CLI Commands:         94.7%  ✓ (90% required)
SDK:                  N/A    - (Not used)
Workers:             100.0%  ✓ (100% required)
Kubernetes Resources:100.0%  ✓ (100% required)
Workflows:           100.0%  ✓ (100% required)
UI/Output:           100.0%  ✓ (100% required)
Error Handling:       87.3%  ✓ (85% required)
Documentation:       100.0%  ✓ (100% required)

Untested Areas:
--------------
1. bin/install-base line 45-47 (error branch)
2. bin/promote line 89 (rare edge case)
3. CLI command: cub unit diff (not used in workflows)

Recommendations:
----------------
1. Add error branch tests for install-base
2. Consider testing promote edge cases
3. Overall coverage excellent, maintain current level
```

### Generating Reports

```bash
# Generate coverage report
./test/generate-coverage-report.sh

# Output locations
test/coverage/coverage-report.txt      # Text format
test/coverage/coverage-report.json     # JSON format
test/coverage/coverage-report.html     # HTML visualization
```

## Coverage Enforcement

### Pre-Commit Checks
```bash
# Check coverage before committing
./test/check-coverage.sh

# Minimum 85% required
# Fails commit if below threshold
```

### CI/CD Checks
```bash
# CI pipeline must verify coverage
./test/run-all-tests.sh --coverage

# Generate report
./test/generate-coverage-report.sh

# Upload to coverage service (if configured)
```

### Pull Request Requirements
- Coverage report must be included
- No reduction in coverage allowed (unless justified)
- New code must have >= 90% coverage

## Exemptions

### Allowed Exemptions
1. **Error handling branches** - Difficult to trigger in tests
2. **Debug code** - Only executed with DEBUG=true
3. **Deprecated code** - Scheduled for removal
4. **Platform-specific code** - Not applicable to test environment

### Requesting Exemption
1. Document reason in code comment
2. Add to exemptions list in this file
3. Explain in pull request
4. Get approval from reviewer

### Current Exemptions
```
# Exemption 1: Error branch in install-base
File: bin/install-base
Lines: 45-47
Reason: ConfigHub API error (quota exceeded) difficult to simulate
Approved: 2025-10-03

# Exemption 2: Cleanup on signal handler
File: bin/ordered-apply
Lines: 15-18
Reason: SIGTERM/SIGINT handling, tested manually
Approved: 2025-10-03
```

## Improvement Goals

### Short Term (Next Release)
- Achieve 90% overall coverage
- 100% coverage for all critical paths
- Add missing CLI command tests

### Medium Term (3 Months)
- Achieve 95% overall coverage
- Automated coverage tracking
- Coverage trend reporting

### Long Term (6 Months)
- Maintain >= 95% coverage
- Zero untested critical paths
- Full error scenario coverage

## Related Documentation

- [Testing Strategy](TESTING-STRATEGY.md)
- [Test README](../README.md)
- [Governing Principles](/Users/alexis/devops-as-apps-project/CLAUDE.md)
