#!/usr/bin/env bash
# Backfill HN silver + gold for a date range, one date at a time.
#
# Architecture note: the daily state machine (<prefix>-silver-gold) runs
# silver-hacker-news -> gold-hn only. Twitter is event-driven (a CSV upload to
# bronze/source=twitter/ triggers the <prefix>-twitter pipeline). Pass
# RUN_TWITTER=1 to also kick that twitter pipeline once over the whole dataset.
#
# Sequential on purpose: the HN users dimension is shared across dates, so
# concurrent runs would race on the same S3 objects.
#
# Usage:
#   START=2026-05-29 END=2026-06-26 bash scripts/backfill.sh
#   BACKFILL_BRONZE=1 START=2026-05-29 END=2026-06-26 bash scripts/backfill.sh
#   RUN_TWITTER=1 bash scripts/backfill.sh        # just (re)run the X pipeline
set -euo pipefail

REGION="${REGION:-eu-central-1}"
ACCOUNT="${ACCOUNT:-278371787079}"
PREFIX="${PREFIX:-iza-oblaka-tim28-dev}"
START="${START:-2026-05-29}"
END="${END:-2026-06-26}"
BACKFILL_BRONZE="${BACKFILL_BRONZE:-0}"
RUN_TWITTER="${RUN_TWITTER:-0}"

HN_SM_ARN="arn:aws:states:${REGION}:${ACCOUNT}:stateMachine:${PREFIX}-silver-gold"
TW_SM_ARN="arn:aws:states:${REGION}:${ACCOUNT}:stateMachine:${PREFIX}-twitter"
HN_FN="${PREFIX}-bronze-hacker-news"

invoke_bronze() {
  echo "    bronze HN $1"
  aws lambda invoke \
    --function-name "$HN_FN" \
    --cli-binary-format raw-in-base64-out \
    --payload "{\"date\":\"$1\"}" \
    --region "$REGION" \
    /dev/null >/dev/null
}

wait_for() {
  local arn="$1" status
  while true; do
    status=$(aws stepfunctions describe-execution \
      --execution-arn "$arn" --region "$REGION" \
      --query status --output text)
    [ "$status" = "RUNNING" ] || { echo "    $status"; break; }
    sleep 5
  done
}

start_sm() {  # start_sm <state-machine-arn> <name> <input-json>
  aws stepfunctions start-execution \
    --state-machine-arn "$1" --name "$2" --input "$3" \
    --region "$REGION" --query executionArn --output text
}

if [ "$RUN_TWITTER" = "1" ]; then
  echo ">>> twitter pipeline (whole dataset)"
  wait_for "$(start_sm "$TW_SM_ARN" "twitter-backfill-$$" '{}')"
fi

d="$START"
while :; do
  echo ">>> $d"
  [ "$BACKFILL_BRONZE" = "1" ] && invoke_bronze "$d"
  wait_for "$(start_sm "$HN_SM_ARN" "backfill-${d}-$$" "{\"date\":\"$d\"}")"
  [ "$d" = "$END" ] && break
  d=$(date -d "$d + 1 day" +%F)
done

echo "Backfill complete: $START .. $END"
