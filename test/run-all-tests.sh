#!/bin/bash
set -euo pipefail

# TraderX - Run All Tests
# Executes complete test suite

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CI_MODE=false
COVERAGE_MODE=false
QUICK_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --ci)
      CI_MODE=true
      shift
      ;;
    --coverage)
      COVERAGE_MODE=true
      shift
      ;;
    --quick)
      QUICK_MODE=true
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --ci         Run in CI mode (non-interactive)"
      echo "  --coverage   Generate coverage report"
      echo "  --quick      Run only quick unit tests"
      echo "  --help       Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "========================================"
echo "TraderX Test Suite"
echo "========================================"
echo ""

# Check prerequisites
echo "Checking prerequisites..."
MISSING_TOOLS=()

if ! command -v kubectl &>/dev/null; then
  MISSING_TOOLS+=("kubectl")
fi

if ! command -v cub &>/dev/null; then
  MISSING_TOOLS+=("cub")
fi

if ! command -v jq &>/dev/null; then
  MISSING_TOOLS+=("jq")
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  echo -e "${RED}Missing required tools: ${MISSING_TOOLS[*]}${NC}"
  exit 1
fi

echo -e "${GREEN}All prerequisites found${NC}"
echo ""

# Test execution tracking
SUITES_RUN=0
SUITES_PASSED=0
SUITES_FAILED=0
START_TIME=$(date +%s)

run_test_suite() {
  local name=$1
  local script=$2
  local required=${3:-true}

  SUITES_RUN=$((SUITES_RUN + 1))

  echo -e "${BLUE}[SUITE $SUITES_RUN]${NC} $name"
  echo "Running: $script"

  if [ ! -f "$script" ]; then
    echo -e "${YELLOW}SKIP${NC}: Test script not found"
    if [ "$required" = "true" ]; then
      SUITES_FAILED=$((SUITES_FAILED + 1))
    fi
    echo ""
    return 1
  fi

  if bash "$script"; then
    echo -e "${GREEN}✓ PASS${NC}: $name"
    SUITES_PASSED=$((SUITES_PASSED + 1))
  else
    echo -e "${RED}✗ FAIL${NC}: $name"
    SUITES_FAILED=$((SUITES_FAILED + 1))

    if [ "$CI_MODE" = "false" ]; then
      read -p "Continue with remaining tests? (y/n) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
      fi
    fi
  fi

  echo ""
}

# Run test suites
echo "========================================"
echo "Executing Test Suites"
echo "========================================"
echo ""

# 1. Unit Tests
run_test_suite "Unit Tests - Scripts" "test/unit/test-scripts.sh" true

if [ "$QUICK_MODE" = "false" ]; then
  run_test_suite "Unit Tests - ConfigHub API" "test/unit/confighub-api/test-api.sh" true
  run_test_suite "Unit Tests - CLI Commands" "test/unit/cli/test-cub-commands.sh" false
  run_test_suite "Unit Tests - Workers" "test/unit/workers/test-worker-config.sh" false
fi

# 2. Integration Tests (skip in quick mode)
if [ "$QUICK_MODE" = "false" ]; then
  if kubectl cluster-info &>/dev/null; then
    run_test_suite "Integration Tests - Deployment" "test/integration/test-deployment.sh" true
  else
    echo -e "${YELLOW}SKIP${NC}: Integration tests (no Kubernetes cluster)"
  fi
fi

# 3. E2E Tests (skip in quick mode, optional)
if [ "$QUICK_MODE" = "false" ] && [ "$CI_MODE" = "false" ]; then
  run_test_suite "E2E Tests - Full Workflow" "test/e2e/test-full-workflow.sh" false
fi

# 4. Regression Tests
if [ "$QUICK_MODE" = "false" ]; then
  run_test_suite "Regression Tests" "test/regression/test-regression.sh" false
fi

# 5. Acceptance Tests
if [ "$QUICK_MODE" = "false" ] && [ "$CI_MODE" = "false" ]; then
  run_test_suite "Acceptance Tests - User Flows" "test/acceptance/test-user-flows.sh" false
fi

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Summary
echo "========================================"
echo "Test Suite Summary"
echo "========================================"
echo "Mode: $([ "$QUICK_MODE" = "true" ] && echo "Quick" || echo "Full")"
echo "Duration: ${DURATION}s"
echo ""
echo "Suites run: $SUITES_RUN"
echo -e "Passed: ${GREEN}$SUITES_PASSED${NC}"
echo -e "Failed: ${RED}$SUITES_FAILED${NC}"
echo ""

# Calculate success rate
if [ $SUITES_RUN -gt 0 ]; then
  SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($SUITES_PASSED/$SUITES_RUN)*100}")
  echo "Success rate: $SUCCESS_RATE%"
  echo ""
fi

# Coverage report
if [ "$COVERAGE_MODE" = "true" ]; then
  echo "Generating coverage report..."
  if [ -f "test/generate-coverage-report.sh" ]; then
    bash test/generate-coverage-report.sh
  else
    echo -e "${YELLOW}Coverage report script not found${NC}"
  fi
  echo ""
fi

# Exit status
if [ $SUITES_FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ All test suites passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some test suites failed${NC}"

  if [ "$CI_MODE" = "true" ]; then
    echo ""
    echo "CI Mode - Build Failed"
  fi

  exit 1
fi
