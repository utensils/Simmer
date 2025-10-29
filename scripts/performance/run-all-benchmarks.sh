#!/bin/bash
#
# Master script to run all performance benchmarks
# Executes T083, T084, T085, T098, T099, T100, T105, T132
#
# Usage: ./run-all-benchmarks.sh [--quick]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

QUICK_MODE=false
if [ "${1:-}" = "--quick" ]; then
    QUICK_MODE=true
fi

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         Simmer Performance Benchmark Suite                   ║"
echo "║         Testing FR-019, SC-002, SC-003, SC-004, SC-006       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Verify app is built
APP_PATH="${PROJECT_ROOT}/DerivedData/Build/Products/Release/Simmer.app"
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: Simmer.app not found${NC}"
    echo "Building Release configuration..."
    xcodebuild -project "${PROJECT_ROOT}/Simmer.xcodeproj" -scheme Simmer -configuration Release -derivedDataPath "${PROJECT_ROOT}/DerivedData" build
fi

echo -e "${GREEN}✓ Simmer.app ready${NC}"
echo ""

# Create results directory
RESULTS_DIR="${PROJECT_ROOT}/DerivedData/BenchmarkResults"
mkdir -p "$RESULTS_DIR"
SUMMARY_FILE="${RESULTS_DIR}/benchmark-summary-$(date +%Y%m%d-%H%M%S).md"

# Initialize summary
cat > "$SUMMARY_FILE" <<EOF
# Performance Benchmark Results

**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**Build**: Release
**Mode**: $(if $QUICK_MODE; then echo "Quick (automated only)"; else echo "Full (interactive + manual)"; fi)

## Test Matrix

| Test | Task | Description | Target | Status |
|------|------|-------------|--------|--------|
EOF

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

run_test() {
    local test_name="$1"
    local test_script="$2"
    local test_desc="$3"
    local test_target="$4"
    local requires_manual="${5:-false}"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Running: ${test_name}${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    if [ "$requires_manual" = "true" ] && [ "$QUICK_MODE" = "true" ]; then
        echo -e "${BLUE}⊘ SKIPPED (requires manual interaction)${NC}"
        echo "| ${test_name} | ${test_desc} | ${test_target} | ⊘ SKIPPED (manual) |" >> "$SUMMARY_FILE"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        echo ""
        return
    fi

    if bash "$test_script"; then
        echo -e "${GREEN}✓ ${test_name} PASSED${NC}"
        echo "| ${test_name} | ${test_desc} | ${test_target} | ✓ PASS |" >> "$SUMMARY_FILE"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ ${test_name} FAILED${NC}"
        echo "| ${test_name} | ${test_desc} | ${test_target} | ✗ FAIL |" >> "$SUMMARY_FILE"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi

    echo ""
    sleep 2
}

# Run benchmarks in order

if ! $QUICK_MODE; then
    echo -e "${YELLOW}Note: Some tests require manual configuration.${NC}"
    echo "You will be prompted to configure patterns via the Settings UI."
    echo ""
    echo "Press ENTER to begin..."
    read -r
fi

# T098: Baseline idle (5 minutes - long running)
run_test "T098" \
         "${SCRIPT_DIR}/benchmark-baseline-idle.sh" \
         "Baseline idle CPU" \
         "<1% CPU (10 patterns, no matches, 5 min)" \
         "true"

# T099: Baseline active (1 minute)
run_test "T099" \
         "${SCRIPT_DIR}/benchmark-baseline-active.sh" \
         "Baseline active CPU" \
         "<5% CPU (10 patterns, 100 matches/sec)" \
         "true"

# T100: Baseline memory
run_test "T100" \
         "${SCRIPT_DIR}/benchmark-baseline-memory.sh" \
         "Baseline memory" \
         "<50MB (20 patterns, 1000 history)" \
         "true"

# T083: Multi-watcher CPU
run_test "T083" \
         "${SCRIPT_DIR}/benchmark-multi-watcher.sh" \
         "Multi-watcher CPU" \
         "<5% CPU (10 patterns, 100 matches/sec)" \
         "true"

# T084: Multi-watcher memory
run_test "T084" \
         "${SCRIPT_DIR}/benchmark-memory.sh" \
         "Multi-watcher memory" \
         "<50MB (20 patterns, 10k history)" \
         "true"

# T105: Launch time
run_test "T105" \
         "${SCRIPT_DIR}/benchmark-launch-time.sh" \
         "Launch time" \
         "<2 seconds cold launch" \
         "false"

# T132: Pattern matching timing
run_test "T132" \
         "${SCRIPT_DIR}/benchmark-pattern-matching.sh" \
         "Pattern matching latency" \
         "<10ms per line (20 patterns)" \
         "true"

# Add summary footer
cat >> "$SUMMARY_FILE" <<EOF

## Summary

- **Total Tests**: ${TOTAL_TESTS}
- **Passed**: ${PASSED_TESTS}
- **Failed**: ${FAILED_TESTS}
- **Skipped**: ${SKIPPED_TESTS}

## Manual Tests (Not Automated)

### T085: Multi-Pattern Priority Test

**Objective**: Verify animation prioritization with simultaneous matches

**Steps**:
1. Configure 5 patterns with different colors and priorities:
   - Pattern 1: ERROR (Red, highest priority)
   - Pattern 2: WARN (Yellow)
   - Pattern 3: INFO (Blue)
   - Pattern 4: DEBUG (Green)
   - Pattern 5: TRACE (Gray, lowest priority)

2. Create 5 test log files and trigger simultaneous matches
3. Verify menu bar icon animates with highest-priority color
4. Trigger lower-priority matches - verify no animation change
5. Wait for animation to stop, trigger lower-priority match - verify it animates

**Success Criteria**: Highest-priority pattern always takes precedence

## Trace Files

All Instruments traces saved to: \`DerivedData/Traces/\`

To analyze:
\`\`\`bash
open DerivedData/Traces/*.trace
\`\`\`

## Next Steps

1. Review failed tests and investigate bottlenecks
2. Analyze Instruments traces for optimization opportunities
3. Update tasks.md to mark completed benchmark tasks
4. Document findings in research.md if architectural changes needed

---

Generated by: \`scripts/performance/run-all-benchmarks.sh\`
EOF

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 BENCHMARK SUITE COMPLETE                      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Results Summary:${NC}"
echo -e "  Total:   ${TOTAL_TESTS}"
echo -e "  ${GREEN}Passed:  ${PASSED_TESTS}${NC}"
echo -e "  ${RED}Failed:  ${FAILED_TESTS}${NC}"
echo -e "  ${BLUE}Skipped: ${SKIPPED_TESTS}${NC}"
echo ""
echo "Detailed results: ${SUMMARY_FILE}"
echo ""
echo -e "${YELLOW}Manual Test Remaining:${NC}"
echo "  T085: Multi-pattern priority verification (see summary for steps)"
echo ""

if [ $FAILED_TESTS -gt 0 ]; then
    exit 1
fi
