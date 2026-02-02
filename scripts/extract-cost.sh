#!/bin/bash
# Clawdbot Cost Extractor
# 
# Extract actual API costs from Clawdbot session JSONL files.
# This reads the usage.cost.total field which contains real USD costs.
#
# Usage:
#   extract-cost.sh [options]
#
# Options:
#   --yesterday    Show yesterday's cost only
#   --date DATE    Show cost for specific date (YYYY-MM-DD)
#   --week         Show this week's costs
#   --month        Show this month's costs
#   --by-model     Group costs by model
#   --json         Output as JSON
#   --sessions-dir Directory containing JSONL files
#
# Examples:
#   extract-cost.sh                    # All daily costs
#   extract-cost.sh --yesterday        # Yesterday only
#   extract-cost.sh --date 2026-01-30  # Specific date
#   extract-cost.sh --week --json      # This week as JSON
#
# @author Clawdbot
# @license MIT

set -e

# Default sessions directory
SESSIONS_DIR="${HOME}/.clawdbot/agents/main/sessions"

# Parse arguments
OUTPUT_FORMAT="text"
DATE_FILTER=""
BY_MODEL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --yesterday)
      if [[ "$(uname)" == "Darwin" ]]; then
        DATE_FILTER=$(date -v-1d +%Y-%m-%d)
      else
        DATE_FILTER=$(date -d "yesterday" +%Y-%m-%d)
      fi
      shift
      ;;
    --date)
      DATE_FILTER="$2"
      shift 2
      ;;
    --week)
      if [[ "$(uname)" == "Darwin" ]]; then
        DATE_FILTER=$(date -v-7d +%Y-%m-%d)
      else
        DATE_FILTER=$(date -d "7 days ago" +%Y-%m-%d)
      fi
      DATE_FILTER="week:$DATE_FILTER"
      shift
      ;;
    --month)
      if [[ "$(uname)" == "Darwin" ]]; then
        DATE_FILTER=$(date +%Y-%m)
      else
        DATE_FILTER=$(date +%Y-%m)
      fi
      DATE_FILTER="month:$DATE_FILTER"
      shift
      ;;
    --by-model)
      BY_MODEL=true
      shift
      ;;
    --json)
      OUTPUT_FORMAT="json"
      shift
      ;;
    --sessions-dir)
      SESSIONS_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Check sessions directory exists
if [[ ! -d "$SESSIONS_DIR" ]]; then
  echo "Error: Sessions directory not found: $SESSIONS_DIR" >&2
  exit 1
fi

cd "$SESSIONS_DIR"

# Function to extract costs by date
extract_daily_costs() {
  for f in *.jsonl; do
    [[ -f "$f" ]] || continue
    grep -o '"timestamp":"[^"]*".*"total":[0-9.]*' "$f" 2>/dev/null | \
    sed 's/.*"timestamp":"\([^T]*\)T.*"total":\([0-9.]*\).*/\1 \2/'
  done | awk '{date=$1; cost=$2; sum[date]+=cost} END {for(d in sum) printf "%s %.4f\n", d, sum[d]}' | sort
}

# Function to extract costs by model
extract_by_model() {
  for f in *.jsonl; do
    [[ -f "$f" ]] || continue
    # Extract model from session metadata and costs from usage
    model=$(grep -o '"modelId":"[^"]*"' "$f" 2>/dev/null | head -1 | cut -d'"' -f4)
    [[ -z "$model" ]] && model="unknown"
    total=$(grep -o '"total":[0-9.]*' "$f" 2>/dev/null | cut -d: -f2 | awk '{sum+=$1} END {print sum}')
    [[ -n "$total" ]] && echo "$model $total"
  done | awk '{model=$1; cost=$2; sum[model]+=cost} END {for(m in sum) printf "%s %.4f\n", m, sum[m]}' | sort -k2 -rn
}

# Apply date filter
filter_by_date() {
  local filter="$1"
  if [[ -z "$filter" ]]; then
    cat
  elif [[ "$filter" == week:* ]]; then
    local start_date="${filter#week:}"
    awk -v start="$start_date" '$1 >= start'
  elif [[ "$filter" == month:* ]]; then
    local month="${filter#month:}"
    grep "^$month"
  else
    grep "^$filter"
  fi
}

# Main logic
if [[ "$BY_MODEL" == true ]]; then
  results=$(extract_by_model)
else
  results=$(extract_daily_costs | filter_by_date "$DATE_FILTER")
fi

# Calculate total
total=$(echo "$results" | awk '{sum+=$2} END {printf "%.2f", sum}')

# Output based on format
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  echo "{"
  echo "  \"generatedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"sessionsDir\": \"$SESSIONS_DIR\","
  if [[ "$BY_MODEL" == true ]]; then
    echo "  \"byModel\": {"
    echo "$results" | awk 'BEGIN{first=1} {if(!first)print ","; first=0; printf "    \"%s\": %.4f", $1, $2}'
    echo ""
    echo "  },"
  else
    echo "  \"byDate\": {"
    echo "$results" | awk 'BEGIN{first=1} {if(!first)print ","; first=0; printf "    \"%s\": %.4f", $1, $2}'
    echo ""
    echo "  },"
  fi
  echo "  \"total\": $total"
  echo "}"
else
  if [[ "$BY_MODEL" == true ]]; then
    echo "=== Cost by Model ==="
    echo "$results" | awk '{printf "%-25s $%.2f\n", $1, $2}'
  else
    echo "=== Daily Costs ==="
    echo "$results" | awk '{printf "%s  $%.2f\n", $1, $2}'
  fi
  echo "---"
  echo "Total: \$$total"
fi
