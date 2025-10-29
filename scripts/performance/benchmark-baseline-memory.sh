#!/bin/bash
#
# T100: Profile baseline memory usage
# Verify <50MB with 20 patterns, 1000 match history
#
# Usage: ./benchmark-baseline-memory.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_PATH="${PROJECT_ROOT}/DerivedData/Build/Products/Release/Simmer.app"
TEST_LOGS_DIR="${PROJECT_ROOT}/test-logs"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== T100: Baseline Memory Profiling ===${NC}"
echo "Target: <50MB with 20 patterns and 1000 match history"
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: Simmer.app not found${NC}"
    exit 1
fi

# Create test logs directory
mkdir -p "$TEST_LOGS_DIR"
mkdir -p "${PROJECT_ROOT}/DerivedData/Traces"

# Create 20 test log files
echo -e "${YELLOW}Creating 20 test log files...${NC}"
for i in {1..20}; do
    LOG_FILE="${TEST_LOGS_DIR}/mem-test-${i}.log"
    echo "Initial content for memory test ${i}" > "$LOG_FILE"
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
echo "Configure 20 patterns for memory testing:"
echo ""
for i in {1..20}; do
    LOG_FILE="${TEST_LOGS_DIR}/mem-test-${i}.log"
    echo "   Pattern ${i}: ERROR|WARN → ${LOG_FILE}"
done
echo ""
echo "Press ENTER when configuration is complete..."
read -r

# Measure baseline memory before matches
echo -e "${YELLOW}Measuring baseline memory...${NC}"
sleep 2
BASELINE_MEM=$(ps -p "$APP_PID" -o rss= | tr -d ' ')
BASELINE_MB=$(echo "scale=2; $BASELINE_MEM / 1024" | bc)
echo -e "Baseline: ${BASELINE_MB} MB"
echo ""

# Generate 1000 matches
echo -e "${YELLOW}Generating 1,000 match events...${NC}"

TOTAL_MATCHES=1000
for match in $(seq 1 $TOTAL_MATCHES); do
    # Distribute across 20 files
    file_idx=$(( (match % 20) + 1 ))
    LOG_FILE="${TEST_LOGS_DIR}/mem-test-${file_idx}.log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR Memory test match ${match}" >> "$LOG_FILE"

    # Progress indicator every 100 matches
    if [ $((match % 100)) -eq 0 ]; then
        current_mem=$(ps -p "$APP_PID" -o rss= | tr -d ' ')
        current_mb=$(echo "scale=2; $current_mem / 1024" | bc)
        echo -e "${GREEN}  ${match}/${TOTAL_MATCHES} matches (memory: ${current_mb} MB)${NC}"
    fi

    # Brief pause to allow processing
    sleep 0.1
done

echo -e "${GREEN}✓ All matches generated${NC}"
echo ""

# Let memory stabilize
echo -e "${YELLOW}Waiting 10 seconds for memory to stabilize...${NC}"
sleep 10

# Measure final memory
FINAL_MEM=$(ps -p "$APP_PID" -o rss= | tr -d ' ')
FINAL_MB=$(echo "scale=2; $FINAL_MEM / 1024" | bc)

# Calculate delta
DELTA_MEM=$((FINAL_MEM - BASELINE_MEM))
DELTA_MB=$(echo "scale=2; $DELTA_MEM / 1024" | bc)

# Quit the app
echo -e "${YELLOW}Stopping Simmer...${NC}"
osascript -e 'quit app "Simmer"' 2>/dev/null || kill "$APP_PID" 2>/dev/null || true
sleep 2

echo ""
echo -e "${GREEN}=== BASELINE MEMORY RESULTS ===${NC}"
echo ""
echo "Configuration: 20 patterns"
echo "Match history: 1000 events"
echo ""
echo -e "Baseline memory: ${BASELINE_MB} MB"
echo -e "Final memory: ${YELLOW}${FINAL_MB} MB${NC}"
echo -e "Delta: +${DELTA_MB} MB"
echo -e "Target: <50 MB"
echo ""

# Check if we passed
if (( $(echo "$FINAL_MB < 50.0" | bc -l) )); then
    echo -e "${GREEN}✓ PASS: Memory usage within target${NC}"
else
    echo -e "${RED}✗ FAIL: Memory usage exceeds target${NC}"
fi

echo ""

# Additional context
echo -e "${YELLOW}Note:${NC} MatchEventHandler should prune history to 100 items max"
echo "Expected memory for 100 MatchEvents: ~50KB"
echo "Expected memory for 20 FileWatchers: ~200KB"
echo "Expected memory for 20 compiled patterns: ~100KB"
echo ""

echo -e "${YELLOW}CLEANUP:${NC}"
echo "To remove test logs: rm -rf ${TEST_LOGS_DIR}"
echo ""
