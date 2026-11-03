#!/usr/bin/env bash
# Author-only validation probe (not a learner lab step).
# Answers the three questions that decide the lab design before any lab is written,
# on a BRAND-NEW free-trial project with NO Organization (learner reality):
#   V1  Can Security Command Center be activated / read at project scope?
#   V2  Which Org Policy constraints accept project-level policies, incl. dryRunSpec?
#       Does a new project already block public buckets?
#   V3  Bucket Lock: what does a blocked delete look like, and does teardown work?
# Every command's raw output is captured to validation/raw/<date>-probe.log so the
# lab guides quote literal strings, never strings typed from memory.
#
# Usage: validation/probe-v1-v3.sh <PROJECT_ID> [REGION]
set -uo pipefail

P="${1:?usage: $0 <PROJECT_ID> [REGION]}"
REGION="${2:-us-central1}"
# Pin project + quota project for this run only (never touch the user's gcloud config):
# without this, gcloud bills API calls to whatever project the config points at.
export CLOUDSDK_CORE_PROJECT="$P" CLOUDSDK_BILLING_QUOTA_PROJECT="$P"
LOG_DIR="$(cd "$(dirname "$0")" && pwd)/raw"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/$(date +%Y-%m-%d)-probe.log"
: > "$LOG"

run() {  # run <label> <cmd...>: print, time, and log the command and its full output
  local label="$1"; shift
  local t0=$SECONDS
  {
    echo
    echo "### $label"
    echo "\$ $*"
  } | tee -a "$LOG"
  "$@" 2>&1 | tee -a "$LOG"
  local rc=${PIPESTATUS[0]}
  echo "[exit=$rc elapsed=$((SECONDS - t0))s]" | tee -a "$LOG"
  return "$rc"
}

echo "== Tenancy check ==" | tee -a "$LOG"
run "gcloud version" gcloud version
run "active account" gcloud config get-value account
run "project parent (empty = no Organization)" \
  gcloud projects describe "$P" --format='value(parent.type,parent.id)'
parent=$(gcloud projects describe "$P" --format='value(parent.type)' 2>/dev/null)
if [ -n "$parent" ]; then
  echo "!! $P has a parent ($parent). This probe must run on a no-Organization project." | tee -a "$LOG"
  echo "!! Results would not reflect learner reality. Stopping." | tee -a "$LOG"
  exit 1
fi
run "billing link" gcloud billing projects describe "$P"

echo; echo "== API enablement (timed, for V4 propagation notes) ==" | tee -a "$LOG"
run "enable APIs" gcloud services enable \
  cloudresourcemanager.googleapis.com orgpolicy.googleapis.com \
  securitycenter.googleapis.com securitycentermanagement.googleapis.com \
  cloudasset.googleapis.com storage.googleapis.com --project="$P"

echo; echo "== V1: Security Command Center at project scope ==" | tee -a "$LOG"
run "V1a SHA service state (project)" \
  gcloud scc manage services describe security-health-analytics --project="$P"
run "V1b findings list (project, v2 global)" \
  gcloud scc findings list "projects/$P" --location=global --limit=5
run "V1c sources list (project)" gcloud scc sources describe "projects/$P" --source-display-name="Security Health Analytics"
echo ">> If V1a/V1b fail, activate SCC Standard for the project in the console" | tee -a "$LOG"
echo ">> (Security > Security Command Center > Get started) and rerun this script." | tee -a "$LOG"

echo; echo "== V2: Org Policy at project scope ==" | tee -a "$LOG"
ME=$(gcloud config get-value account 2>/dev/null)
run "V2-pre can Org Policy Admin be granted at project scope?" \
  gcloud projects add-iam-policy-binding "$P" --member="user:$ME" \
    --role=roles/orgpolicy.policyAdmin --condition=None
run "V2a constraints visible at project scope (storage/iam, incl. unset)" \
  gcloud org-policies list --project="$P" --show-unset \
    --filter='constraint ~ ^constraints/(storage|iam)\.' --format='value(constraint)'
for c in storage.publicAccessPrevention storage.uniformBucketLevelAccess iam.managed.disableServiceAccountKeyCreation; do
  run "V2b effective policy: $c" gcloud org-policies describe "$c" --project="$P" --effective
  f=$(mktemp)
  cat > "$f" <<EOF
name: projects/$P/policies/$c
dryRunSpec:
  rules:
  - enforce: true
EOF
  run "V2c set dryRunSpec: $c" gcloud org-policies set-policy "$f" --update-mask=dryRunSpec
  run "V2d read back: $c" gcloud org-policies describe "$c" --project="$P"
  run "V2e remove probe policy: $c" gcloud org-policies delete "$c" --project="$P"
  rm -f "$f"
done

echo; echo "== V2f: does a new project block public buckets by default? ==" | tee -a "$LOG"
B2="${P}-v2-public-probe"
run "create test bucket" gcloud storage buckets create "gs://$B2" --project="$P" \
  --location="$REGION" --uniform-bucket-level-access
run "describe PAP setting" gcloud storage buckets describe "gs://$B2" \
  --format='value(public_access_prevention)'
run "attempt public grant (allUsers objectViewer)" \
  gcloud storage buckets add-iam-policy-binding "gs://$B2" \
  --member=allUsers --role=roles/storage.objectViewer
run "delete test bucket" gcloud storage rm --recursive "gs://$B2"

echo; echo "== V3: Bucket Lock with a 60-second retention ==" | tee -a "$LOG"
B3="${P}-v3-lock-probe"
run "create bucket with 60s retention" gcloud storage buckets create "gs://$B3" \
  --project="$P" --location="$REGION" --uniform-bucket-level-access \
  --public-access-prevention --retention-period=60s
# --quiet answers the lock prompt with its default (No) and aborts, so answer yes explicitly.
run "LOCK retention policy (irreversible, 60s window)" \
  bash -c "printf 'y\\n' | gcloud storage buckets update 'gs://$B3' --lock-retention-period"
run "confirm lock" gcloud storage buckets describe "gs://$B3" --format='value(retention_policy)'
echo "probe" > /tmp/cgegcp-v3-probe.txt
run "upload object" gcloud storage cp /tmp/cgegcp-v3-probe.txt "gs://$B3/probe.txt"
run "attempt delete inside retention (expected to FAIL)" gcloud storage rm "gs://$B3/probe.txt"
run "attempt bucket delete inside retention (expected to FAIL)" gcloud storage buckets delete "gs://$B3" --quiet
echo ">> waiting 75s for retention to expire" | tee -a "$LOG"; sleep 75
run "delete object after retention" gcloud storage rm "gs://$B3/probe.txt"
run "delete bucket after retention" gcloud storage buckets delete "gs://$B3" --quiet
rm -f /tmp/cgegcp-v3-probe.txt

echo; echo "Done. Raw log: $LOG" | tee -a "$LOG"
