#!/usr/bin/env bash
# Bootstrap the Terraform remote-state bucket for the CGE-GCP pipeline.
# Run once, before your first `terraform init` in stages/00-foundation.
# Chicken-and-egg: the state bucket can't manage itself, so this one piece is a script.
# Usage: labs/03-foundation/bootstrap.sh [REGION]
set -euo pipefail

P=$(gcloud config get-value project 2>/dev/null)
[ -n "$P" ] || { echo "No project set. Run: gcloud config set project <YOUR_PROJECT_ID>"; exit 1; }
REGION="${1:-us-central1}"
BUCKET="${P}-tfstate"
DIR="$(cd "$(dirname "$0")" && pwd)"

echo ">> Project: $P"
echo ">> State bucket: gs://$BUCKET (versioned, uniform access, public access prevention enforced)"
gcloud services enable storage.googleapis.com --project="$P"
if gcloud storage buckets describe "gs://$BUCKET" --project="$P" >/dev/null 2>&1; then
  echo "   already exists, leaving it as is"
else
  gcloud storage buckets create "gs://$BUCKET" --project="$P" --location="$REGION" \
    --uniform-bucket-level-access --public-access-prevention
fi
gcloud storage buckets update "gs://$BUCKET" --versioning

cat > "$DIR/backend.hcl" <<HCL
bucket = "$BUCKET"
HCL
# One tfvars file, copied into every stage, so no stage ever needs -var flags.
for stage in "$DIR"/../../stages/*/; do
  cat > "$stage/project.auto.tfvars" <<TFVARS
project_id   = "$P"
region       = "$REGION"
state_bucket = "$BUCKET"
TFVARS
done
echo ">> Wrote $DIR/backend.hcl and project.auto.tfvars in every stage"
echo ">> Next: cd stages/00-foundation && terraform init -backend-config=../../labs/03-foundation/backend.hcl"
