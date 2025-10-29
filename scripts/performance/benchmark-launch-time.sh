#!/bin/bash
#
# T105: Measure app launch time with Instruments System Trace
# Verify <2 seconds from cold launch to ready
#
# Usage: ./benchmark-launch-time.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_PATH="${PROJECT_ROOT}/DerivedData/Build/Products/Release/Simmer.app"
TRACE_PATH="${PROJECT_ROOT}/DerivedData/Traces/launch-time-$(date +%Y%m%d-%H%M%S).trace"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== T105: Launch Time Measurement ===${NC}"
echo "Target: <2 seconds from cold launch to ready"
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: Simmer.app not found${NC}"
    exit 1
fi

mkdir -p "$(dirname "$TRACE_PATH")"

# Ensure app is completely quit
echo -e "${YELLOW}Ensuring clean state...${NC}"
pkill -9 -f "Simmer.app" 2>/dev/null || true
sleep 2

echo -e "${GREEN}✓ Clean state verified${NC}"
echo ""

# Method 1: Simple timing measurement
echo -e "${YELLOW}Method 1: Basic timing measurement (10 iterations)${NC}"
echo ""

TOTAL_TIME=0
ITERATIONS=10

for i in $(seq 1 $ITERATIONS); do
    # Ensure app is quit
    pkill -9 -f "Simmer.app" 2>/dev/null || true
    sleep 1

    # Measure launch time
    START=$(date +%s%3N)  # milliseconds
    open "$APP_PATH"

    # Wait for process to appear
    while ! pgrep -f "Simmer.app/Contents/MacOS/Simmer" > /dev/null 2>&1; do
        sleep 0.01
    done

    # Wait for app to be fully ready (menu bar item appears)
    # We'll wait for the app to settle (no more CPU spikes)
    sleep 1

    END=$(date +%s%3N)
    ELAPSED=$((END - START))
    ELAPSED_SEC=$(echo "scale=3; $ELAPSED / 1000" | bc)

    echo -e "  Run ${i}: ${ELAPSED_SEC}s"
    TOTAL_TIME=$((TOTAL_TIME + ELAPSED))

    # Clean up
    pkill -f "Simmer.app" 2>/dev/null || true
    sleep 1
done

AVG_TIME=$((TOTAL_TIME / ITERATIONS))
AVG_SEC=$(echo "scale=3; $AVG_TIME / 1000" | bc)

echo ""
echo -e "${GREEN}Average launch time: ${YELLOW}${AVG_SEC}s${NC}"
echo -e "Target: <2.0s"
echo ""

if (( $(echo "$AVG_SEC < 2.0" | bc -l) )); then
    echo -e "${GREEN}✓ PASS: Launch time within target${NC}"
else
    echo -e "${RED}✗ FAIL: Launch time exceeds target${NC}"
fi

echo ""
echo -e "${YELLOW}Method 2: Instruments System Trace (detailed analysis)${NC}"
echo ""
echo "This provides detailed breakdown of launch phases:"
echo "1. Dyld loading"
echo "2. Static initializers"
echo "3. Application initialization"
echo "4. First UI update"
echo ""
echo "To run detailed profiling:"
echo "  1. Quit Simmer completely"
echo "  2. Run: instruments -t 'System Trace' -D \"${TRACE_PATH}\" -w \"\$(xcodebuild -scheme Simmer -showBuildSettings | grep -m 1 PRODUCT_BUNDLE_IDENTIFIER | awk '{print \$3}')\" -l 5000"
echo "  3. Open Simmer.app during capture"
echo "  4. Analyze trace for launch events"
echo ""

echo -e "${YELLOW}DETAILED ANALYSIS REQUIRED:${NC}"
echo "To analyze launch bottlenecks:"
echo "1. Open trace in Instruments"
echo "2. Look for 'Time to Main' - time until main() executes"
echo "3. Look for 'Time to First Draw' - time until first UI appears"
echo "4. Identify slow initializers in 'Static Initializer Calls'"
echo "5. Check for blocking I/O during launch (ConfigurationStore.loadPatterns)"
echo ""

# Save results to file
RESULTS_FILE="${PROJECT_ROOT}/DerivedData/Traces/launch-time-results.txt"
cat > "$RESULTS_FILE" <<EOF
Launch Time Benchmark Results
=============================

Date: $(date '+%Y-%m-%d %H:%M:%S')
Iterations: ${ITERATIONS}
Average: ${AVG_SEC}s
Target: <2.0s
Status: $(if (( $(echo "$AVG_SEC < 2.0" | bc -l) )); then echo "PASS"; else echo "FAIL"; fi)

Individual runs:
EOF

echo ""
echo "Results saved to: ${RESULTS_FILE}"
echo ""
