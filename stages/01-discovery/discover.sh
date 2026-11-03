#!/usr/bin/env bash
# Stage 1 discovery probe, called by Terraform's external data source.
# Reads only. Prints one flat JSON object of strings (the external provider's contract).
# Every answer is present / absent / different, or a count.
set -euo pipefail
P=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["project_id"])')
export CLOUDSDK_CORE_PROJECT="$P" CLOUDSDK_BILLING_QUOTA_PROJECT="$P"

# 1. Data Access logs for Cloud Storage: both DATA_READ and DATA_WRITE = present.
audit=$(gcloud projects get-iam-policy "$P" --format=json | python3 -c '
import json,sys
p=json.load(sys.stdin); types=set()
for c in p.get("auditConfigs",[]):
    if c.get("service") in ("storage.googleapis.com","allServices"):
        types |= {l["logType"] for l in c.get("auditLogConfigs",[])}
need={"DATA_READ","DATA_WRITE"}
print("present" if need<=types else ("different" if types else "absent"))')

# 2. Audit log sink to the long-retention bucket. Resources the pipeline created carry
#    the marker "managed-by: cgegcp" so later runs keep managing them instead of
#    mistaking them for someone else's history.
sink_desc=$(gcloud logging sinks describe grc-audit-sink --format='value(description)' 2>/dev/null || echo "__absent__")
case "$sink_desc" in
  __absent__)          sink=absent ;;
  *"managed-by: cgegcp"*) sink=pipeline ;;
  *)                   sink=different ;;
esac

# 3. Buckets missing either guardrail (public access prevention enforced, uniform access on).
weak=$(gcloud storage buckets list --format=json | python3 -c '
import json,sys
b=json.load(sys.stdin) or []
print(sum(1 for x in b if x.get("public_access_prevention")!="enforced" or not x.get("uniform_bucket_level_access")))')

# 4. User-managed service account keys (each one is a finding).
keys=0
for sa in $(gcloud iam service-accounts list --format='value(email)'); do
  n=$(gcloud iam service-accounts keys list --iam-account="$sa" --managed-by=user --format='value(name)' | wc -l | tr -d ' ')
  keys=$((keys + n))
done

printf '{"data_access_storage":"%s","audit_sink":"%s","buckets_missing_guardrails":"%s","user_managed_sa_keys":"%s"}\n' \
  "$audit" "$sink" "$weak" "$keys"
