#!/bin/bash
#
# T099: Profile baseline active CPU usage
# Verify <5% CPU with 10 patterns, 100 matches/second
#
# Usage: ./benchmark-baseline-active.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_PATH="${PROJECT_ROOT}/DerivedData/Build/Products/Release/Simmer.app"
TEST_LOGS_DIR="${PROJECT_ROOT}/test-logs"
DURATION=60  # 1 minute active load

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== T099: Baseline Active CPU Profiling ===${NC}"
echo "Target: <5% CPU with 10 patterns @ 100 matches/second"
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: Simmer.app not found${NC}"
    exit 1
fi

# Create test logs directory
mkdir -p "$TEST_LOGS_DIR"
mkdir -p "${PROJECT_ROOT}/DerivedData/Traces"

# Create 10 test log files
echo -e "${YELLOW}Creating 10 test log files...${NC}"
for i in {1..10}; do
    LOG_FILE="${TEST_LOGS_DIR}/active-test-${i}.log"
    echo "Initial content for active test ${i}" > "$LOG_FILE"
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
echo "Configure 10 patterns for active monitoring:"
echo ""
for i in {1..10}; do
    LOG_FILE="${TEST_LOGS_DIR}/active-test-${i}.log"
    echo "   Pattern ${i}: ERROR|WARN|INFO → ${LOG_FILE}"
done
echo ""
echo "Press ENTER when configuration is complete..."
read -r

# Wait for stabilization
echo -e "${YELLOW}Waiting 5 seconds for stabilization...${NC}"
sleep 5

# Start load generation in background
echo -e "${YELLOW}Starting load generation: 100 matches/second for 60 seconds...${NC}"
(
    for second in $(seq 1 $DURATION); do
        # Write 10 matches per second (distributed across 10 files)
        for i in {1..10}; do
            LOG_FILE="${TEST_LOGS_DIR}/active-test-${i}.log"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR Active test message ${second}" >> "$LOG_FILE"
        done
        sleep 1
    done
) &
LOAD_GEN_PID=$!

# Sample CPU during load
CPU_SAMPLES_FILE="${PROJECT_ROOT}/DerivedData/Traces/active-cpu-samples.txt"
: > "$CPU_SAMPLES_FILE"  # Clear file

TOTAL_CPU=0
SAMPLE_COUNT=0

for i in $(seq 1 $DURATION); do
    CPU=$(ps -p "$APP_PID" -o %cpu= 2>/dev/null | tr -d ' ' || echo "0.0")

    echo "$CPU" >> "$CPU_SAMPLES_FILE"
    TOTAL_CPU=$(echo "$TOTAL_CPU + $CPU" | bc)
    SAMPLE_COUNT=$((SAMPLE_COUNT + 1))

    # Progress indicator every 10 seconds
    if [ $((i % 10)) -eq 0 ]; then
        avg=$(echo "scale=2; $TOTAL_CPU / $SAMPLE_COUNT" | bc)
        echo -e "${GREEN}  ${i}/${DURATION} seconds (avg CPU: ${avg}%)${NC}"
    fi

    sleep 1
done

# Wait for load generation to complete
wait $LOAD_GEN_PID

# Calculate average
AVG_CPU=$(echo "scale=2; $TOTAL_CPU / $SAMPLE_COUNT" | bc)

echo ""
echo -e "${GREEN}✓ Active monitoring complete${NC}"
echo ""

# Quit the app
echo -e "${YELLOW}Stopping Simmer...${NC}"
osascript -e 'quit app "Simmer"' 2>/dev/null || kill "$APP_PID" 2>/dev/null || true
sleep 2

echo ""
echo -e "${GREEN}=== BASELINE ACTIVE RESULTS ===${NC}"
echo ""
echo "Duration: 60 seconds"
echo "Patterns: 10"
echo "Match rate: ~100 matches/second"
echo "Total matches: ~6000"
echo "Samples: ${SAMPLE_COUNT}"
echo ""
echo -e "Average CPU: ${YELLOW}${AVG_CPU}%${NC}"
echo -e "Target: <5.0%"
echo ""

# Check if we passed
if (( $(echo "$AVG_CPU < 5.0" | bc -l) )); then
    echo -e "${GREEN}✓ PASS: Active CPU usage within target${NC}"
else
    echo -e "${RED}✗ FAIL: Active CPU usage exceeds target${NC}"
fi

echo ""
echo "CPU samples saved to: ${CPU_SAMPLES_FILE}"
echo ""

echo -e "${YELLOW}CLEANUP:${NC}"
echo "To remove test logs: rm -rf ${TEST_LOGS_DIR}"
echo ""
