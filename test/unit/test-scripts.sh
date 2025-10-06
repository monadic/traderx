#!/bin/bash
set -euo pipefail

# TraderX Unit Tests - Test All Deployment Scripts
# Validates script syntax, logic, and idempotency

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test reporting functions
test_start() {
  echo -n "  Testing: $1 ... "
  TESTS_RUN=$((TESTS_RUN + 1))
}

test_pass() {
  echo -e "${GREEN}PASS${NC}"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
  echo -e "${RED}FAIL${NC}: $1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

echo "======================================"
echo "TraderX Script Unit Tests"
echo "======================================"
echo ""

# Test 1: Script existence
echo "Test Suite 1: Script Existence"
echo "--------------------------------------"

SCRIPTS=(
  "bin/install-base"
  "bin/install-envs"
  "bin/apply-all"
  "bin/ordered-apply"
  "bin/promote"
  "bin/setup-worker"
  "bin/health-check"
  "bin/rollback"
  "bin/validate-deployment"
  "bin/blue-green-deploy"
)

for script in "${SCRIPTS[@]}"; do
  test_start "$script exists"
  if [ -f "$script" ]; then
    test_pass
  else
    test_fail "Script not found"
  fi
done

echo ""

# Test 2: Script executability
echo "Test Suite 2: Script Executability"
echo "--------------------------------------"

for script in "${SCRIPTS[@]}"; do
  test_start "$script is executable"
  if [ -x "$script" ]; then
    test_pass
  else
    test_fail "Script is not executable"
  fi
done

echo ""

# Test 3: Shell syntax validation
echo "Test Suite 3: Shell Syntax Validation"
echo "--------------------------------------"

for script in "${SCRIPTS[@]}"; do
  test_start "$script has valid syntax"
  if bash -n "$script" 2>/dev/null; then
    test_pass
  else
    test_fail "Syntax error detected"
  fi
done

echo ""

# Test 4: Shellcheck validation (if available)
echo "Test Suite 4: Shellcheck Validation"
echo "--------------------------------------"

if command -v shellcheck &>/dev/null; then
  for script in "${SCRIPTS[@]}"; do
    test_start "$script passes shellcheck"
    if shellcheck "$script" 2>/dev/null; then
      test_pass
    else
      test_fail "Shellcheck found issues"
    fi
  done
else
  echo "  Skipping: shellcheck not installed"
fi

echo ""

# Test 5: Script has set -euo pipefail
echo "Test Suite 5: Error Handling (set -euo pipefail)"
echo "--------------------------------------"

for script in "${SCRIPTS[@]}"; do
  test_start "$script has set -euo pipefail"
  if grep -q "set -euo pipefail" "$script"; then
    test_pass
  else
    test_fail "Missing set -euo pipefail"
  fi
done

echo ""

# Test 6: Script has logging functions
echo "Test Suite 6: Logging Functions"
echo "--------------------------------------"

SCRIPTS_WITH_LOGGING=(
  "bin/ordered-apply"
  "bin/health-check"
  "bin/rollback"
  "bin/validate-deployment"
  "bin/blue-green-deploy"
)

for script in "${SCRIPTS_WITH_LOGGING[@]}"; do
  test_start "$script has logging functions"
  if grep -q "timestamp()" "$script" && \
     grep -q "log()" "$script" && \
     grep -q "error()" "$script"; then
    test_pass
  else
    test_fail "Missing logging functions"
  fi
done

echo ""

# Test 7: Script has error handling
echo "Test Suite 7: Error Trapping"
echo "--------------------------------------"

SCRIPTS_WITH_TRAPS=(
  "bin/ordered-apply"
  "bin/rollback"
  "bin/blue-green-deploy"
)

for script in "${SCRIPTS_WITH_TRAPS[@]}"; do
  test_start "$script has error trap"
  if grep -q "trap.*ERR" "$script"; then
    test_pass
  else
    test_fail "Missing error trap"
  fi
done

echo ""

# Test 8: ConfigHub-only commands (NO kubectl in production code)
echo "Test Suite 8: ConfigHub-Only Commands"
echo "--------------------------------------"

PRODUCTION_SCRIPTS=(
  "bin/install-base"
  "bin/install-envs"
  "bin/promote"
)

for script in "${PRODUCTION_SCRIPTS[@]}"; do
  test_start "$script uses only cub commands"
  # Check for kubectl in non-comment, non-echo lines
  if grep -v "^[[:space:]]*#" "$script" | \
     grep -v "echo" | \
     grep -q "kubectl"; then
    test_fail "Found kubectl command (should use cub only)"
  else
    test_pass
  fi
done

echo ""

# Test 9: Usage/help messages
echo "Test Suite 9: Usage Messages"
echo "--------------------------------------"

SCRIPTS_WITH_USAGE=(
  "bin/ordered-apply"
  "bin/health-check"
  "bin/rollback"
  "bin/validate-deployment"
  "bin/blue-green-deploy"
)

for script in "${SCRIPTS_WITH_USAGE[@]}"; do
  test_start "$script has usage message"
  if grep -q "Usage:" "$script"; then
    test_pass
  else
    test_fail "Missing usage message"
  fi
done

echo ""

# Test 10: Idempotency checks
echo "Test Suite 10: Idempotency Patterns"
echo "--------------------------------------"

test_start "install-base is idempotent"
if grep -q "|| true\||| echo\|&>/dev/null" "bin/install-base"; then
  test_pass
else
  test_fail "May not be idempotent"
fi

test_start "apply-all is idempotent"
if grep -q "|| " "bin/apply-all"; then
  test_pass
else
  test_fail "May not be idempotent"
fi

echo ""

# Test 11: YAML manifest validation
echo "Test Suite 11: YAML Manifest Validation"
echo "--------------------------------------"

MANIFESTS=(
  "confighub/base/namespace.yaml"
  "confighub/base/reference-data-deployment.yaml"
  "confighub/base/trade-service-deployment.yaml"
  "confighub/base/position-service-deployment.yaml"
)

for manifest in "${MANIFESTS[@]}"; do
  test_start "$manifest is valid YAML"
  if python3 -c "import yaml; yaml.safe_load(open('$manifest'))" 2>/dev/null || \
     ruby -ryaml -e "YAML.load_file('$manifest')" 2>/dev/null; then
    test_pass
  else
    test_fail "YAML syntax error"
  fi
done

echo ""

# Test 12: Namespace and replica configuration
echo "Test Suite 12: Namespace and Replica Configuration"
echo "--------------------------------------"

DEPLOYMENT_MANIFESTS=(
  "confighub/base/trade-service-deployment.yaml"
  "confighub/base/reference-data-deployment.yaml"
)

for manifest in "${DEPLOYMENT_MANIFESTS[@]}"; do
  test_start "$manifest has namespace and replicas"
  if grep -q "namespace:" "$manifest" && \
     grep -q "replicas:" "$manifest"; then
    test_pass
  else
    test_fail "Missing namespace or replicas fields"
  fi
done

echo ""

# Test 13: Health checks in manifests
echo "Test Suite 13: Health Checks in Manifests"
echo "--------------------------------------"

for manifest in "${DEPLOYMENT_MANIFESTS[@]}"; do
  test_start "$manifest has health probes"
  if grep -q "livenessProbe:" "$manifest" && \
     grep -q "readinessProbe:" "$manifest" && \
     grep -q "startupProbe:" "$manifest"; then
    test_pass
  else
    test_fail "Missing health probes"
  fi
done

echo ""

# Test 14: Resource limits in manifests
echo "Test Suite 14: Resource Limits"
echo "--------------------------------------"

for manifest in "${DEPLOYMENT_MANIFESTS[@]}"; do
  test_start "$manifest has resource limits"
  if grep -q "resources:" "$manifest" && \
     grep -q "requests:" "$manifest" && \
     grep -q "limits:" "$manifest"; then
    test_pass
  else
    test_fail "Missing resource limits"
  fi
done

echo ""

# Test 15: Security context
echo "Test Suite 15: Security Context"
echo "--------------------------------------"

for manifest in "${DEPLOYMENT_MANIFESTS[@]}"; do
  test_start "$manifest has security context"
  if grep -q "securityContext:" "$manifest" && \
     grep -q "runAsNonRoot:" "$manifest"; then
    test_pass
  else
    test_fail "Missing security context"
  fi
done

echo ""

# Summary
echo "======================================"
echo "Test Summary"
echo "======================================"
echo "Total tests: $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
fi
