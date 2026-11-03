#!/usr/bin/env bash
# Author-only: measure how long a new public grant takes to appear in
# Cloud Asset Inventory (fills the [from validation] wait in 02_02 / 02_05).
# Usage: validation/probe-asset-delay.sh <PROJECT_ID> [REGION]
set -uo pipefail
P="${1:?usage: $0 <PROJECT_ID> [REGION]}"; REGION="${2:-us-central1}"
export CLOUDSDK_CORE_PROJECT="$P" CLOUDSDK_BILLING_QUOTA_PROJECT="$P"
LOG="$(cd "$(dirname "$0")" && pwd)/raw/$(date +%Y-%m-%d)-asset-delay.log"
B="${P}-asset-delay-probe"
{
  gcloud storage buckets create "gs://$B" --location="$REGION" --uniform-bucket-level-access
  gcloud storage buckets add-iam-policy-binding "gs://$B" --member=allUsers --role=roles/storage.objectViewer --format=none
  t0=$SECONDS
  echo "grant applied at $(date -u +%FT%TZ)"
  while :; do
    out=$(gcloud asset search-all-iam-policies --scope="projects/$P" --query="policy:allUsers" --format='value(resource)' 2>&1)
    if echo "$out" | grep -q "$B"; then echo "visible after $((SECONDS - t0))s: $out"; break; fi
    [ $((SECONDS - t0)) -gt 1200 ] && { echo "not visible after 1200s; last output: $out"; break; }
    echo "  $((SECONDS - t0))s: not yet (${out:-empty})"; sleep 15
  done
  gcloud storage rm --recursive "gs://$B"
} 2>&1 | tee "$LOG"
