#!/bin/bash
# cub-command-analyzer.sh - ConfigHub cub CLI Command Analyzer
#
# Scans scripts for cub commands and provides comprehensive analysis:
# - Syntax validation
# - Grammar validation (WHERE clauses)
# - Unit test compliance
# - Semantic explanation with pre/post conditions
#
# Usage:
#   ./cub-command-analyzer.sh <file>           # Analyze single file
#   ./cub-command-analyzer.sh <directory>      # Analyze all scripts in directory
#   ./cub-command-analyzer.sh <URL>            # Analyze script from URL (future)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the validation framework
source "$SCRIPT_DIR/test/lib/cub-test-framework.sh"

# Colors for output - only use if outputting to terminal
if [ -t 1 ]; then
    # Output is a terminal (TTY) - use colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    UNDERLINE='\033[4m'
    NC='\033[0m'
else
    # Output is redirected to file - no colors
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    UNDERLINE=''
    NC=''
fi

# Analysis counters
TOTAL_FILES=0
TOTAL_COMMANDS=0
VALID_COMMANDS=0
INVALID_COMMANDS=0

# Output format
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"  # text, json, markdown

#============================================================================
# SEMANTIC EXPLANATION GENERATOR
#============================================================================

# Generate semantic explanation for a cub command
# Returns English description with pre/post conditions
function generate_semantic_explanation {
    local command="$1"
    local entity verb unit_name space_name

    # Extract components
    entity=$(echo "$command" | awk '{print $2}')
    verb=$(echo "$command" | awk '{print $3}')

    # Extract unit name if present (4th arg often)
    unit_name=$(echo "$command" | awk '{print $4}' | sed 's/--.*//;s/[[:space:]]*$//')

    # Extract space name from --space flag (BSD grep compatible)
    space_name=$(echo "$command" | sed -n 's/.*--space[[:space:]]\+\([^[:space:]]*\).*/\1/p' || echo "")

    # Generate explanation based on entity and verb
    case "$entity" in
        space)
            case "$verb" in
                create)
                    echo "Creates a new ConfigHub space named '$unit_name'"
                    echo "  Pre-condition: Space '$unit_name' does not exist"
                    echo "  Post-condition: Space '$unit_name' exists and is accessible"
                    ;;
                get)
                    echo "Retrieves information about space '$unit_name'"
                    echo "  Pre-condition: Space '$unit_name' exists"
                    echo "  Post-condition: Space information returned"
                    ;;
                list)
                    echo "Lists all ConfigHub spaces accessible to the user"
                    echo "  Pre-condition: User is authenticated"
                    echo "  Post-condition: List of spaces returned"
                    ;;
                update)
                    echo "Updates metadata for space '$unit_name'"
                    echo "  Pre-condition: Space '$unit_name' exists"
                    echo "  Post-condition: Space metadata updated"
                    ;;
                delete)
                    echo "Deletes space '$unit_name' and all its contents"
                    echo "  Pre-condition: Space '$unit_name' exists"
                    echo "  Post-condition: Space '$unit_name' no longer exists"
                    ;;
                new-prefix)
                    echo "Generates a unique space prefix for naming (canonical pattern)"
                    echo "  Pre-condition: User is authenticated"
                    echo "  Post-condition: Returns unique prefix like 'chubby-paws'"
                    ;;
                *)
                    echo "Performs '$verb' operation on space '$unit_name'"
                    ;;
            esac
            ;;
        unit)
            case "$verb" in
                create)
                    if echo "$command" | grep -q "\-\-upstream-unit"; then
                        echo "Creates unit '$unit_name' in space '$space_name' with upstream relationship (clone pattern)"
                        echo "  Pre-condition: Space '$space_name' exists, upstream unit exists"
                        echo "  Post-condition: Unit '$unit_name' exists in '$space_name' with upstream link"
                    else
                        echo "Creates a new configuration unit '$unit_name' in space '$space_name'"
                        echo "  Pre-condition: Space '$space_name' exists, unit '$unit_name' does not exist"
                        echo "  Post-condition: Unit '$unit_name' exists with provided configuration data"
                    fi
                    ;;
                update)
                    if echo "$command" | grep -q "\-\-patch"; then
                        if echo "$command" | grep -q "\-\-upgrade"; then
                            echo "Updates unit '$unit_name' by propagating changes from upstream (push-upgrade pattern)"
                            echo "  Pre-condition: Unit '$unit_name' has upstream unit with newer changes"
                            echo "  Post-condition: Unit '$unit_name' updated to match upstream"
                        elif echo "$command" | grep -q "\-\-label"; then
                            echo "Updates metadata labels for unit '$unit_name' in space '$space_name'"
                            echo "  Pre-condition: Unit '$unit_name' exists"
                            echo "  Post-condition: Unit labels updated"
                        else
                            echo "Updates unit '$unit_name' with patch operation"
                            echo "  Pre-condition: Unit '$unit_name' exists"
                            echo "  Post-condition: Unit updated based on patch operation"
                        fi
                    else
                        echo "Updates configuration data for unit '$unit_name' in space '$space_name' (monolithic)"
                        echo "  Pre-condition: Unit '$unit_name' exists"
                        echo "  Post-condition: Unit data replaced with new configuration"
                    fi
                    ;;
                apply)
                    echo "Applies unit '$unit_name' to target infrastructure in space '$space_name'"
                    echo "  Pre-condition: Unit '$unit_name' exists, target configured, worker running"
                    echo "  Post-condition: Configuration deployed to Kubernetes/cloud"
                    ;;
                destroy)
                    echo "Removes deployed configuration for unit '$unit_name' from infrastructure"
                    echo "  Pre-condition: Unit '$unit_name' is applied"
                    echo "  Post-condition: Resources removed from Kubernetes/cloud"
                    ;;
                list)
                    echo "Lists all units in space '$space_name'"
                    echo "  Pre-condition: Space '$space_name' exists"
                    echo "  Post-condition: List of units returned"
                    ;;
                get)
                    echo "Retrieves full configuration for unit '$unit_name' from space '$space_name'"
                    echo "  Pre-condition: Unit '$unit_name' exists"
                    echo "  Post-condition: Unit configuration returned"
                    ;;
                *)
                    echo "Performs '$verb' operation on unit '$unit_name' in space '$space_name'"
                    ;;
            esac
            ;;
        function)
            if echo "$command" | grep -q "set-replicas"; then
                local replicas=$(echo "$command" | awk '{print $NF}')
                echo "Sets replicas to $replicas for units matching criteria (fine-grained Data update)"
                echo "  Pre-condition: Units exist and are Kubernetes Deployments"
                echo "  Post-condition: spec.replicas field set to $replicas in unit data"
            elif echo "$command" | grep -q "set-image"; then
                echo "Updates container image for units (fine-grained Data update)"
                echo "  Pre-condition: Units exist with container spec"
                echo "  Post-condition: Container image reference updated"
            else
                echo "Executes ConfigHub function on unit configuration data"
                echo "  Pre-condition: Units exist, function is valid"
                echo "  Post-condition: Function executed, unit data modified"
            fi
            ;;
        filter)
            case "$verb" in
                create)
                    echo "Creates a filter named '$unit_name' for querying units with WHERE clause"
                    echo "  Pre-condition: Filter '$unit_name' does not exist"
                    echo "  Post-condition: Filter '$unit_name' exists and can be used to query units"
                    ;;
                *)
                    echo "Performs '$verb' operation on filter '$unit_name'"
                    ;;
            esac
            ;;
        link)
            case "$verb" in
                create)
                    echo "Creates links connecting app units to infrastructure units"
                    echo "  Pre-condition: Source and destination units exist"
                    echo "  Post-condition: Units linked, relationships established"
                    ;;
                *)
                    echo "Performs '$verb' operation on links"
                    ;;
            esac
            ;;
        changeset)
            case "$verb" in
                create)
                    echo "Creates changeset '$unit_name' for atomic multi-unit operations"
                    echo "  Pre-condition: Changeset '$unit_name' does not exist"
                    echo "  Post-condition: Changeset exists, units can be locked to it"
                    ;;
                *)
                    echo "Performs '$verb' operation on changeset '$unit_name'"
                    ;;
            esac
            ;;
        *)
            echo "Performs '$verb' operation on $entity '$unit_name'"
            ;;
    esac
}

#============================================================================
# COMMAND ANALYSIS
#============================================================================

# Analyze a single cub command
function analyze_command {
    local file="$1"
    local line_num="$2"
    local command="$3"

    TOTAL_COMMANDS=$((TOTAL_COMMANDS + 1))

    echo ""
    echo "=========================================="
    echo "FILE: $file"
    echo "LINE $line_num: $command"
    echo "=========================================="

    # 1. SYNTAX VALIDATION
    echo ""
    echo "SYNTAX VALIDATION:"
    if validate_cub_syntax "$command"; then
        echo -e "  ${GREEN}[PASS]${NC} Valid syntax"
        VALID_COMMANDS=$((VALID_COMMANDS + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} Invalid syntax"
        echo "  Error: $CUB_SYNTAX_ERROR"
        INVALID_COMMANDS=$((INVALID_COMMANDS + 1))
    fi

    # 2. GRAMMAR VALIDATION (if WHERE clause present)
    echo ""
    echo "GRAMMAR VALIDATION:"
    if echo "$command" | grep -q "\-\-where"; then
        # Extract WHERE clause (BSD grep compatible)
        local where_clause=$(echo "$command" | sed -n 's/.*--where[[:space:]]\+["'\'']\([^"'\'']*\)["'\''].*/\1/p' || echo "")
        if [ -n "$where_clause" ]; then
            if validate_where_clause "$where_clause"; then
                echo -e "  ${GREEN}[PASS]${NC} Valid WHERE clause"
                echo "  Clause: $where_clause"
            else
                echo -e "  ${RED}[FAIL]${NC} Invalid WHERE clause"
                echo "  Error: $WHERE_CLAUSE_ERROR"
                echo "  Clause: $where_clause"
            fi
        else
            echo -e "  ${YELLOW}[WARN]${NC} WHERE flag present but no clause extracted"
        fi
    else
        echo "  [N/A] No WHERE clause present"
    fi

    # 3. COMMON ERRORS CHECK
    echo ""
    echo "COMMON ERRORS:"
    if detect_common_errors "$command"; then
        echo -e "  ${GREEN}[PASS]${NC} No common errors detected"
    else
        echo -e "  ${YELLOW}[WARN]${NC} Common errors found:"
        for error in "${CUB_COMMON_ERRORS[@]}"; do
            echo "    - $error"
        done

        # Suggest corrections
        if echo "$command" | grep -qE "\-\-patch +['\"]?\{"; then
            echo ""
            echo -e "  ${BLUE}[INFO]${NC} Suggested corrections:"
            echo "    For monolithic Data update:"
            echo "      echo '{...}' | cub unit update <unit> --from-stdin --space <space>"
            echo "    For fine-grained Data update:"
            echo "      cub function do --space <space> --where \"Slug = '<unit>'\" set-replicas 3"
        fi
    fi

    # 4. SEMANTIC EXPLANATION
    echo ""
    echo "SEMANTIC EXPLANATION:"
    echo "  $(generate_semantic_explanation "$command" | head -1)"
    generate_semantic_explanation "$command" | tail -n +2 | sed 's/^/  /'

    echo ""
    echo "------------------------------------------"
}

#============================================================================
# FILE SCANNING
#============================================================================

# Scan a file for cub commands
function scan_file {
    local file="$1"

    TOTAL_FILES=$((TOTAL_FILES + 1))

    echo ""
    echo "=============================================================="
    echo "Analyzing: $file"
    echo "=============================================================="

    if [ ! -f "$file" ]; then
        echo "[ERROR] File not found: $file"
        return 1
    fi

    local line_num=0
    local in_multiline=false
    local current_command=""
    local command_start_line=0

    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Skip empty lines and comments
        if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # Check if line contains "cub"
        if echo "$line" | grep -q "cub "; then
            # Extract the cub command
            local cmd=$(echo "$line" | sed 's/^[[:space:]]*//' | grep -o 'cub .*' || echo "")

            if [ -n "$cmd" ]; then
                # Check if multiline (ends with backslash)
                if echo "$line" | grep -q '\\$'; then
                    in_multiline=true
                    command_start_line=$line_num
                    current_command="$cmd"
                    current_command=${current_command%\\}  # Remove trailing backslash
                else
                    # Single line command
                    analyze_command "$file" "$line_num" "$cmd"
                fi
            fi
        elif $in_multiline; then
            # Continue multiline command
            local continuation=$(echo "$line" | sed 's/^[[:space:]]*//')

            if echo "$line" | grep -q '\\$'; then
                # Still more lines
                continuation=${continuation%\\}  # Remove trailing backslash
                current_command="$current_command $continuation"
            else
                # End of multiline
                current_command="$current_command $continuation"
                in_multiline=false
                analyze_command "$file" "$command_start_line" "$current_command"
                current_command=""
            fi
        fi
    done < "$file"
}

# Scan directory for scripts
function scan_directory {
    local dir="$1"

    if [ ! -d "$dir" ]; then
        echo -e "${RED}Error: Directory not found: $dir${NC}"
        return 1
    fi

    echo "Scanning directory: $dir"
    echo ""

    # Find all shell scripts
    while IFS= read -r file; do
        scan_file "$file"
    done < <(find "$dir" -type f \( -name "*.sh" -o -perm -111 \) 2>/dev/null)
}

#============================================================================
# MAIN
#============================================================================

function print_usage {
    cat <<EOF
ConfigHub cub CLI Command Analyzer

Usage:
  $0 <file>           Analyze single file
  $0 <directory>      Analyze all scripts in directory
  $0 --help           Show this help

Examples:
  $0 bin/install-base
  $0 bin/
  $0 /Users/alexis/traderx/bin/

Output:
  For each cub command found:
  - Syntax validation (✓/✗)
  - Grammar validation for WHERE clauses (✓/✗)
  - Common errors check (✓/⚠)
  - Semantic explanation with pre/post conditions

Environment Variables:
  CUB_TEST_DEBUG=true   Enable debug output
EOF
}

# Parse arguments
if [ $# -eq 0 ]; then
    print_usage
    exit 1
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    print_usage
    exit 0
fi

INPUT="$1"

# Print header
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         ConfigHub cub CLI Command Analyzer                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Analyze input
if [ -f "$INPUT" ]; then
    scan_file "$INPUT"
elif [ -d "$INPUT" ]; then
    scan_directory "$INPUT"
else
    echo "[ERROR] Input not found: $INPUT"
    echo "Must be a file or directory"
    exit 1
fi

# Print summary
echo ""
echo "=============================================================="
echo "ANALYSIS SUMMARY"
echo "=============================================================="
echo "Files analyzed:       $TOTAL_FILES"
echo "Commands found:       $TOTAL_COMMANDS"
echo -e "${GREEN}Valid commands:       $VALID_COMMANDS${NC}"
echo -e "${RED}Invalid commands:     $INVALID_COMMANDS${NC}"
echo "=============================================================="
echo ""

if [ $INVALID_COMMANDS -eq 0 ]; then
    echo -e "${GREEN}[PASS]${NC} All commands are valid!"
    exit 0
else
    echo -e "${YELLOW}[WARN]${NC} Found $INVALID_COMMANDS invalid command(s). See details above."
    exit 1
fi
