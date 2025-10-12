#!/bin/bash
# cub-test-framework.sh - ConfigHub CLI Testing Framework
#
# General-purpose testing framework for validating cub CLI usage.
# Ensures syntactic correctness, grammatical correctness (WHERE clauses),
# semantic correctness (pre/post conditions), and error detection.
#
# This framework can be used with any ConfigHub project and will eventually
# be moved to devops-sdk for general use.

# Color output for test results
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
CUB_TEST_TOTAL=0
CUB_TEST_PASSED=0
CUB_TEST_FAILED=0
CUB_TEST_SKIPPED=0

# Test results array
declare -a CUB_TEST_RESULTS

# Enable debug mode
CUB_TEST_DEBUG=${CUB_TEST_DEBUG:-false}

#============================================================================
# CORE TEST FUNCTIONS
#============================================================================

# Start a test
# Usage: cub_test_start "Test description"
function cub_test_start {
    local description="$1"
    CUB_TEST_TOTAL=$((CUB_TEST_TOTAL + 1))
    if [ "$CUB_TEST_DEBUG" = "true" ]; then
        echo -e "${YELLOW}[TEST $CUB_TEST_TOTAL]${NC} $description"
    fi
}

# Mark test as passed
# Usage: cub_test_pass "Success message"
function cub_test_pass {
    local message="$1"
    CUB_TEST_PASSED=$((CUB_TEST_PASSED + 1))
    CUB_TEST_RESULTS+=("PASS: $message")
    echo -e "${GREEN}✓${NC} $message"
}

# Mark test as failed
# Usage: cub_test_fail "Failure message"
function cub_test_fail {
    local message="$1"
    CUB_TEST_FAILED=$((CUB_TEST_FAILED + 1))
    CUB_TEST_RESULTS+=("FAIL: $message")
    echo -e "${RED}✗${NC} $message"
}

# Mark test as skipped
# Usage: cub_test_skip "Skip reason"
function cub_test_skip {
    local message="$1"
    CUB_TEST_SKIPPED=$((CUB_TEST_SKIPPED + 1))
    CUB_TEST_RESULTS+=("SKIP: $message")
    echo -e "${YELLOW}⊘${NC} $message"
}

# Print test summary
function cub_test_summary {
    echo ""
    echo "=================================================="
    echo "Test Summary"
    echo "=================================================="
    echo "Total:   $CUB_TEST_TOTAL"
    echo -e "${GREEN}Passed:  $CUB_TEST_PASSED${NC}"
    echo -e "${RED}Failed:  $CUB_TEST_FAILED${NC}"
    echo -e "${YELLOW}Skipped: $CUB_TEST_SKIPPED${NC}"
    echo "=================================================="

    if [ $CUB_TEST_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        return 1
    fi
}

#============================================================================
# SYNTAX VALIDATION
#============================================================================

# IMPORTANT: Understanding Unit Data vs Unit Metadata (FROM BRIAN'S FEEDBACK)
#
# ConfigHub Units have two parts:
# 1. METADATA - Unit-level fields (Slug, Labels, Annotations, Description, etc.)
# 2. DATA - The actual config content (YAML/JSON/etc.) stored as an opaque blob
#
# How to UPDATE them:
#
# METADATA Updates (labels, annotations, etc.):
#   ✅ cub unit update myunit --patch --label version=2.0 --space dev
#   ✅ cub unit update --patch --upgrade --space staging (push-upgrade)
#
# DATA Updates - MONOLITHIC (whole blob):
#   ✅ cub unit update myunit myfile.yaml --space dev
#   ✅ echo '{"spec":...}' | cub unit update myunit --from-stdin --space dev
#   ✅ cub unit update myunit --filename newdata.yaml --space dev
#
# DATA Updates - FINE-GRAINED (specific fields):
#   ✅ cub function do --space dev --where "Slug = 'myunit'" set-replicas 3
#   ✅ cub function do --space dev set-image nginx nginx:1.21
#   ✅ cub function do --space dev yq '.spec.replicas = 3'
#
# INVALID Patterns:
#   ❌ cub unit update --patch '{"spec":{"replicas":3}}'
#      (inline JSON as positional arg - Brian: "You're passing that data patch as the unit slug")
#   ❌ cub unit update --patch (without companion flags like --from-stdin, --label, etc.)
#   ❌ --where "Data.spec.replicas > 2" (WHERE clauses can't query Data contents)

# Validate cub command syntax
# Usage: validate_cub_syntax "cub unit create myunit config.yaml --space dev"
# Returns: 0 if valid, 1 if invalid, sets CUB_SYNTAX_ERROR
function validate_cub_syntax {
    local command="$1"
    CUB_SYNTAX_ERROR=""

    # Check if command starts with "cub"
    if ! echo "$command" | grep -q "^cub "; then
        CUB_SYNTAX_ERROR="Command must start with 'cub'"
        return 1
    fi

    # Extract entity type (second word)
    local entity=$(echo "$command" | awk '{print $2}')

    # Extract verb (third word)
    local verb=$(echo "$command" | awk '{print $3}')

    # Validate entity type
    local valid_entities="space unit filter set link changeset revision target worker function auth context dataset"
    if ! echo "$valid_entities" | grep -qw "$entity"; then
        CUB_SYNTAX_ERROR="Invalid entity type: $entity"
        return 1
    fi

    # Validate verb for entity
    case "$entity" in
        space)
            local valid_verbs="create get list update delete new-prefix"
            ;;
        unit)
            local valid_verbs="create get list update delete apply destroy tree diff set-target get-live-state push-upgrade"
            ;;
        filter)
            local valid_verbs="create get list update delete"
            ;;
        function)
            local valid_verbs="do list explain"
            ;;
        *)
            local valid_verbs="create get list update delete"
            ;;
    esac

    if ! echo "$valid_verbs" | grep -qw "$verb"; then
        CUB_SYNTAX_ERROR="Invalid verb '$verb' for entity '$entity'. Valid: $valid_verbs"
        return 1
    fi

    # Check for --patch without required flags (FROM BRIAN'S FEEDBACK)
    # --patch must be paired with one of: --from-stdin, --filename, --restore, --upgrade,
    # --merge-source, --label, --delete-gate, --destroy-gate, or --changeset
    if echo "$command" | grep -q "\-\-patch"; then
        if ! echo "$command" | grep -qE "\-\-(from-stdin|filename|restore|upgrade|merge-source|label|delete-gate|destroy-gate|changeset)"; then
            CUB_SYNTAX_ERROR="--patch requires one of: --from-stdin, --filename, --restore, --upgrade, --merge-source, --label, --delete-gate, --destroy-gate, or --changeset"
            return 1
        fi
    fi

    # Check for inline JSON being passed incorrectly (FROM BRIAN'S FEEDBACK)
    # The error: cub unit update --space "*" --where "..." --patch '{"spec":{"replicas":3}}'
    # Problem: The JSON is a positional argument (interpreted as unit slug), not proper --from-stdin
    # Correct ways:
    #   1. For monolithic Data update: echo '{"spec":...}' | cub unit update myunit --space dev --from-stdin
    #   2. For fine-grained changes: cub function do --space dev --where "Slug = 'myunit'" set-replicas 3
    if echo "$command" | grep -qE "\-\-patch +['\"]?\{"; then
        CUB_SYNTAX_ERROR="Cannot pass inline JSON with --patch. Use --from-stdin (with pipe/heredoc) or --filename. For fine-grained Data changes, use 'cub function do' instead"
        return 1
    fi

    # Check for --space with value
    if echo "$command" | grep -q "\-\-space" && ! echo "$command" | grep -qE "\-\-space +[^ ]"; then
        CUB_SYNTAX_ERROR="--space requires a value"
        return 1
    fi

    return 0
}

# Test if a command is syntactically valid
# Usage: test_cub_syntax "cub unit create..." "Description"
function test_cub_syntax {
    local command="$1"
    local description="$2"

    cub_test_start "$description"

    if validate_cub_syntax "$command"; then
        cub_test_pass "Syntax valid: $description"
        return 0
    else
        cub_test_fail "Syntax invalid: $description - $CUB_SYNTAX_ERROR"
        return 1
    fi
}

#============================================================================
# WHERE CLAUSE GRAMMAR VALIDATION
#============================================================================

# Validate WHERE clause against EBNF grammar
# Usage: validate_where_clause "Slug = 'myunit'"
# Returns: 0 if valid, 1 if invalid, sets WHERE_CLAUSE_ERROR
function validate_where_clause {
    local where_clause="$1"
    WHERE_CLAUSE_ERROR=""

    # Empty WHERE clause is invalid
    if [ -z "$where_clause" ]; then
        WHERE_CLAUSE_ERROR="WHERE clause cannot be empty"
        return 1
    fi

    # Check for unsupported OR operator
    if echo "$where_clause" | grep -iq " OR "; then
        WHERE_CLAUSE_ERROR="OR operator not supported, use AND for conjunctions"
        return 1
    fi

    # Validate operators
    local valid_operators="<= >= < > = != LIKE ILIKE ~~ !~~ ~ ~\* !~ !~\* IN NOT IN ?"

    # Check for invalid wildcard usage (FROM BRIAN'S FEEDBACK)
    # Wildcards like "*" cannot be used as attribute values in most contexts
    if echo "$where_clause" | grep -qE "= +['\"]?\*['\"]?"; then
        WHERE_CLAUSE_ERROR="Wildcard '*' cannot be used as a value in WHERE clause"
        return 1
    fi

    # Check for valid attribute names (PascalCase, 1-41 characters)
    # Common valid attributes: Slug, DisplayName, CreatedAt, UpdatedAt, Labels.key, Space.Labels.key
    local attribute_pattern='[A-Z][A-Za-z0-9]*(\.[A-Za-z0-9][A-Za-z0-9\-_\.\/]*[A-Za-z0-9])?'

    # Check for string literals properly quoted
    # String literals must use single quotes
    if echo "$where_clause" | grep -qE '= *"[^"]*"'; then
        WHERE_CLAUSE_ERROR="String literals must use single quotes, not double quotes"
        return 1
    fi

    # Check for CONTAINS operator (not supported - FROM BRIAN'S FEEDBACK)
    if echo "$where_clause" | grep -qi "CONTAINS"; then
        WHERE_CLAUSE_ERROR="CONTAINS operator not supported. Use LIKE or ~ (regex) instead"
        return 1
    fi

    # Check for Data field queries (not directly supported)
    if echo "$where_clause" | grep -qiE "Data\.(spec|metadata|kind|apiVersion)"; then
        WHERE_CLAUSE_ERROR="Cannot query Data fields directly in WHERE clause. Data queries not supported"
        return 1
    fi

    # Check maximum length (4096 characters)
    if [ ${#where_clause} -gt 4096 ]; then
        WHERE_CLAUSE_ERROR="WHERE clause exceeds maximum length of 4096 characters"
        return 1
    fi

    # If we get here, basic validation passed
    return 0
}

# Test if a WHERE clause is valid
# Usage: test_where_clause "Slug = 'myunit'" "Description"
function test_where_clause {
    local where_clause="$1"
    local description="$2"

    cub_test_start "$description"

    if validate_where_clause "$where_clause"; then
        cub_test_pass "WHERE clause valid: $description"
        return 0
    else
        cub_test_fail "WHERE clause invalid: $description - $WHERE_CLAUSE_ERROR"
        return 1
    fi
}

#============================================================================
# SEMANTIC VALIDATION (PRE/POST CONDITIONS)
#============================================================================

# Define a semantic test with pre/post conditions
# Usage: semantic_test "operation_name" "English description" "pre_condition_func" "operation_func" "post_condition_func"
function semantic_test {
    local operation="$1"
    local description="$2"
    local pre_check="$3"
    local operation_func="$4"
    local post_check="$5"

    cub_test_start "Semantic: $description"

    # Check pre-condition
    if ! $pre_check; then
        cub_test_fail "Pre-condition failed for: $description"
        return 1
    fi

    # Execute operation
    if ! $operation_func; then
        cub_test_fail "Operation failed for: $description"
        return 1
    fi

    # Check post-condition
    if ! $post_check; then
        cub_test_fail "Post-condition failed for: $description"
        return 1
    fi

    cub_test_pass "Semantic test passed: $description"
    return 0
}

# Example semantic test functions (users can define their own)

# Pre-condition: Space exists
function pre_space_exists {
    local space="$1"
    cub space get "$space" &>/dev/null
}

# Pre-condition: Unit does not exist
function pre_unit_not_exists {
    local space="$1"
    local unit="$2"
    ! cub unit get "$unit" --space "$space" &>/dev/null
}

# Post-condition: Unit exists
function post_unit_exists {
    local space="$1"
    local unit="$2"
    cub unit get "$unit" --space "$space" &>/dev/null
}

# Post-condition: Unit has N replicas
function post_unit_replicas {
    local space="$1"
    local unit="$2"
    local expected_replicas="$3"

    local actual=$(cub function do --space "$space" --where "Slug = '$unit'" --quiet --output-only yq '.spec.replicas' 2>/dev/null)
    [ "$actual" = "$expected_replicas" ]
}

#============================================================================
# ERROR DETECTION
#============================================================================

# Check for common cub command errors
# Usage: detect_common_errors "cub command"
# Returns: 0 if no errors, 1 if errors found, sets CUB_COMMON_ERRORS (array)
declare -a CUB_COMMON_ERRORS

function detect_common_errors {
    local command="$1"
    CUB_COMMON_ERRORS=()

    # Error 1: Using --patch without required flags
    if echo "$command" | grep -q "\-\-patch"; then
        if ! echo "$command" | grep -qE "\-\-(from-stdin|filename|restore|upgrade|merge-source|label|delete-gate|destroy-gate|changeset)"; then
            CUB_COMMON_ERRORS+=("--patch requires additional flags")
        fi
    fi

    # Error 2: Inline JSON passed to --patch (positional argument error)
    # FROM BRIAN: "You're passing that data patch (which isn't a thing you can pass to
    # update) as the unit slug. And there's no specification of what to update."
    if echo "$command" | grep -qE "\-\-patch +['\"]?\{"; then
        CUB_COMMON_ERRORS+=("Inline JSON with --patch is invalid. Use --from-stdin (with pipe) or use 'cub function do' for fine-grained changes")
    fi

    # Error 3: Invalid wildcard in --space
    if echo "$command" | grep -qE "\-\-space +['\"]?\*['\"]?.*\-\-where +['\"]?\*['\"]?"; then
        CUB_COMMON_ERRORS+=("Cannot use '*' in both --space and --where")
    fi

    # Error 4: CONTAINS in WHERE clause
    if echo "$command" | grep -qi "CONTAINS"; then
        CUB_COMMON_ERRORS+=("CONTAINS not supported in WHERE clauses")
    fi

    # Error 5: Data field queries (FROM BRIAN'S FEEDBACK)
    # Brian said: "Data CONTAINS 'replicas:' AND replicas > 2" doesn't work
    # WHERE clauses operate on Unit metadata, not config Data contents
    if echo "$command" | grep -qiE "\-\-where.*Data\.(spec|metadata)"; then
        CUB_COMMON_ERRORS+=("Cannot query Data fields in WHERE clause (Data is opaque to ConfigHub queries)")
    fi

    # Error 6: Double quotes for string literals
    if echo "$command" | grep -qE "\-\-where.*= *\""; then
        CUB_COMMON_ERRORS+=("Use single quotes for string literals in WHERE clauses")
    fi

    # Error 7: Missing --space flag when required
    if echo "$command" | grep -qE "^cub (unit|filter|set|link) (get|list|create|update|delete)"; then
        if ! echo "$command" | grep -qE "\-\-space"; then
            CUB_COMMON_ERRORS+=("--space flag required for this command")
        fi
    fi

    # Return status
    if [ ${#CUB_COMMON_ERRORS[@]} -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Test for common errors
# Usage: test_no_common_errors "cub command" "Description"
function test_no_common_errors {
    local command="$1"
    local description="$2"

    cub_test_start "$description"

    if detect_common_errors "$command"; then
        cub_test_pass "No common errors: $description"
        return 0
    else
        local errors=$(IFS=", "; echo "${CUB_COMMON_ERRORS[*]}")
        cub_test_fail "Common errors found: $description - $errors"
        return 1
    fi
}

#============================================================================
# INTEGRATION TESTING HELPERS
#============================================================================

# Execute a cub command and validate it succeeds
# Usage: exec_cub_success "cub space create myspace" "Create space"
function exec_cub_success {
    local command="$1"
    local description="$2"

    cub_test_start "$description"

    local output
    local exit_code

    output=$(eval "$command" 2>&1)
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        cub_test_pass "Command succeeded: $description"
        return 0
    else
        cub_test_fail "Command failed: $description - Exit code: $exit_code, Output: $output"
        return 1
    fi
}

# Execute a cub command and validate it fails
# Usage: exec_cub_failure "cub unit get nonexistent --space dev" "Get nonexistent unit"
function exec_cub_failure {
    local command="$1"
    local description="$2"
    local expected_error="${3:-}"

    cub_test_start "$description"

    local output
    local exit_code

    output=$(eval "$command" 2>&1)
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        if [ -n "$expected_error" ]; then
            if echo "$output" | grep -q "$expected_error"; then
                cub_test_pass "Command failed as expected with correct error: $description"
                return 0
            else
                cub_test_fail "Command failed but with wrong error: $description - Expected: '$expected_error', Got: '$output'"
                return 1
            fi
        else
            cub_test_pass "Command failed as expected: $description"
            return 0
        fi
    else
        cub_test_fail "Command should have failed but succeeded: $description"
        return 1
    fi
}

#============================================================================
# COMMAND SCANNING
#============================================================================

# Scan a shell script for all cub commands
# Usage: scan_script_for_cub "path/to/script.sh"
# Returns: Array of cub commands found
declare -a SCANNED_CUB_COMMANDS

function scan_script_for_cub {
    local script="$1"
    SCANNED_CUB_COMMANDS=()

    if [ ! -f "$script" ]; then
        echo "Script not found: $script" >&2
        return 1
    fi

    # Find all lines with cub commands (handle line continuations)
    while IFS= read -r line; do
        # Skip comments
        if echo "$line" | grep -q "^[[:space:]]*#"; then
            continue
        fi

        # Extract cub commands
        if echo "$line" | grep -q "cub "; then
            local command=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            SCANNED_CUB_COMMANDS+=("$command")
        fi
    done < "$script"

    echo "Found ${#SCANNED_CUB_COMMANDS[@]} cub commands in $script"
}

# Validate all cub commands in a script
# Usage: validate_script_cub_commands "path/to/script.sh"
function validate_script_cub_commands {
    local script="$1"
    local script_name=$(basename "$script")

    echo "Validating cub commands in $script_name..."

    scan_script_for_cub "$script"

    local all_valid=true
    for command in "${SCANNED_CUB_COMMANDS[@]}"; do
        if ! validate_cub_syntax "$command"; then
            echo -e "${RED}Invalid:${NC} $command"
            echo -e "${RED}Error:${NC} $CUB_SYNTAX_ERROR"
            all_valid=false
        fi

        if ! detect_common_errors "$command"; then
            echo -e "${RED}Common errors:${NC} $command"
            for error in "${CUB_COMMON_ERRORS[@]}"; do
                echo -e "${RED}  - $error${NC}"
            done
            all_valid=false
        fi
    done

    if $all_valid; then
        echo -e "${GREEN}All cub commands valid in $script_name${NC}"
        return 0
    else
        echo -e "${RED}Some cub commands invalid in $script_name${NC}"
        return 1
    fi
}

#============================================================================
# UTILITY FUNCTIONS
#============================================================================

# Print framework version
function cub_test_version {
    echo "cub-test-framework.sh v1.0.0"
    echo "ConfigHub CLI Testing Framework"
}

# Print usage
function cub_test_usage {
    cat <<EOF
ConfigHub CLI Testing Framework

Usage:
  source test/lib/cub-test-framework.sh

Test Functions:
  cub_test_start <description>                 - Start a test
  cub_test_pass <message>                      - Mark test as passed
  cub_test_fail <message>                      - Mark test as failed
  cub_test_skip <message>                      - Mark test as skipped
  cub_test_summary                             - Print test summary

Validation Functions:
  validate_cub_syntax <command>                - Validate command syntax
  test_cub_syntax <command> <description>      - Test command syntax

  validate_where_clause <clause>               - Validate WHERE clause
  test_where_clause <clause> <description>     - Test WHERE clause

  semantic_test <op> <desc> <pre> <op> <post>  - Semantic test with pre/post

  detect_common_errors <command>               - Detect common errors
  test_no_common_errors <command> <desc>       - Test for no common errors

Integration Functions:
  exec_cub_success <command> <description>     - Execute expecting success
  exec_cub_failure <command> <description>     - Execute expecting failure

Scanning Functions:
  scan_script_for_cub <script>                 - Scan script for cub commands
  validate_script_cub_commands <script>        - Validate all commands in script

Environment Variables:
  CUB_TEST_DEBUG=true                          - Enable debug output

Example:
  source test/lib/cub-test-framework.sh
  test_cub_syntax "cub space create myspace" "Create space command"
  test_where_clause "Slug = 'myunit'" "Simple equality"
  cub_test_summary
EOF
}

# Export functions for use in test scripts
export -f cub_test_start cub_test_pass cub_test_fail cub_test_skip cub_test_summary
export -f validate_cub_syntax test_cub_syntax
export -f validate_where_clause test_where_clause
export -f semantic_test pre_space_exists pre_unit_not_exists post_unit_exists post_unit_replicas
export -f detect_common_errors test_no_common_errors
export -f exec_cub_success exec_cub_failure
export -f scan_script_for_cub validate_script_cub_commands
export -f cub_test_version cub_test_usage

echo "cub-test-framework.sh loaded successfully"
