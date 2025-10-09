# Source this file in your test script

cub="bin/cub"

# Use a random space name unless a specific space is specified.
if [ -z "$SPACE" ] ; then
    SPACE="space$RANDOM"
fi

# Name of the kubecontext for which to create a target.
if [ -z "$KUBECONTEXT" ] ; then
    KUBECONTEXT="kind-kind"
fi

# Name of the directory to put output of commands.
if [ -z "$OUTDIR" ] ; then
    OUTDIR="test/out"
fi
mkdir -p "${OUTDIR}"

# Ensure we see the space in a list of the spaces.
function verifySpaceExists {
    space="$1"
    shift 1
    if ! $cub space list --no-header | grep -q "$space" ; then
        echo "$space" not found in list >&2
        exit 1
    fi
    if ! $cub space get --json "$space" 2>&1 > /dev/null ; then
        echo "$space" not found with get >&2
        exit 1
    fi
}

# Ensure that we can the specified entity within the specified space.
# Additional arguments can be passed to the get command.
function getEntityWithinSpace {
    space="$1"
    entityType="$2"
    entityName="$3"
    case="$4"
    shift 4
    $cub "$entityType" get --space "$space" --json "$entityName" "$@" > "${OUTDIR}/get-${case}-${entityType}-${entityName}.txt"
}

# Ensure we see the entity within the specified space.
function verifyEntityWithinSpaceExists {
    space="$1"
    entityType="$2"
    entityName="$3"
    shift 3
    if ! $cub "$entityType" list --space "$space" --no-header | grep -q "$entityName" ; then
        echo "$entityName" of type "$entityType" not found in list >&2
        exit 1
    fi
    if ! $cub "$entityType" get --space "$space" --json "$entityName" 2>&1 > /dev/null ; then
        echo "$entityName" of type "$entityType" not found with get >&2
        exit 1
    fi
}

# Ensure we don't see the entity within the specified space.
function verifyEntityWithinSpaceDoesNotExist {
    space="$1"
    entityType="$2"
    entityName="$3"
    shift 3
    if $cub "$entityType" list --space "$space" --no-header --names | grep -q "$entityName" ; then
        echo "$entityName" of type "$entityType" found in list >&2
        exit 1
    fi
    if $cub "$entityType" get --space "$space" --json "$entityName" 2>&1 > /dev/null ; then
        echo "$entityName" of type "$entityType" found with get >&2
        exit 1
    fi
}

function awaitEntityWithinSpace {
    space="$1"
    entityType="$2"
    entityName="$3"
    shift 3
    while ! $cub "$entityType" get --space "$space" --json "$entityName" 2>&1 > /dev/null ; do
        echo Waiting for "$entityName" ...
        sleep 1
    done
}

# There's at least an autoprovisioned personal space. There may be others if the
# database wasn't reset.
spaceCount=1

# No autoprovisioning for these.
setCount=0
triggerCount=0
targetCount=0
linkCount=0
unitCount=0

# Check that the numer of entities listed is within the expected range [min,max].
# Additional arguments can be passed to the list command.
function checkEntityWithinSpaceListLength {
    space="$1"
    entityType="$2"
    min="$3"
    max="$4"
    shift 4
    lines=$($cub "$entityType" list --no-header --space "$space" "$@" 2>&1 | wc -l)
    if [[ $lines -lt $min ]] ; then
        echo Got $lines, expected at least $min from cub "$entityType" list --space "$space" "$@" >&2
        exit 1
    fi
    if [[ $lines -gt $max ]] ; then
        echo Got $lines, expected at most $max from cub "$entityType" list --space "$space" "$@" >&2
        exit 1
    fi
}

function listEntityWithinSpace {
    space="$1"
    entityType="$2"
    case="$3"
    shift 3
    $cub "$entityType" list --no-header --space "$space" "$@" > "${OUTDIR}/list-${entityType}-${case}.txt"
}

# Create a space, verify that it exists, and count its creation.
function createSpace {
    space="$1"
    shift 1
    spaceCount=$(( $spaceCount + 1 ))
    cat test-data/space-metadata.json | $cub space create --verbose --json --from-stdin "$space" > "${OUTDIR}/create-space.txt"
    verifySpaceExists "$space"
}

# Create an entity within the specified space, verify that it exists, and count its creation.
# Additional arguments can be passed to the create command.
function createWithinSpace {
    space="$1"
    entityType="$2"
    entityName="$3"
    shift 3

    # This counts the creation in an env var of the name "fooCount" for entity type "foo".
    # Set the count to the appropriate starting value (usually 0 or 1) above.
    entityTypeCountName="${entityType}Count"
    eval $entityTypeCountName=\$\(\( \$$entityTypeCountName \+ 1 \)\)

    cat test-data/metadata.json | $cub "$entityType" create --space "$space" --verbose --json --from-stdin "$entityName" "$@" > "${OUTDIR}/create-${entityType}-${entityName}.txt"
    verifyEntityWithinSpaceExists "$space" "$entityType" "$entityName"
}

# Create an entity within the specified space, verify that it exists, and count its creation.
# Additional arguments can be passed to the create command.
function createWithinSpaceNoStdin {
    space="$1"
    entityType="$2"
    entityName="$3"
    shift 3

    # This counts the creation in an env var of the name "fooCount" for entity type "foo".
    # Set the count to the appropriate starting value (usually 0 or 1) above.
    entityTypeCountName="${entityType}Count"
    eval $entityTypeCountName=\$\(\( \$$entityTypeCountName \+ 1 \)\)

    $cub "$entityType" create --space "$space" --verbose --json "$entityName" "$@" > "${OUTDIR}/create-${entityType}-${entityName}.txt"
    verifyEntityWithinSpaceExists "$space" "$entityType" "$entityName"
}

# Create a trigger within the specified space, verify that it exists, and count its creation.
# Additional arguments can be passed to the create command.
function createTrigger {
    space="$1"
    entityType=trigger
    entityName="$2"
    event="$3"
    function="$4"
    shift 4
    triggerCount=$(( $triggerCount + 1 ))
    $cub $entityType create --space "$space" --verbose --json $entityName $event Kubernetes/YAML $function "$@" > "${OUTDIR}/create-${entityType}-${entityName}.txt"
    verifyEntityWithinSpaceExists "$space" "$entityType" "$entityName"
}

function updateTrigger {
    space="$1"
    entityType=trigger
    entityName="$2"
    event="$3"
    function="$4"
    shift 4
    $cub $entityType update --space "$space" --verbose --json $entityName $event Kubernetes/YAML $function "$@" > "${OUTDIR}/update-${entityType}-${entityName}.txt"
}

# Update an entity with the specified space and verify that it exists.
# Additional arguments can be passed to the update command.
function updateWithinSpace {
    space="$1"
    entityType="$2"
    entityName="$3"
    case="$4"
    shift 4
    $cub "$entityType" update --space "$space" --verbose --json "$entityName" "$@" > "${OUTDIR}/update-${case}-${entityType}-${entityName}.txt"
    verifyEntityWithinSpaceExists "$space" "$entityType" "$entityName"
}

# Delete an entity with the specified space and verify that it no longer exists.
# Additional arguments can be passed to the delete command.
function deleteWithinSpace {
    space="$1"
    entityType="$2"
    entityName="$3"
    shift 3

    # This counts the creation in an env var of the name "fooCount" for entity type "foo".
    entityTypeCountName="${entityType}Count"
    eval $entityTypeCountName=\$\(\( \$$entityTypeCountName \- 1 \)\)

    $cub "$entityType" delete --space "$space" "$entityName" "$@" > "${OUTDIR}/delete-${entityType}-${entityName}.txt"
    verifyEntityWithinSpaceDoesNotExist "$space" "$entityType" "$entityName"
}

# Execute a specified function within the specified space on a specified unit
# with the specified arguments.
function doUnit {
    space="$1"
    unit="$2"
    function="$3"
    shift 3
    $cub function do --space "$space" --where "Slug = '$unit'" "$function" "$@" > "${OUTDIR}/function-do-${unit}-${function}.txt"
}

# Execute a specified function within the specified space on all units
function doAll {
    space="$1"
    function="$2"
    shift 2
    $cub function do --space "$space" "$function" "$@" > "${OUTDIR}/function-do-all-${function}.txt"
}

function checkUnitConfigValue {
    space="$1"
    unit="$2"
    field="$3"
    value="$4"
    shift 4
    result=$($cub function do --space "$space" --where "Slug = '$unit'" --quiet --output-only yq "$field")
    if [[ "$result" != "$value" ]] ; then
        echo "$result != $value" >&2
        exit 1
    fi
}

# Check if output contains expected error message
# Usage: expectError "output" "expected error message"
function expectError {
    local output="$1"
    local expected_msg="$2"

    if ! echo -n "$output" | grep -zq "$expected_msg"; then
        echo "Expected error message not found:" >&2
        echo "Expected: $expected_msg" >&2
        echo "Got: $output" >&2
        exit 1
    fi
}

# Check if output contains expected HTTP status
# Usage: expectHttpError "output" "status code"
function expectHttpError {
    local output="$1"
    local expected_code="$2"

    if ! echo -n "$output" | grep -zq "HTTP $expected_code"; then
        echo "Expected HTTP status not found:" >&2
        echo "Expected: HTTP $expected_code" >&2
        echo "Got: $output" >&2
        exit 1
    fi
}
