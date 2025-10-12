#!/bin/bash
set -euo pipefail

# TraderX ConfigHub API Tests
# Tests all ConfigHub API operations used by TraderX

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
echo "ConfigHub API Tests"
echo "======================================"
echo ""

# Check prerequisites
if ! command -v cub &>/dev/null; then
  echo "Error: cub CLI not found"
  exit 1
fi

if ! cub auth get-token &>/dev/null; then
  echo "Error: Not authenticated with ConfigHub"
  echo "Run: cub auth login"
  exit 1
fi

# Create test prefix
TEST_PREFIX="traderx-api-test-$$"

# Test Suite 1: Space Operations
echo "Test Suite 1: Space Operations"
echo "--------------------------------------"

test_start "Create space"
if cub space create "${TEST_PREFIX}-test" &>/dev/null; then
  test_pass
else
  test_fail "Failed to create space"
fi

test_start "Get space"
if cub space get "${TEST_PREFIX}-test" &>/dev/null; then
  test_pass
else
  test_fail "Failed to get space"
fi

test_start "List spaces"
if cub space list --format json | jq -e ".[] | select(.Slug == \"${TEST_PREFIX}-test\")" &>/dev/null; then
  test_pass
else
  test_fail "Space not in list"
fi

test_start "Update space labels"
if cub space update "${TEST_PREFIX}-test" --label "test=true" &>/dev/null; then
  test_pass
else
  test_fail "Failed to update labels"
fi

echo ""

# Test Suite 2: Unit Operations
echo "Test Suite 2: Unit Operations"
echo "--------------------------------------"

# Create test unit data
TEST_UNIT_DATA=$(cat <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-config
data:
  key: value
EOF
)

test_start "Create unit"
if echo "$TEST_UNIT_DATA" | cub unit create test-unit --space "${TEST_PREFIX}-test" --data - &>/dev/null; then
  test_pass
else
  test_fail "Failed to create unit"
fi

test_start "Get unit"
if cub unit get test-unit --space "${TEST_PREFIX}-test" &>/dev/null; then
  test_pass
else
  test_fail "Failed to get unit"
fi

test_start "List units"
if cub unit list --space "${TEST_PREFIX}-test" --format json | jq -e '.[] | select(.Slug == "test-unit")' &>/dev/null; then
  test_pass
else
  test_fail "Unit not in list"
fi

test_start "Get unit data"
if cub unit get-data test-unit --space "${TEST_PREFIX}-test" | grep -q "test-config"; then
  test_pass
else
  test_fail "Failed to get unit data"
fi

test_start "Update unit"
NEW_DATA="apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: test-config\ndata:\n  key: updated"
if echo -e "$NEW_DATA" | cub unit update test-unit --space "${TEST_PREFIX}-test" --data - &>/dev/null; then
  test_pass
else
  test_fail "Failed to update unit"
fi

echo ""

# Test Suite 3: Filter Operations
echo "Test Suite 3: Filter Operations"
echo "--------------------------------------"

test_start "Create filter"
if cub filter create test-filter Unit --where-field "Labels.test = 'true'" --space "${TEST_PREFIX}-test" &>/dev/null; then
  test_pass
else
  test_fail "Failed to create filter"
fi

test_start "Get filter"
if cub filter get test-filter --space "${TEST_PREFIX}-test" &>/dev/null; then
  test_pass
else
  test_fail "Failed to get filter"
fi

test_start "List filters"
if cub filter list --space "${TEST_PREFIX}-test" --format json | jq -e '.[] | select(.Slug == "test-filter")' &>/dev/null; then
  test_pass
else
  test_fail "Filter not in list"
fi

echo ""

# Test Suite 4: Set Operations
echo "Test Suite 4: Set Operations"
echo "--------------------------------------"

test_start "Create set"
if cub set create test-set --space "${TEST_PREFIX}-test" --label "type=test" &>/dev/null; then
  test_pass
else
  test_fail "Failed to create set"
fi

test_start "Get set"
if cub set get test-set --space "${TEST_PREFIX}-test" &>/dev/null; then
  test_pass
else
  test_fail "Failed to get set"
fi

test_start "List sets"
if cub set list --space "${TEST_PREFIX}-test" --format json | jq -e '.[] | select(.Slug == "test-set")' &>/dev/null; then
  test_pass
else
  test_fail "Set not in list"
fi

echo ""

# Cleanup
echo "Cleaning up test resources..."
cub space delete "${TEST_PREFIX}-test" --force &>/dev/null || true

# Summary
echo ""
echo "======================================"
echo "API Test Summary"
echo "======================================"
echo "Total tests: $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}All ConfigHub API tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some API tests failed!${NC}"
  exit 1
fi
