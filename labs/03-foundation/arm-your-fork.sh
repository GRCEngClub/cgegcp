#!/usr/bin/env bash
# Connect YOUR fork's GitHub Actions to YOUR project with Workload Identity Federation.
# No keys, no secrets: GitHub proves its identity with a short-lived token on every run,
# and Google trusts tokens from exactly one repository, the one you name here.
#
# Usage: labs/03-foundation/arm-your-fork.sh <your-github-user>/<your-fork-name>
#   e.g. labs/03-foundation/arm-your-fork.sh octocat/cgegcp
# The argument is REQUIRED and has no default, on purpose: a default would make every
# learner's project trust someone else's repository.
#
# CI only PLANS. The roles in ci-roles.txt are read-only; applying stays on your machine.
set -euo pipefail

REPO="${1:-}"
[[ "$REPO" =~ ^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$ ]] || {
  echo "Usage: $0 <your-github-user>/<your-fork-name>   (required, no default)"; exit 1; }
P=$(gcloud config get-value project 2>/dev/null)
[ -n "$P" ] || { echo "No project set. Run: gcloud config set project <YOUR_PROJECT_ID>"; exit 1; }
NUM=$(gcloud projects describe "$P" --format='value(projectNumber)')
POOL="${POOL:-github}"
DIR="$(cd "$(dirname "$0")" && pwd)"
export CLOUDSDK_CORE_PROJECT="$P" CLOUDSDK_BILLING_QUOTA_PROJECT="$P"

echo ">> Trusting GitHub Actions in $REPO, and nothing else, for project $P"
gcloud iam workload-identity-pools describe "$POOL" --location=global >/dev/null 2>&1 || \
  gcloud iam workload-identity-pools create "$POOL" --location=global \
    --display-name="GitHub Actions" --description="CI for $REPO. managed-by: cgegcp"
gcloud iam workload-identity-pools providers describe github --location=global \
    --workload-identity-pool="$POOL" >/dev/null 2>&1 || \
  gcloud iam workload-identity-pools providers create-oidc github --location=global \
    --workload-identity-pool="$POOL" --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
    --attribute-condition="assertion.repository == '$REPO'"

PRINCIPAL="principalSet://iam.googleapis.com/projects/$NUM/locations/global/workloadIdentityPools/$POOL/attribute.repository/$REPO"
grep -v '^#' "$DIR/ci-roles.txt" | while read -r role; do
  [ -n "$role" ] || continue
  gcloud projects add-iam-policy-binding "$P" --member="$PRINCIPAL" --role="$role" \
    --condition=None --format=none
done
gcloud storage buckets add-iam-policy-binding "gs://$P-tfstate" --member="$PRINCIPAL" \
  --role=roles/storage.objectUser --format=none
gcloud storage buckets add-iam-policy-binding "gs://$P-fn-source" --member="$PRINCIPAL" \
  --role=roles/storage.objectViewer --format=none 2>/dev/null || \
  echo "   (fn-source bucket not created yet: rerun this script after Lab 4)"

cat <<OUT

>> Done. In your fork on GitHub: Settings > Secrets and variables > Actions > Variables tab.
   Add these two repository VARIABLES (not secrets; there is nothing secret to store):

   GCP_PROJECT_ID     = $P
   GCP_WIF_PROVIDER   = projects/$NUM/locations/global/workloadIdentityPools/$POOL/providers/github

   Until both exist, the workflows skip themselves. The upstream repo never has them.
OUT
