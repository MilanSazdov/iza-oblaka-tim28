# Test backfill: runs silver + gold for a single day (2026-05-29 only).
# Add -BackfillBronze to also fetch that day's raw HN data first.
#
# Usage (PowerShell, from repo root):
#   ./scripts/backfill_test.ps1
#   ./scripts/backfill_test.ps1 -BackfillBronze
param(
  [switch]$BackfillBronze
)

& "$PSScriptRoot\backfill.ps1" -Start 2026-05-29 -End 2026-05-29 -BackfillBronze:$BackfillBronze
