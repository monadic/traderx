#!/bin/bash
set -euo pipefail

# Claude Session Startup - TraderX Test Validation
# Executes at the beginning of each Claude session to validate project state

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "Claude Session Startup - TraderX"
echo "========================================"
echo ""

# Step 1: Identify Test Suites
echo -e "${BLUE}Step 1: Identifying test suites...${NC}"
echo ""

TEST_SUITES=$(find test/ -name "test-*.sh" -type f | sort)
TEST_COUNT=$(echo "$TEST_SUITES" | wc -l | tr -d ' ')

echo "Found $TEST_COUNT test suites:"
echo "$TEST_SUITES" | sed 's/^/  - /'
echo ""

# Step 2: Offer Test Validation
echo -e "${BLUE}Step 2: Test validation options${NC}"
echo ""
echo "Would you like to:"
echo "  1. Run quick unit tests (< 30s) [RECOMMENDED]"
echo "  2. Run full integration tests (3-5 min)"
echo "  3. Run all tests (10+ min)"
echo "  4. Skip testing and proceed with work"
echo ""

# In automated mode, default to quick tests
if [ "${CLAUDE_AUTO_TEST:-}" = "true" ]; then
  CHOICE=1
  echo "Auto-test mode: Running quick unit tests"
else
  read -p "Select option [1-4]: " CHOICE
fi

echo ""

# Step 3: Execute Tests Based on Choice
case $CHOICE in
  1)
    echo -e "${BLUE}Step 3: Running quick unit tests...${NC}"
    echo ""
    ./test/unit/test-scripts.sh
    TEST_RESULT=$?
    ;;
  2)
    echo -e "${BLUE}Step 3: Running integration tests...${NC}"
    echo ""
    ./test/run-all-tests.sh --quick
    TEST_RESULT=$?
    ;;
  3)
    echo -e "${BLUE}Step 3: Running full test suite...${NC}"
    echo ""
    ./test/run-all-tests.sh
    TEST_RESULT=$?
    ;;
  4)
    echo -e "${YELLOW}Skipping tests - proceeding with work${NC}"
    echo ""
    echo "Note: Project state has not been validated"
    exit 0
    ;;
  *)
    echo -e "${RED}Invalid choice${NC}"
    exit 1
    ;;
esac

echo ""

# Step 4: Report Results
echo "========================================"
echo -e "${BLUE}Step 4: Test Results${NC}"
echo "========================================"
echo ""

if [ $TEST_RESULT -eq 0 ]; then
  echo -e "${GREEN}✓ All tests passed${NC}"
  echo ""
  echo "Project state: HEALTHY"
  echo "Ready to proceed with work"
  exit 0
else
  echo -e "${RED}✗ Some tests failed${NC}"
  echo ""
  echo "Project state: ISSUES DETECTED"
  echo ""

  # Step 5: Flag Issues and Provide Recommendations
  echo "========================================"
  echo -e "${BLUE}Step 5: Recommendations${NC}"
  echo "========================================"
  echo ""

  # Analyze common issues
  if ! cub auth status &>/dev/null; then
    echo -e "${YELLOW}Issue: Not authenticated with ConfigHub${NC}"
    echo "Recommendation: Run 'cub auth login'"
    echo ""
  fi

  if ! kubectl cluster-info &>/dev/null; then
    echo -e "${YELLOW}Issue: No Kubernetes cluster available${NC}"
    echo "Recommendation: Run 'kind create cluster --name traderx-test'"
    echo ""
  fi

  if ! kubectl get pods -n confighub &>/dev/null 2>&1; then
    echo -e "${YELLOW}Issue: ConfigHub worker not running${NC}"
    echo "Recommendation: Run 'bin/setup-worker dev'"
    echo ""
  fi

  echo "Review test output above for specific failures"
  echo ""

  read -p "Continue with work despite failures? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Proceeding with work - be aware of test failures"
    exit 0
  else
    echo "Stopping - resolve test failures first"
    exit 1
  fi
fi
