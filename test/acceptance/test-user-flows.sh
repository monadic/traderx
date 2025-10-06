#!/bin/bash
set -euo pipefail

# TraderX User Acceptance Tests
# Validates common user workflows and tutorial steps

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
echo "User Acceptance Tests"
echo "======================================"
echo ""

# Test Suite 1: Documentation Validation
echo "Test Suite 1: Documentation Validation"
echo "--------------------------------------"

test_start "README.md exists"
if [ -f "README.md" ]; then
  test_pass
else
  test_fail "README.md not found"
fi

test_start "QUICKSTART.md exists"
if [ -f "QUICKSTART.md" ]; then
  test_pass
else
  test_fail "QUICKSTART.md not found"
fi

test_start "RUNBOOK.md exists"
if [ -f "RUNBOOK.md" ]; then
  test_pass
else
  test_fail "RUNBOOK.md not found"
fi

echo ""

# Test Suite 2: Common Operations
echo "Test Suite 2: Common Operations"
echo "--------------------------------------"

test_start "List deployment scripts"
script_count=$(ls bin/ | grep -v "\.sh$" | wc -l | tr -d ' ')
if [ "$script_count" -ge 10 ]; then
  test_pass "Found $script_count scripts"
else
  test_fail "Only found $script_count scripts (expected >= 10)"
fi

test_start "All scripts have usage messages"
missing_usage=0
for script in bin/ordered-apply bin/health-check bin/rollback bin/validate-deployment bin/blue-green-deploy; do
  if [ -f "$script" ]; then
    if ! grep -q "Usage:" "$script"; then
      missing_usage=$((missing_usage + 1))
    fi
  fi
done

if [ $missing_usage -eq 0 ]; then
  test_pass "All scripts have usage messages"
else
  test_fail "$missing_usage scripts missing usage messages"
fi

echo ""

# Summary
echo "======================================"
echo "Acceptance Test Summary"
echo "======================================"
echo "Total tests: $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}All acceptance tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some acceptance tests failed!${NC}"
  exit 1
fi
