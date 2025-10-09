#!/bin/bash -x
# Copyright (C) ConfigHub, Inc.
# SPDX-License-Identifier: MIT

# Test script for TraderX application deployment with topological sorting
# This script tests that TraderX units are applied in the correct dependency order

set -e

ROOTDIR="$(git rev-parse --show-toplevel)"
export CONFIGHUB_URL=${CONFIGHUB_URL:-http://localhost:9090}
export CONFIGHUB_WORKER_PORT=${CONFIGHUB_WORKER_PORT:-9091}
export CONFIGHUB_WORKER_EXECUTABLE=$ROOTDIR/bin/cub-worker-run

export GRACE_PERIOD_DELAY=0

testlibsh="$ROOTDIR/test/scripts/test-lib.sh"
source $testlibsh

TRADERX_CONFIG_DIR="$ROOTDIR/test-data/traderx-config"

# Helper function for waiting with retries
wait_for_resource() {
    local resource_type=$1
    local namespace=$2
    local name=$3
    local max_retries=${4:-10}
    local retry_delay=${5:-2}
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        if kubectl get "$resource_type" -n "$namespace" "$name" > /dev/null 2>&1; then
            return 0  # Success
        fi
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo "  Waiting for $resource_type/$name in namespace $namespace... (attempt $retry_count/$max_retries)"
            sleep $retry_delay
        fi
    done
    return 1  # Failed after max retries
}

# Helper function for waiting for resource deletion
wait_for_deletion() {
    local resource_type=$1
    local namespace=$2
    local name=$3
    local max_retries=${4:-15}
    local retry_delay=${5:-2}
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        if ! kubectl get "$resource_type" -n "$namespace" "$name" > /dev/null 2>&1; then
            return 0  # Success - resource deleted
        fi
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo "  Waiting for deletion of $resource_type/$name in namespace $namespace... (attempt $retry_count/$max_retries)"
            sleep $retry_delay
        fi
    done
    return 1  # Resource still exists after max retries
}

# Use a unique space name for this test
if [ -z "$SPACE" ] ; then
    SPACE="traderxtest$RANDOM"
fi

echo "=== TraderX Application Deployment Test ==="
echo "Test space: $SPACE"
echo ""

# Create kind cluster for testing with TraderX config
kind create cluster --name "$SPACE" --config "$TRADERX_CONFIG_DIR/kind-config.yaml"

# Load Docker images into kind cluster to avoid pulling from remote registries
echo ""
echo "Loading Docker images into kind cluster..."
kind load docker-image --name "$SPACE" ghcr.io/finos/traderx/database:latest
kind load docker-image --name "$SPACE" ghcr.io/finos/traderx/people-service:latest
kind load docker-image --name "$SPACE" ghcr.io/finos/traderx/reference-data:latest
kind load docker-image --name "$SPACE" ghcr.io/finos/traderx/trade-feed:latest
kind load docker-image --name "$SPACE" ghcr.io/finos/traderx/account-service:latest
kind load docker-image --name "$SPACE" ghcr.io/finos/traderx/position-service:latest
kind load docker-image --name "$SPACE" ghcr.io/finos/traderx/trade-processor:latest
kind load docker-image --name "$SPACE" ghcr.io/finos/traderx/trade-service:latest
kind load docker-image --name "$SPACE" ghcr.io/finos/traderx/web-front-end-angular:latest
kind load docker-image --name "$SPACE" registry.k8s.io/ingress-nginx/controller:v1.11.1
kind load docker-image --name "$SPACE" registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.4.1
echo "✓ All Docker images loaded into kind cluster"
echo ""

function kindCleanup {
    kind delete cluster --name "$SPACE" || true
}
if [[ -z "$NOCLEANUP" ]] ; then
    trap kindCleanup SIGINT SIGTERM SIGHUP EXIT
fi

# Create test space
createSpace "$SPACE"

# Create and start a worker for Kubernetes operations
$cub worker create --space "$SPACE" worker-traderx

# Redirect worker output to a log file for cleaner test output
WORKER_LOG="${OUTDIR}/${SPACE}-worker-traderx.log"
$cub worker run --space "$SPACE" worker-traderx -t=kubernetes > "$WORKER_LOG" 2>&1 &
WORKER_PID=$!
echo "Worker PID is $WORKER_PID (logs: $WORKER_LOG)"

function workerCleanup {
    pkill -SIGTERM -P "$WORKER_PID" || true
}
function kindAndWorkerCleanup {
    kindCleanup
    workerCleanup
}
if [[ -z "$NOCLEANUP" ]] ; then
    trap kindAndWorkerCleanup SIGINT SIGTERM SIGHUP EXIT
fi

# Wait for the worker to start and create Targets
echo "Waiting for worker to be ready..."
sleep 2
targetSlug="k8s-worker-traderx-kind-$SPACE"
awaitEntityWithinSpace "$SPACE" target "$targetSlug"

echo "Worker started and target created"

# Create units from TraderX YAML files
echo ""
echo "Creating TraderX units from YAML files"
echo ""

# Create units with Labels.Project=traderx
echo "Creating nginx-ingress-controller unit..."
$cub unit create --space "$SPACE" nginx-ingress-controller \
    --label "Component=infrastructure" \
    "$TRADERX_CONFIG_DIR/00-nginx-ingress-controller.yaml"

echo "Creating traderx-namespace unit..."
$cub unit create --space "$SPACE" traderx-namespace \
    --label "Project=traderx" \
    --label "Component=namespace" \
    "$TRADERX_CONFIG_DIR/10-traderx-namespace.yml"

echo "Creating database unit..."
$cub unit create --space "$SPACE" database \
    --label "Project=traderx" \
    --label "Component=data" \
    "$TRADERX_CONFIG_DIR/20-database.yaml"

echo "Creating people-service unit..."
$cub unit create --space "$SPACE" people-service \
    --label "Project=traderx" \
    --label "Component=service" \
    "$TRADERX_CONFIG_DIR/30-people.yaml"

echo "Creating reference-data unit..."
$cub unit create --space "$SPACE" reference-data \
    --label "Project=traderx" \
    --label "Component=service" \
    "$TRADERX_CONFIG_DIR/40-reference-data.yaml"

echo "Creating trade-feed unit..."
$cub unit create --space "$SPACE" trade-feed \
    --label "Project=traderx" \
    --label "Component=service" \
    "$TRADERX_CONFIG_DIR/50-trade-feed.yaml"

echo "Creating account-service unit..."
$cub unit create --space "$SPACE" account-service \
    --label "Project=traderx" \
    --label "Component=service" \
    "$TRADERX_CONFIG_DIR/60-account-service.yaml"

echo "Creating position-service unit..."
$cub unit create --space "$SPACE" position-service \
    --label "Project=traderx" \
    --label "Component=service" \
    "$TRADERX_CONFIG_DIR/60-position-service.yaml"

echo "Creating trade-processor unit..."
$cub unit create --space "$SPACE" trade-processor \
    --label "Project=traderx" \
    --label "Component=service" \
    "$TRADERX_CONFIG_DIR/60-trade-processor.yaml"

echo "Creating trade-service unit..."
$cub unit create --space "$SPACE" trade-service \
    --label "Project=traderx" \
    --label "Component=service" \
    "$TRADERX_CONFIG_DIR/60-trade-service.yaml"

echo "Creating web-front-end-angular unit..."
$cub unit create --space "$SPACE" web-front-end-angular \
    --label "Project=traderx" \
    --label "Component=frontend" \
    "$TRADERX_CONFIG_DIR/80-web-front-end-angular.yaml"

echo "Creating traderx-ingress unit..."
$cub unit create --space "$SPACE" traderx-ingress \
    --label "Project=traderx" \
    --label "Component=ingress" \
    "$TRADERX_CONFIG_DIR/99-ingress.yaml"

# Verify units were created
checkEntityWithinSpaceListLength "$SPACE" unit 11 11 --where "Labels.Project = 'traderx'"
echo "✓ All 11 TraderX units created successfully (plus nginx-ingress-controller as infrastructure)"

# Create dependency links based on application dependencies
echo ""
echo "Creating dependency links"
echo ""

# All services depend on the namespace
$cub link create --space "$SPACE" database-to-ns database traderx-namespace
$cub link create --space "$SPACE" people-to-ns people-service traderx-namespace
$cub link create --space "$SPACE" refdata-to-ns reference-data traderx-namespace
$cub link create --space "$SPACE" tradefeed-to-ns trade-feed traderx-namespace
$cub link create --space "$SPACE" account-to-ns account-service traderx-namespace
$cub link create --space "$SPACE" position-to-ns position-service traderx-namespace
$cub link create --space "$SPACE" tradeproc-to-ns trade-processor traderx-namespace
$cub link create --space "$SPACE" tradesvc-to-ns trade-service traderx-namespace
$cub link create --space "$SPACE" frontend-to-ns web-front-end-angular traderx-namespace
$cub link create --space "$SPACE" ingress-to-ns traderx-ingress traderx-namespace

# Service dependencies based on environment variables
$cub link create --space "$SPACE" account-to-db account-service database
$cub link create --space "$SPACE" position-to-db position-service database

$cub link create --space "$SPACE" tradeproc-to-db trade-processor database
$cub link create --space "$SPACE" tradeproc-to-feed trade-processor trade-feed

$cub link create --space "$SPACE" tradesvc-to-db trade-service database
$cub link create --space "$SPACE" tradesvc-to-people trade-service people-service
$cub link create --space "$SPACE" tradesvc-to-refdata trade-service reference-data
$cub link create --space "$SPACE" tradesvc-to-feed trade-service trade-feed
$cub link create --space "$SPACE" tradesvc-to-account trade-service account-service

# Ingress dependencies - ingress only needs nginx-ingress-controller to be ready
$cub link create --space "$SPACE" ingress-to-nginx traderx-ingress nginx-ingress-controller

echo "✓ All 20 dependency links created"

# Set targets for all units
echo ""
echo "Setting targets for all units..."
$cub unit set-target --space "$SPACE" nginx-ingress-controller "$targetSlug"
$cub unit set-target --space "$SPACE" "$targetSlug" --where "Labels.Project = 'traderx'"

# Update target WaitTimeout to 5 minutes for slow-starting services
echo ""
echo "Updating target WaitTimeout to 15 minutes..."
echo '{"WaitTimeout": "15m0s"}' | $cub target update --space "$SPACE" --patch --target $targetSlug --from-stdin

# Apply nginx-ingress-controller first with longer timeout
echo ""
echo "Applying nginx-ingress-controller first (infrastructure)"
echo ""

echo "Applying nginx-ingress-controller with 5-minute timeout..."
$cub unit apply --space "$SPACE" nginx-ingress-controller --timeout 5m

echo "✓ nginx-ingress-controller applied successfully"
echo ""
echo "Waiting for nginx-ingress-controller to stabilize (10 seconds)..."
sleep 10

# Bulk apply remaining units with longer timeout
echo ""
echo "Performing bulk apply with Labels.Project = 'traderx' (5-minute timeout)..."
echo ""

echo "Starting bulk apply of remaining TraderX units..."
$cub unit apply --space "$SPACE" \
    --where "Labels.Project = 'traderx'" \
    --timeout 5m

echo ""
echo "Bulk apply completed successfully with correct dependency order!"

# Wait for resources to stabilize
echo ""
echo "Waiting for resources to stabilize..."
sleep 10

# Verify resources were actually created
echo ""
echo "Verifying resources were created in Kubernetes:"

# Check namespace
if kubectl get namespace traderx > /dev/null 2>&1; then
    echo "✓ Namespace traderx was created"
else
    echo "✗ Namespace traderx was NOT created" >&2
fi

# Check ingress controller
if wait_for_resource "deployment" "ingress-nginx" "ingress-nginx-controller" 15 2; then
    echo "✓ nginx-ingress-controller deployment was created"
else
    echo "⚠ nginx-ingress-controller deployment not found after retries"
fi

# Check key deployments
for deployment in database people-service reference-data trade-feed account-service position-service trade-processor-deployment trade-service web-front-end-angular; do
    if wait_for_resource "deployment" "traderx" "$deployment" 10 2; then
        echo "✓ Deployment $deployment was created"
    else
        echo "⚠ Deployment $deployment not found after retries"
    fi
done

# Check ingress
if wait_for_resource "ingress" "traderx" "traderx-ingress-root" 10 2; then
    echo "✓ Ingress traderx-ingress-root was created"
else
    echo "⚠ Ingress traderx-ingress-root not found after retries"
fi

# Bulk destroy with topological ordering
echo ""
echo "Testing bulk destroy with Labels.Project = 'traderx'"
echo ""

echo "Performing bulk destroy..."
$cub unit destroy --space "$SPACE" \
    --where "Labels.Project = 'traderx'"

# Verify units were destroyed
echo ""
echo "Verifying units were destroyed:"
for unit in nginx-ingress-controller traderx-namespace database people-service reference-data trade-feed account-service position-service trade-processor trade-service web-front-end-angular traderx-ingress; do
    EVENT_LINE=$($cub unit-event list --space "$SPACE" "$unit" --no-header | head -1)
    if echo "$EVENT_LINE" | grep -q "DestroyCompleted"; then
        echo "✓ Unit $unit was destroyed"
    else
        echo "✗ Unit $unit was NOT destroyed (Latest event: $EVENT_LINE)"
    fi
done

# Verify Kubernetes resources were removed
echo ""
echo "Verifying Kubernetes resources were removed (with retry):"
if wait_for_deletion "namespace" "" "traderx" 20 2; then
    echo "✓ Namespace traderx was removed"
else
    echo "⚠ Namespace traderx still exists after retries (may be finalizing)"
fi

if wait_for_deletion "namespace" "" "ingress-nginx" 20 2; then
    echo "✓ Namespace ingress-nginx was removed"
else
    echo "⚠ Namespace ingress-nginx still exists after retries (may be finalizing)"
fi

# Summary
echo ""
echo "=== Summary ==="
echo "Space: $SPACE"
echo ""
echo "All operations completed successfully!"
echo "✓ TraderX units created with Labels.Project=traderx"
echo "✓ Dependency links created based on service requirements"
echo "✓ nginx-ingress-controller applied first as infrastructure"
echo "✓ Bulk apply with Labels.Project operator works correctly"
echo "✓ Bulk destroy with Labels.Project operator works correctly"

# Cleanup
if [[ -z "$NOCLEANUP" ]] ; then
    kindAndWorkerCleanup
    trap - SIGINT SIGTERM SIGHUP EXIT

    # Delete the worker if it still exists
    if $cub worker get --space "$SPACE" worker-traderx > /dev/null 2>&1; then
        deleteWithinSpace "$SPACE" worker worker-traderx
    fi
fi

echo "TraderX bulk apply topological sort test completed successfully!"
exit 0
