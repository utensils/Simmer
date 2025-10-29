#!/bin/bash
#
# T098: Profile baseline idle CPU usage
# Verify <1% CPU with 10 patterns, no matches for 5 minutes
#
# Usage: ./benchmark-baseline-idle.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_PATH="${PROJECT_ROOT}/DerivedData/Build/Products/Release/Simmer.app"
TRACE_PATH="${PROJECT_ROOT}/DerivedData/Traces/baseline-idle-$(date +%Y%m%d-%H%M%S).trace"
TEST_LOGS_DIR="${PROJECT_ROOT}/test-logs"
DURATION=300  # 5 minutes in seconds

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== T098: Baseline Idle CPU Profiling ===${NC}"
echo "Target: <1% CPU with 10 patterns, no matches for 5 minutes"
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: Simmer.app not found${NC}"
    exit 1
fi

# Create test logs directory
mkdir -p "$TEST_LOGS_DIR"
mkdir -p "$(dirname "$TRACE_PATH")"

# Create 10 test log files (with no updates during test)
echo -e "${YELLOW}Creating 10 static test log files...${NC}"
for i in {1..10}; do
    LOG_FILE="${TEST_LOGS_DIR}/idle-test-${i}.log"
    echo "Static content for idle test ${i}" > "$LOG_FILE"
done

echo -e "${GREEN}✓ Test log files created${NC}"
echo ""

# Start the app
echo -e "${YELLOW}Launching Simmer.app...${NC}"
open "$APP_PATH"
sleep 5

APP_PID=$(pgrep -f "Simmer.app/Contents/MacOS/Simmer" | head -n 1)
if [ -z "$APP_PID" ]; then
    echo -e "${RED}Error: Could not find Simmer process${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Simmer running with PID: ${APP_PID}${NC}"
echo ""

echo -e "${YELLOW}MANUAL CONFIGURATION REQUIRED:${NC}"
echo "Configure 10 patterns for idle monitoring:"
echo ""
for i in {1..10}; do
    LOG_FILE="${TEST_LOGS_DIR}/idle-test-${i}.log"
    echo "   Pattern ${i}: ERROR|WARN → ${LOG_FILE}"
done
echo ""
echo "Press ENTER when configuration is complete..."
read -r

# Start Activity Monitor sampling
echo -e "${YELLOW}Starting idle CPU monitoring for 5 minutes...${NC}"
echo "Sampling CPU every 5 seconds"
echo ""

CPU_SAMPLES_FILE="${PROJECT_ROOT}/DerivedData/Traces/idle-cpu-samples.txt"
: > "$CPU_SAMPLES_FILE"  # Clear file

# Sample CPU for 5 minutes
SAMPLES=$((DURATION / 5))
TOTAL_CPU=0
SAMPLE_COUNT=0

for i in $(seq 1 $SAMPLES); do
    # Get CPU percentage
    CPU=$(ps -p "$APP_PID" -o %cpu= 2>/dev/null | tr -d ' ' || echo "0.0")

    echo "$CPU" >> "$CPU_SAMPLES_FILE"
    TOTAL_CPU=$(echo "$TOTAL_CPU + $CPU" | bc)
    SAMPLE_COUNT=$((SAMPLE_COUNT + 1))

    # Progress indicator every minute
    elapsed=$((i * 5))
    if [ $((elapsed % 60)) -eq 0 ]; then
        minutes=$((elapsed / 60))
        avg=$(echo "scale=2; $TOTAL_CPU / $SAMPLE_COUNT" | bc)
        echo -e "${GREEN}  ${minutes}/5 minutes elapsed (avg CPU: ${avg}%)${NC}"
    fi

    sleep 5
done

# Calculate average
AVG_CPU=$(echo "scale=2; $TOTAL_CPU / $SAMPLE_COUNT" | bc)

echo ""
echo -e "${GREEN}✓ Idle monitoring complete${NC}"
echo ""

# Quit the app
echo -e "${YELLOW}Stopping Simmer...${NC}"
osascript -e 'quit app "Simmer"' 2>/dev/null || kill "$APP_PID" 2>/dev/null || true
sleep 2

echo ""
echo -e "${GREEN}=== BASELINE IDLE RESULTS ===${NC}"
echo ""
echo "Duration: 5 minutes"
echo "Patterns: 10"
echo "Matches: 0 (no log activity)"
echo "Samples: ${SAMPLE_COUNT}"
echo ""
echo -e "Average CPU: ${YELLOW}${AVG_CPU}%${NC}"
echo -e "Target: <1.0%"
echo ""

# Check if we passed
if (( $(echo "$AVG_CPU < 1.0" | bc -l) )); then
    echo -e "${GREEN}✓ PASS: Idle CPU usage within target${NC}"
else
    echo -e "${RED}✗ FAIL: Idle CPU usage exceeds target${NC}"
fi

echo ""
echo "CPU samples saved to: ${CPU_SAMPLES_FILE}"
echo ""

echo -e "${YELLOW}CLEANUP:${NC}"
echo "To remove test logs: rm -rf ${TEST_LOGS_DIR}"
echo ""
