# Backfill HN silver + gold for a date range, one date at a time (sequential).
# Requires AWS CLI for Windows on PATH and configured credentials (aws configure).
#
# The daily state machine (<prefix>-silver-gold) runs silver-hacker-news -> gold-hn
# only. Twitter is event-driven (a CSV upload to bronze/source=twitter/ triggers
# the <prefix>-twitter pipeline). Use -RunTwitter to kick that pipeline once.
#
# Usage (PowerShell, from repo root):
#   ./scripts/backfill.ps1 -Start 2026-05-29 -End 2026-06-26
#   ./scripts/backfill.ps1 -Start 2026-05-29 -End 2026-06-26 -BackfillBronze
#   ./scripts/backfill.ps1 -RunTwitter            # just (re)run the X pipeline
param(
  [string]$Start   = "2026-05-29",
  [string]$End     = "2026-06-26",
  [string]$Region  = "eu-central-1",
  [string]$Account = "278371787079",
  [string]$Prefix  = "iza-oblaka-tim28-dev",
  [switch]$BackfillBronze,
  [switch]$RunTwitter
)

$hnSm = "arn:aws:states:${Region}:${Account}:stateMachine:${Prefix}-silver-gold"
$twSm = "arn:aws:states:${Region}:${Account}:stateMachine:${Prefix}-twitter"
$hn   = "${Prefix}-bronze-hacker-news"

function Wait-Execution($arn) {
  do {
    Start-Sleep -Seconds 5
    $status = aws stepfunctions describe-execution --execution-arn $arn `
      --region $Region --query status --output text
  } while ($status -eq "RUNNING")
  Write-Host "    $status"
}

function Start-Sm($smArn, $name, $input) {
  return (aws stepfunctions start-execution --state-machine-arn $smArn `
    --name $name --input $input --region $Region --query executionArn --output text)
}

if ($RunTwitter) {
  Write-Host ">>> twitter pipeline (whole dataset)"
  Wait-Execution (Start-Sm $twSm "twitter-backfill-$PID" "{}")
}

$d    = [datetime]::ParseExact($Start, 'yyyy-MM-dd', $null)
$endD = [datetime]::ParseExact($End,   'yyyy-MM-dd', $null)

while ($d -le $endD) {
  $ds = $d.ToString('yyyy-MM-dd')
  Write-Host ">>> $ds"

  if ($BackfillBronze) {
    Write-Host "    bronze HN $ds"
    aws lambda invoke --function-name $hn --cli-binary-format raw-in-base64-out `
      --payload "{""date"":""$ds""}" --region $Region "$env:TEMP\bronze.json" | Out-Null
  }

  Wait-Execution (Start-Sm $hnSm "backfill-$ds-$PID" "{""date"":""$ds""}")
  $d = $d.AddDays(1)
}

Write-Host "Backfill complete: $Start .. $End"
