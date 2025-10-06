# TraderX Testing Strategy

## Overview

This document defines the comprehensive testing strategy for TraderX ConfigHub deployment, aligned with the governing principles in `/Users/alexis/devops-as-apps-project/CLAUDE.md`.

## Testing Objectives

1. **Verify ConfigHub Integration** - Ensure all ConfigHub operations work correctly
2. **Validate Kubernetes Deployment** - Confirm proper deployment to Kubernetes
3. **Test Worker Operations** - Verify worker can apply units successfully
4. **Ensure Script Reliability** - All scripts execute without errors
5. **Validate Complete Workflows** - End-to-end user workflows function correctly
6. **Prevent Regressions** - Detect breaking changes early
7. **User Experience** - Confirm tutorial and common operations work

## Test Pyramid

```
         /\
        /  \  E2E (10 tests)
       /____\
      /      \
     / Integration (20 tests)
    /____________\
   /              \
  /   Unit (100+)  \
 /__________________\
```

### Distribution
- **Unit Tests**: 70% of tests, 100% pass rate required
- **Integration Tests**: 20% of tests, >= 95% pass rate required
- **E2E Tests**: 10% of tests, >= 90% pass rate required

## Test Categories

### 1. Unit Tests

**Purpose**: Test individual components in isolation

**Coverage Areas**:
- Script syntax and structure
- ConfigHub API calls
- CLI command usage
- Helper functions
- YAML manifest validation
- Worker configuration

**Execution Time**: < 30 seconds total

**Pass Criteria**: 100% pass rate

**Test Files**:
- `test/unit/test-scripts.sh` - Script validation
- `test/unit/confighub-api/test-api.sh` - API tests
- `test/unit/cli/test-cub-commands.sh` - CLI tests
- `test/unit/sdk/test-sdk-usage.sh` - SDK tests
- `test/unit/workers/test-worker-config.sh` - Worker tests

### 2. Integration Tests

**Purpose**: Test component interactions

**Coverage Areas**:
- ConfigHub → Kubernetes workflow
- Worker apply operations
- Service connectivity
- Multi-service deployments
- ConfigHub live state
- Space hierarchy

**Execution Time**: 2-5 minutes

**Pass Criteria**: >= 95% pass rate

**Test Files**:
- `test/integration/test-deployment.sh` - Full deployment
- `test/integration/test-worker-apply.sh` - Worker integration
- `test/integration/test-service-connectivity.sh` - Service mesh

### 3. UI Tests

**Purpose**: Validate user-facing output

**Coverage Areas**:
- ASCII table rendering
- Dashboard output
- CLI output formatting
- Error messages
- Log format

**Execution Time**: < 1 minute

**Pass Criteria**: 100% pass rate

**Test Files**:
- `test/ui/ascii-tables/test-tables.sh` - Table validation
- `test/ui/dashboards/test-output.sh` - Dashboard tests

### 4. End-to-End Tests

**Purpose**: Test complete user workflows

**Coverage Areas**:
- Fresh deployment (install-base → apply)
- Environment promotion (dev → staging → prod)
- Blue-green deployment
- Rollback scenarios
- Health check workflows
- Validation workflows

**Execution Time**: 5-10 minutes

**Pass Criteria**: >= 90% pass rate

**Test Files**:
- `test/e2e/test-full-workflow.sh` - Complete workflow
- `test/e2e/test-promotion.sh` - Multi-environment
- `test/e2e/test-blue-green.sh` - Blue-green deployment
- `test/e2e/test-rollback.sh` - Rollback validation

### 5. Regression Tests

**Purpose**: Prevent previously fixed bugs from reappearing

**Coverage Areas**:
- Known bug fixes
- API breaking changes
- Performance regressions
- Configuration changes

**Execution Time**: 2-3 minutes

**Pass Criteria**: 100% pass rate

**Test Files**:
- `test/regression/test-regression.sh` - All regression tests
- `test/regression/known-issues.md` - Bug registry

### 6. User Acceptance Tests

**Purpose**: Validate user-facing functionality

**Coverage Areas**:
- Tutorial workflows
- QUICKSTART.md steps
- Common operations
- Error handling
- Documentation accuracy

**Execution Time**: 3-5 minutes

**Pass Criteria**: >= 95% pass rate

**Test Files**:
- `test/acceptance/test-user-flows.sh` - User workflows
- `test/acceptance/test-tutorial.sh` - Tutorial validation
- `test/acceptance/test-common-ops.sh` - Common operations

## Test Execution Strategy

### Development Workflow

```bash
# 1. Before starting work
./test/claude-session-startup.sh

# 2. During development
./test/unit/test-scripts.sh  # After script changes

# 3. Before commit
./test/unit/test-scripts.sh
./test/integration/test-deployment.sh dev  # If deployment changes

# 4. Before push
./test/run-all-tests.sh
```

### CI/CD Pipeline

```bash
# Stage 1: Quick validation (< 1 min)
./test/unit/test-scripts.sh

# Stage 2: Integration (3-5 min)
./test/integration/test-deployment.sh ci

# Stage 3: E2E (10-15 min)
./test/e2e/test-full-workflow.sh ci

# Stage 4: Acceptance (5 min)
./test/acceptance/test-user-flows.sh ci
```

### Pre-Release Testing

```bash
# Full test suite with real infrastructure
export TEST_MODE=production

# 1. Unit tests
./test/unit/test-scripts.sh

# 2. Integration tests
./test/integration/test-deployment.sh dev

# 3. E2E tests
./test/e2e/test-full-workflow.sh dev

# 4. Regression tests
./test/regression/test-regression.sh

# 5. Acceptance tests
./test/acceptance/test-user-flows.sh dev

# 6. Generate coverage report
./test/generate-coverage-report.sh
```

## Claude Agent Testing Protocol

### Session Startup
At the beginning of each Claude session:

1. **Identify Test Suites**
   ```bash
   find test/ -name "test-*.sh" -type f
   ```

2. **Offer Test Validation**
   ```
   Claude: "I've identified 15 test suites. Would you like me to:
   1. Run quick unit tests (< 30s)
   2. Run full integration tests (3-5 min)
   3. Skip testing and proceed with work

   Recommendation: Run quick unit tests to verify project state."
   ```

3. **Execute Tests**
   ```bash
   ./test/claude-session-startup.sh
   ```

4. **Report Results**
   ```
   Claude: "Test Results:
   ✓ Unit tests: 98/100 passed (98%)
   ✗ Integration tests: 18/20 passed (90%)

   Failing tests:
   - test-worker-apply.sh: Worker not running

   Recommendation: Start worker before proceeding.
   Command: bin/setup-worker dev"
   ```

5. **Flag Issues**
   - If tests fail: Report failures and recommend fixes
   - If tests pass: Proceed with requested work
   - If tests skipped: Note that validation was not performed

### During Development
- Run relevant test suite after each significant change
- Update tests when modifying functionality
- Add regression tests for bug fixes

### Before Commit
- Run full test suite
- Ensure all tests pass or document expected failures
- Update test documentation if needed

## Test Data Management

### Mock Data
- Located in `test/fixtures/`
- Used for unit tests
- No external dependencies

### Test Environments
- **dev**: Local Kind cluster
- **ci**: CI/CD environment
- **production**: Real infrastructure (pre-release only)

### Test Isolation
- Each test creates unique ConfigHub spaces
- Tests clean up after themselves
- No shared state between tests

## Performance Requirements

### Execution Time Limits
- Unit tests: < 30 seconds
- Integration tests: < 5 minutes
- E2E tests: < 15 minutes
- Full suite: < 25 minutes

### Resource Usage
- Memory: < 2GB
- CPU: < 4 cores
- Disk: < 10GB
- Network: Minimal (use local cluster)

## Coverage Requirements

See `COVERAGE-REQUIREMENTS.md` for detailed coverage metrics.

### Minimum Coverage
- Scripts: 85% (lines executed during tests)
- ConfigHub API: 100% (all operations tested)
- CLI commands: 90% (all common commands tested)
- Worker operations: 100% (all apply scenarios tested)
- Kubernetes resources: 100% (all 8 services tested)

## Test Maintenance

### Adding New Tests
1. Identify test category (unit/integration/e2e/etc)
2. Create test file following naming convention
3. Use test helpers from `test/test-helpers.sh`
4. Document test in this strategy doc
5. Add to `run-all-tests.sh`

### Updating Existing Tests
1. Maintain backward compatibility
2. Update documentation
3. Verify all tests still pass
4. Update coverage metrics

### Removing Tests
1. Document reason for removal
2. Check for dependencies
3. Update test documentation
4. Update coverage expectations

## Test Reporting

### Format
```
Test Suite: <name>
Status: <PASS|FAIL>
Duration: <seconds>
Pass Rate: <percentage>

Details:
  ✓ Test 1: <description>
  ✓ Test 2: <description>
  ✗ Test 3: <description>
    Reason: <failure message>
```

### Metrics Tracked
- Pass/fail rate per suite
- Execution time per suite
- Coverage percentage
- Flakiness rate
- Failure trends

### Reports Generated
- `test-results.txt` - Text summary
- `test-results.json` - Machine-readable
- `coverage-report.html` - Coverage visualization
- `test-history.log` - Historical data

## Known Limitations

1. **ConfigHub Quota**: Limited to 100 spaces
2. **Kind Cluster**: Requires local Docker
3. **Network Dependency**: Some tests require internet
4. **Time Dependency**: E2E tests take 10+ minutes

## Future Improvements

1. **Parallel Test Execution** - Run tests concurrently
2. **Test Caching** - Cache test results for unchanged code
3. **Visual Regression** - Screenshot comparison for dashboards
4. **Load Testing** - Test with multiple concurrent operations
5. **Chaos Testing** - Test resilience to failures
6. **Security Testing** - Automated security scans

## References

- [Governing Principles](/Users/alexis/devops-as-apps-project/CLAUDE.md)
- [Coverage Requirements](COVERAGE-REQUIREMENTS.md)
- [Test Helpers](../test-helpers.sh)
- [TraderX README](../../README.md)
