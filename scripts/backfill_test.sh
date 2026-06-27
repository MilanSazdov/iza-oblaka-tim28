#!/usr/bin/env bash
# Test backfill: runs silver + gold for a single day (2026-05-29 only).
# Add BACKFILL_BRONZE=1 to also fetch that day's raw HN data first.
#
# Usage:
#   bash scripts/backfill_test.sh
#   BACKFILL_BRONZE=1 bash scripts/backfill_test.sh
set -euo pipefail

cd "$(dirname "$0")/.."
START=2026-05-29 END=2026-05-29 bash scripts/backfill.sh
