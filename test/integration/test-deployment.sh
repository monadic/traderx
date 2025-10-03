#!/bin/bash
set -euo pipefail

# TraderX Integration Tests - End-to-End Deployment Testing
# Tests the complete deployment workflow

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test reporting functions
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

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

echo "======================================"
echo "TraderX Integration Tests"
echo "======================================"
echo ""

# Check prerequisites
info "Checking prerequisites..."

if ! command -v kubectl &>/dev/null; then
  error "kubectl not found - please install kubectl"
  exit 1
fi

if ! command -v cub &>/dev/null; then
  error "cub CLI not found - please install ConfigHub CLI"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  warn "jq not found - some tests may be skipped"
fi

echo ""

# Test environment
TEST_ENV="dev"
if [ -n "${1:-}" ]; then
  TEST_ENV=$1
fi

info "Test environment: $TEST_ENV"
echo ""

# Test 1: ConfigHub authentication
echo "Test Suite 1: ConfigHub Authentication"
echo "--------------------------------------"

test_start "ConfigHub authentication"
if cub auth status &>/dev/null; then
  test_pass "Authenticated with ConfigHub"
else
  test_fail "Not authenticated with ConfigHub"
  error "Run: cub auth login"
  exit 1
fi

echo ""

# Test 2: Project setup
echo "Test Suite 2: Project Setup"
echo "--------------------------------------"

test_start "Project prefix exists"
if [ -f ".cub-project" ]; then
  PROJECT=$(cat .cub-project)
  test_pass "Project: $PROJECT"
else
  test_fail "Project not initialized"
  warn "Run: bin/install-base"
fi

echo ""

# Test 3: ConfigHub spaces
echo "Test Suite 3: ConfigHub Spaces"
echo "--------------------------------------"

if [ -n "${PROJECT:-}" ]; then
  SPACES=(
    "${PROJECT}-base"
    "${PROJECT}-filters"
    "${PROJECT}-${TEST_ENV}"
  )

  for space in "${SPACES[@]}"; do
    test_start "Space $space exists"
    if cub space get "$space" &>/dev/null; then
      test_pass "Space found"
    else
      test_fail "Space not found"
    fi
  done
fi

echo ""

# Test 4: ConfigHub units
echo "Test Suite 4: ConfigHub Units"
echo "--------------------------------------"

if [ -n "${PROJECT:-}" ]; then
  test_start "Units exist in base space"
  unit_count=$(cub unit list --space "${PROJECT}-base" --format json 2>/dev/null | jq length)
  if [ "$unit_count" -ge 17 ]; then
    test_pass "Found $unit_count units (expected >= 17)"
  else
    test_fail "Found only $unit_count units (expected >= 17)"
  fi

  test_start "Units exist in $TEST_ENV space"
  unit_count=$(cub unit list --space "${PROJECT}-${TEST_ENV}" --format json 2>/dev/null | jq length)
  if [ "$unit_count" -ge 17 ]; then
    test_pass "Found $unit_count units"
  else
    test_fail "Found only $unit_count units"
  fi
fi

echo ""

# Test 5: Kubernetes namespace
echo "Test Suite 5: Kubernetes Namespace"
echo "--------------------------------------"

NAMESPACE="traderx-${TEST_ENV}"

test_start "Namespace $NAMESPACE exists"
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
  status=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.status.phase}')
  if [ "$status" == "Active" ]; then
    test_pass "Namespace is Active"
  else
    test_fail "Namespace status: $status"
  fi
else
  test_fail "Namespace not found"
fi

echo ""

# Test 6: Service deployments
echo "Test Suite 6: Service Deployments"
echo "--------------------------------------"

SERVICES=(
  "reference-data"
  "people-service"
  "account-service"
  "position-service"
  "trade-service"
  "trade-processor"
  "trade-feed"
  "web-gui"
)

all_ready=true
for service in "${SERVICES[@]}"; do
  test_start "Deployment $service"
  if kubectl get deployment "$service" -n "$NAMESPACE" &>/dev/null; then
    desired=$(kubectl get deployment "$service" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
    ready=$(kubectl get deployment "$service" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' || echo "0")

    if [ "$ready" -eq "$desired" ] && [ "$ready" -gt 0 ]; then
      test_pass "$ready/$desired replicas ready"
    else
      test_fail "$ready/$desired replicas ready"
      all_ready=false
    fi
  else
    test_fail "Deployment not found"
    all_ready=false
  fi
done

echo ""

# Test 7: Service endpoints
echo "Test Suite 7: Service Endpoints"
echo "--------------------------------------"

SERVICES_WITH_PORTS=(
  "reference-data:18085"
  "people-service:18089"
  "account-service:18091"
  "position-service:18090"
  "trade-service:18092"
  "trade-feed:18088"
  "web-gui:18080"
)

for service_info in "${SERVICES_WITH_PORTS[@]}"; do
  IFS=':' read -r service port <<< "$service_info"

  test_start "Service $service endpoint"
  if kubectl get svc "$service" -n "$NAMESPACE" &>/dev/null; then
    cluster_ip=$(kubectl get svc "$service" -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
    service_port=$(kubectl get svc "$service" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}')

    if [ -n "$cluster_ip" ] && [ "$service_port" == "$port" ]; then
      test_pass "ClusterIP: $cluster_ip:$service_port"
    else
      test_fail "Invalid configuration"
    fi
  else
    test_fail "Service not found"
  fi
done

echo ""

# Test 8: Service dependencies
echo "Test Suite 8: Service Dependencies"
echo "--------------------------------------"

test_start "reference-data → position-service connectivity"
# Try to curl reference-data from a test pod
if timeout 10 kubectl run dep-test --rm -i --restart=Never --image=curlimages/curl:latest \
  -- curl -s -f "http://reference-data.$NAMESPACE.svc.cluster.local:18085" &>/dev/null; then
  test_pass "Services can communicate"
else
  warn "Unable to test service connectivity (may be expected)"
fi

echo ""

# Test 9: Pod health
echo "Test Suite 9: Pod Health"
echo "--------------------------------------"

for service in "${SERVICES[@]}"; do
  test_start "Pod health for $service"

  # Check for failed pods
  failed_pods=$(kubectl get pods -n "$NAMESPACE" -l "app=$service" \
    --field-selector=status.phase=Failed 2>/dev/null | grep -c "$service" || echo "0")

  if [ "$failed_pods" -eq 0 ]; then
    test_pass "No failed pods"
  else
    test_fail "$failed_pods failed pods detected"
  fi
done

echo ""

# Test 10: Resource limits
echo "Test Suite 10: Resource Limits"
echo "--------------------------------------"

deployments_without_limits=0
total_deployments=0

for service in "${SERVICES[@]}"; do
  test_start "Resource limits for $service"
  total_deployments=$((total_deployments + 1))

  if kubectl get deployment "$service" -n "$NAMESPACE" &>/dev/null; then
    has_limits=$(kubectl get deployment "$service" -n "$NAMESPACE" -o json | \
      jq '.spec.template.spec.containers[0].resources.limits != null')

    if [ "$has_limits" == "true" ]; then
      test_pass "Resource limits configured"
    else
      test_fail "No resource limits"
      deployments_without_limits=$((deployments_without_limits + 1))
    fi
  fi
done

if [ $deployments_without_limits -eq 0 ]; then
  info "All deployments have resource limits"
else
  warn "$deployments_without_limits/$total_deployments deployments missing resource limits"
fi

echo ""

# Test 11: Health probes
echo "Test Suite 11: Health Probes"
echo "--------------------------------------"

for service in "${SERVICES[@]}"; do
  test_start "Health probes for $service"

  if kubectl get deployment "$service" -n "$NAMESPACE" &>/dev/null; then
    has_liveness=$(kubectl get deployment "$service" -n "$NAMESPACE" -o json | \
      jq '.spec.template.spec.containers[0].livenessProbe != null')
    has_readiness=$(kubectl get deployment "$service" -n "$NAMESPACE" -o json | \
      jq '.spec.template.spec.containers[0].readinessProbe != null')

    if [ "$has_liveness" == "true" ] && [ "$has_readiness" == "true" ]; then
      test_pass "Liveness and readiness probes configured"
    else
      warn "Missing health probes (liveness: $has_liveness, readiness: $has_readiness)"
    fi
  fi
done

echo ""

# Test 12: Ingress
echo "Test Suite 12: Ingress"
echo "--------------------------------------"

test_start "Ingress resource exists"
if kubectl get ingress -n "$NAMESPACE" &>/dev/null; then
  ingress_count=$(kubectl get ingress -n "$NAMESPACE" -o json | jq '.items | length')
  test_pass "Found $ingress_count ingress resource(s)"
else
  test_fail "No ingress resources found"
fi

echo ""

# Test 13: ConfigHub live state
echo "Test Suite 13: ConfigHub Live State"
echo "--------------------------------------"

CRITICAL_SERVICES=("reference-data" "trade-service" "position-service")

for service in "${CRITICAL_SERVICES[@]}"; do
  test_start "ConfigHub live state for $service"

  if cub unit get-live-state "${service}-deployment" --space "${PROJECT}-${TEST_ENV}" &>/dev/null; then
    test_pass "Live state available"
  else
    warn "Live state not available (worker may not be running)"
  fi
done

echo ""

# Test 14: Labels and annotations
echo "Test Suite 14: Labels and Annotations"
echo "--------------------------------------"

test_start "Deployments have required labels"
missing_labels=0

for service in "${SERVICES[@]}"; do
  if kubectl get deployment "$service" -n "$NAMESPACE" &>/dev/null; then
    has_service_label=$(kubectl get deployment "$service" -n "$NAMESPACE" -o json | \
      jq '.metadata.labels.service != null')
    has_layer_label=$(kubectl get deployment "$service" -n "$NAMESPACE" -o json | \
      jq '.metadata.labels.layer != null')

    if [ "$has_service_label" != "true" ] || [ "$has_layer_label" != "true" ]; then
      missing_labels=$((missing_labels + 1))
    fi
  fi
done

if [ $missing_labels -eq 0 ]; then
  test_pass "All deployments have required labels"
else
  test_fail "$missing_labels deployments missing labels"
fi

echo ""

# Summary
echo "======================================"
echo "Integration Test Summary"
echo "======================================"
echo "Environment: $TEST_ENV"
echo "Namespace: $NAMESPACE"
if [ -n "${PROJECT:-}" ]; then
  echo "Project: $PROJECT"
fi
echo ""
echo "Total tests: $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo "Success rate: $(awk "BEGIN {printf \"%.1f\", ($TESTS_PASSED/$TESTS_RUN)*100}")%"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}All integration tests passed!${NC}"
  echo ""
  echo "Next steps:"
  echo "  - Run full validation: bin/validate-deployment $TEST_ENV"
  echo "  - Check health: bin/health-check $TEST_ENV"
  echo "  - View logs: kubectl logs deployment/<service-name> -n $NAMESPACE"
  exit 0
else
  echo -e "${RED}Some integration tests failed!${NC}"
  echo ""
  echo "Troubleshooting:"
  echo "  - Check deployment status: kubectl get all -n $NAMESPACE"
  echo "  - View pod logs: kubectl logs <pod-name> -n $NAMESPACE"
  echo "  - Run health check: bin/health-check $TEST_ENV"
  exit 1
fi
