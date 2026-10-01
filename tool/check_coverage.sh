#!/usr/bin/env bash
set -euo pipefail

lcov_file="${1:-coverage/lcov.info}"
baseline="${COVERAGE_BASELINE_PERCENT:-35.00}"

if [ ! -s "$lcov_file" ]; then
  echo "Coverage file is missing or empty: $lcov_file"
  exit 1
fi

total="$(awk -F: '/^LF:/{sum+=$2} END{print sum+0}' "$lcov_file")"
hit="$(awk -F: '/^LH:/{sum+=$2} END{print sum+0}' "$lcov_file")"
percent="$(awk -v hit="$hit" -v total="$total" 'BEGIN { if (total == 0) print "0.00"; else printf "%.2f", hit * 100 / total }')"

echo "Line coverage: $percent% (baseline: $baseline%)"

awk -v actual="$percent" -v baseline="$baseline" 'BEGIN {
  if (actual + 0 < baseline + 0) {
    printf "Coverage regression: %.2f%% is below %.2f%% baseline.\n", actual, baseline
    exit 1
  }
}'
