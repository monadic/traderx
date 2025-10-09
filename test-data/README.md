# TraderX Test Data

Standard test data and metadata for TraderX integration tests, following ConfigHub conventions.

## Files

### Standard Metadata

- **metadata.json** - Default labels and annotations for test units
  ```json
  {
    "Labels": {
      "Layer": "Application",
      "Tier": "Backend",
      "Otherlabel": "labelvalue"
    },
    "Annotations": {
      "Description": "This is a config unit"
    }
  }
  ```

- **space-metadata.json** - Default metadata for test spaces

### YAML Fixtures

Test YAML files are organized by deployment layer:

#### Layer 0: Namespace
- `10-traderx-namespace.yml` - Namespace definition

#### Layer 1: Data Tier
- `20-database.yaml` - Database deployment and service

#### Layer 2: Core Services
- `30-people.yaml` - People service
- `40-reference-data.yaml` - Reference data service
- `50-trade-feed.yaml` - Trade feed service

#### Layer 3: Trading Services
- `60-account-service.yaml` - Account service
- `60-position-service.yaml` - Position service
- `60-trade-processor.yaml` - Trade processor
- `60-trade-service.yaml` - Trade service

#### Layer 4: Frontend
- `80-web-front-end-angular.yaml` - Web frontend

#### Layer 5: Ingress
- `99-ingress.yaml` - Ingress configuration

### Infrastructure
- `00-nginx-ingress-controller.yaml` - Nginx ingress controller
- `kind-config.yaml` - Kind cluster configuration

## Usage in Tests

```bash
#!/bin/bash -x
set -e

ROOTDIR="$(git rev-parse --show-toplevel)"
testlibsh="$ROOTDIR/test/scripts/test-lib.sh"
source $testlibsh

# Create space with metadata
createSpace "$SPACE"

# Create unit with metadata
cat test-data/metadata.json | $cub unit create --space "$SPACE" \
  --from-stdin my-unit test-data/deployment.yaml
```

## Validation

All YAML files are validated for:
- Valid YAML syntax
- Kubernetes API version
- Required fields (metadata.name, spec, etc.)
- Resource limits and requests
- Security contexts
- Health probes (liveness/readiness)

## References

Based on ConfigHub standard test infrastructure:
- https://github.com/confighubai/confighub/tree/main/test-data
- https://github.com/confighubai/confighub/blob/main/test/scripts/test-lib.sh
