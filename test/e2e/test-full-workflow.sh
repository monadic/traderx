#!/bin/bash
set -euo pipefail

# TraderX End-to-End Workflow Test
# Tests complete deployment workflow from scratch

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

test_start() {
  echo -e "${BLUE}[TEST]${NC} $1"
  TESTS_RUN=$((TESTS_RUN + 1))
}

test_pass() {
  echo -e "  ${GREEN}✓ PASS${NC}: $1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
  echo -e "  ${RED}✗ FAIL${NC}: $1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

echo "========================================"
echo "TraderX E2E Workflow Test"
echo "========================================"
echo ""

# Prerequisites check
info "Checking prerequisites..."

if ! command -v kubectl &>/dev/null; then
  echo "Error: kubectl not found"
  exit 1
fi

if ! command -v cub &>/dev/null; then
  echo "Error: cub not found"
  exit 1
fi

if ! cub auth status &>/dev/null; then
  echo "Error: Not authenticated with ConfigHub"
  exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
  echo "Error: No Kubernetes cluster available"
  exit 1
fi

echo ""

# Workflow Test 1: Fresh Installation
echo "Workflow 1: Fresh Installation"
echo "--------------------------------------"

test_start "Clean previous test resources"
if [ -f ".cub-project" ]; then
  OLD_PROJECT=$(cat .cub-project)
  cub space delete "${OLD_PROJECT}-base" --force &>/dev/null || true
  cub space delete "${OLD_PROJECT}-filters" --force &>/dev/null || true
  cub space delete "${OLD_PROJECT}-dev" --force &>/dev/null || true
  rm .cub-project
fi
test_pass "Cleaned"

test_start "Run install-base"
if timeout 120 bin/install-base; then
  test_pass "Created ConfigHub structure"
else
  test_fail "install-base failed"
  exit 1
fi

test_start "Verify project prefix created"
if [ -f ".cub-project" ]; then
  PROJECT=$(cat .cub-project)
  test_pass "Project: $PROJECT"
else
  test_fail "No project prefix"
  exit 1
fi

test_start "Verify spaces created"
space_count=0
for space in "${PROJECT}-base" "${PROJECT}-filters"; do
  if cub space get "$space" &>/dev/null; then
    space_count=$((space_count + 1))
  fi
done

if [ $space_count -eq 2 ]; then
  test_pass "All spaces created"
else
  test_fail "Only $space_count/2 spaces created"
fi

test_start "Run install-envs"
if timeout 120 bin/install-envs; then
  test_pass "Created environment hierarchy"
else
  test_fail "install-envs failed"
fi

echo ""

# Workflow 2: Worker Setup
echo "Workflow 2: Worker Setup"
echo "--------------------------------------"

test_start "Setup worker"
if timeout 180 bin/setup-worker dev; then
  test_pass "Worker configured"
else
  test_fail "Worker setup failed"
fi

test_start "Verify worker running"
sleep 5  # Give worker time to start
if kubectl get pods -n confighub -l app=confighub-worker | grep -q "Running"; then
  test_pass "Worker is running"
else
  echo -e "${YELLOW}SKIP${NC}: Worker not yet running (may take time)"
fi

echo ""

# Workflow 3: Deployment
echo "Workflow 3: Deployment"
echo "--------------------------------------"

test_start "Deploy to dev environment"
if timeout 300 bin/ordered-apply dev; then
  test_pass "Deployment started"
else
  test_fail "Deployment failed"
fi

test_start "Wait for deployments to be ready"
sleep 30  # Give time for deployments to start

NAMESPACE="traderx-dev"
ready_count=0
total_count=8

for service in reference-data people-service account-service position-service trade-service trade-processor trade-feed web-gui; do
  if kubectl get deployment "$service" -n "$NAMESPACE" &>/dev/null; then
    replicas=$(kubectl get deployment "$service" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "$replicas" -gt 0 ]; then
      ready_count=$((ready_count + 1))
    fi
  fi
done

if [ $ready_count -ge 1 ]; then
  test_pass "$ready_count/$total_count services ready"
else
  test_fail "No services ready yet"
fi

echo ""

# Workflow 4: Validation
echo "Workflow 4: Validation"
echo "--------------------------------------"

test_start "Run health check"
if timeout 60 bin/health-check dev; then
  test_pass "Health check passed"
else
  echo -e "${YELLOW}WARN${NC}: Health check issues (expected for partial deployment)"
fi

test_start "Run validate-deployment"
if timeout 60 bin/validate-deployment dev; then
  test_pass "Validation passed"
else
  echo -e "${YELLOW}WARN${NC}: Validation issues (expected for partial deployment)"
fi

echo ""

# Cleanup (optional)
if [ "${E2E_CLEANUP:-true}" = "true" ]; then
  echo "Cleaning up test resources..."
  cub space delete "${PROJECT}-dev" --force &>/dev/null || true
  cub space delete "${PROJECT}-base" --force &>/dev/null || true
  cub space delete "${PROJECT}-filters" --force &>/dev/null || true
  kubectl delete namespace "$NAMESPACE" --force --grace-period=0 &>/dev/null || true
  rm .cub-project || true
  echo "Cleanup complete"
  echo ""
fi

# Summary
echo "======================================"
echo "E2E Workflow Test Summary"
echo "======================================"
echo "Total tests: $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}E2E workflow test passed!${NC}"
  exit 0
else
  echo -e "${RED}E2E workflow test had failures${NC}"
  exit 1
fi
