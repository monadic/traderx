#!/bin/bash
set -euo pipefail

# TraderX Worker Configuration Tests
# Tests ConfigHub worker setup and configuration

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

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
echo "Worker Configuration Tests"
echo "======================================"
echo ""

# Test Suite 1: Worker Script Validation
echo "Test Suite 1: Worker Script Validation"
echo "--------------------------------------"

test_start "setup-worker script exists"
if [ -f "bin/setup-worker" ]; then
  test_pass
else
  test_fail "Script not found"
fi

test_start "setup-worker is executable"
if [ -x "bin/setup-worker" ]; then
  test_pass
else
  test_fail "Script not executable"
fi

test_start "setup-worker has valid syntax"
if bash -n "bin/setup-worker" 2>/dev/null; then
  test_pass
else
  test_fail "Syntax error"
fi

echo ""

# Test Suite 2: Worker Configuration
echo "Test Suite 2: Worker Configuration"
echo "--------------------------------------"

test_start "Worker uses ConfigHub CLI"
if grep -q "cub worker" "bin/setup-worker"; then
  test_pass
else
  test_fail "Missing cub worker commands"
fi

test_start "Worker creates target"
if grep -q "cub target" "bin/setup-worker"; then
  test_pass
else
  test_fail "Missing target creation"
fi

test_start "Worker has error handling"
if grep -q "set -euo pipefail" "bin/setup-worker"; then
  test_pass
else
  test_fail "Missing error handling"
fi

echo ""

# Test Suite 3: Worker Operations (if cluster available)
echo "Test Suite 3: Worker Operations"
echo "--------------------------------------"

if kubectl cluster-info &>/dev/null; then
  test_start "Kubernetes cluster accessible"
  test_pass

  test_start "confighub namespace exists or can be created"
  if kubectl get namespace confighub &>/dev/null || kubectl create namespace confighub &>/dev/null; then
    test_pass
  else
    test_fail "Cannot access/create confighub namespace"
  fi

  test_start "Worker pod exists"
  if kubectl get pods -n confighub -l app=confighub-worker &>/dev/null; then
    pod_count=$(kubectl get pods -n confighub -l app=confighub-worker --no-headers 2>/dev/null | wc -l)
    if [ "$pod_count" -gt 0 ]; then
      test_pass
    else
      echo -e "${YELLOW}SKIP${NC}: No worker pods found (expected if not deployed)"
    fi
  else
    echo -e "${YELLOW}SKIP${NC}: Worker not deployed"
  fi
else
  echo "Skipping: No Kubernetes cluster available"
fi

echo ""

# Summary
echo "======================================"
echo "Worker Test Summary"
echo "======================================"
echo "Total tests: $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}All worker tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some worker tests failed!${NC}"
  exit 1
fi
