# TraderX Test Scripts

Standard test library and utilities for TraderX integration tests, following ConfigHub conventions.

## test-lib.sh

Standard test library providing common functions for ConfigHub integration tests.

### Usage

```bash
#!/bin/bash -x
set -e

ROOTDIR="$(git rev-parse --show-toplevel)"
testlibsh="$ROOTDIR/test/scripts/test-lib.sh"
source $testlibsh
```

### Standard Variables

- `$cub` - Path to cub CLI (`bin/cub`)
- `$SPACE` - Test space name (defaults to `space$RANDOM`)
- `$KUBECONTEXT` - Kubernetes context (defaults to `kind-kind`)
- `$OUTDIR` - Output directory (defaults to `test/out`)

### Core Functions

#### Space Management
- `createSpace <space>` - Create and verify space
- `verifySpaceExists <space>` - Verify space exists

#### Entity Management
- `createWithinSpace <space> <type> <name> [args...]` - Create entity with metadata
- `verifyEntityWithinSpaceExists <space> <type> <name>` - Verify entity exists
- `verifyEntityWithinSpaceDoesNotExist <space> <type> <name>` - Verify entity deleted
- `awaitEntityWithinSpace <space> <type> <name>` - Wait for entity to exist

#### List Operations
- `checkEntityWithinSpaceListLength <space> <type> <min> <max> [args...]` - Verify list count
- `listEntityWithinSpace <space> <type> <case> [args...]` - List entities to file

#### Update Operations
- `updateWithinSpace <space> <type> <name> [args...]` - Update entity
- `deleteWithinSpace <space> <type> <name>` - Delete entity

### Example Test

```bash
#!/bin/bash -x
set -e

ROOTDIR="$(git rev-parse --show-toplevel)"
testlibsh="$ROOTDIR/test/scripts/test-lib.sh"
source $testlibsh

# Create isolated test space
SPACE="mytest$RANDOM"
createSpace "$SPACE"

# Create unit with labels
cat test-data/metadata.json | $cub unit create \
  --space "$SPACE" \
  --label "Project=traderx" \
  --label "Component=service" \
  --from-stdin my-unit test-data/deployment.yaml

# Verify it was created
verifyEntityWithinSpaceExists "$SPACE" unit my-unit

# Verify count
checkEntityWithinSpaceListLength "$SPACE" unit 1 1

# Clean up
deleteWithinSpace "$SPACE" unit my-unit
verifyEntityWithinSpaceDoesNotExist "$SPACE" unit my-unit

echo "Test passed!"
```

## Best Practices

### 1. Test Isolation
- Use random space names: `SPACE="test$RANDOM"`
- Clean up with trap handlers
- Use kind clusters with unique names

### 2. Error Handling
- Always use `set -e` for immediate error exit
- Use `set -x` for debug output
- Implement cleanup functions with traps

### 3. Test Structure
```bash
#!/bin/bash -x
set -e

# Setup
ROOTDIR="$(git rev-parse --show-toplevel)"
source "$ROOTDIR/test/scripts/test-lib.sh"

SPACE="test$RANDOM"

# Cleanup handlers
function cleanup {
    # Clean up resources
}
trap cleanup SIGINT SIGTERM SIGHUP EXIT

# Test body
createSpace "$SPACE"
# ... test operations ...

echo "Test passed!"
```

### 4. Verification
- Always verify operations succeeded
- Check entity counts
- Verify labels and metadata
- Test both positive and negative cases

### 5. Output
- Save command output to `$OUTDIR`
- Use descriptive filenames
- Enable `-x` for debugging

## References

Based on ConfigHub standard test infrastructure:
- https://github.com/confighubai/confighub/blob/main/test/scripts/test-lib.sh
- https://github.com/confighubai/confighub/tree/main/test/scripts
