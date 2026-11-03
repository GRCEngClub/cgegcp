#!/usr/bin/env bash
# Run the mechanical half of the capstone rubric before the grader does (docs/RUBRIC.md).
# If a check is red here, it will be red there. It cannot judge run history or writing;
# those need your project and a human eye.
#   ./self-check.sh        local run (terraform, conftest, shellcheck if installed)
#   ./self-check.sh --ci   the same, as guide-ci.yml runs it (no cloud access needed)
set -uo pipefail
cd "$(dirname "$0")" || exit 1

PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS+1)); }
bad() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

echo "== Repo shape =="
for s in 00-foundation 01-discovery 02-activation 03-evidence-store 04-reporting 05-narrative 06-enforcement; do
  if ls "stages/$s"/*.tf >/dev/null 2>&1; then ok "stages/$s has Terraform"; else bad "stages/$s is EMPTY or missing"; fi
done
for f in functions/collector/main.py functions/collector/checks.py functions/collector/controls.json \
         functions/reports/main.py functions/remediator/main.py; do
  [ -s "$f" ] && ok "$f present" || bad "$f missing"
done
for f in README.md docs/CONTROLS.md docs/RUBRIC.md; do
  [ -s "$f" ] && ok "$f present" || bad "$f missing (auto-fail trigger)"
done
grep -qiE '^\*\*Tenancy' README.md 2>/dev/null && ok "README states tenancy" || bad "README has no **Tenancy...** line"

echo "== IaC quality =="
if terraform fmt -check -recursive stages/ >/dev/null 2>&1; then ok "terraform fmt clean"; else bad "terraform fmt has diffs (run: terraform fmt -recursive stages/)"; fi
for d in stages/*/; do
  name=$(basename "$d")
  # Already-initialized stages validate as they are (re-init would need live credentials).
  if (cd "$d" && { [ -d .terraform ] || terraform init -backend=false -input=false >/dev/null 2>&1; } \
        && terraform validate >/dev/null 2>&1); then
    ok "terraform validate: $name"
  else
    bad "terraform validate fails: $name"
  fi
done

echo "== Evidence integrity =="
grep -rqE --include='*.tf' 'is_locked *= *var\.lock_reports_bucket|is_locked *= *true' stages/03-evidence-store/ \
  && ok "reports bucket retention lock configured" || bad "no retention lock on the reports bucket"
grep -q 'run_id' functions/collector/main.py && ok "collector stamps run lineage (run_id)" || bad "collector has no run_id"
grep -q 'collection("assessments")' functions/reports/main.py && ! grep -q 'asset_v1' functions/reports/main.py \
  && ok "reports read Firestore only" || bad "reports read something other than the evidence store"

echo "== Identity design =="
if grep -rqE --include='*.tf' 'role *= *"roles/(owner|editor|viewer)"' stages/; then bad "a basic role is granted in stages/"; else ok "no basic roles granted"; fi
if grep -rq --include='*.tf' 'google_service_account_key' stages/; then bad "a service account key is created in stages/"; else ok "no service account keys"; fi
grep -q 'service_account_email = local.remediator.email' stages/06-enforcement/main.tf \
  && ok "remediator runs as its own identity" || bad "remediator identity not dedicated"

echo "== Policy gate, both directions =="
if command -v conftest >/dev/null 2>&1; then
  conftest test --no-color -p policy policy/tests/good-plan.json >/dev/null 2>&1 \
    && ok "gate passes a compliant plan" || bad "gate FAILS a compliant plan"
  n=$(conftest test --no-color -p policy policy/tests/bad-plan.json 2>/dev/null | grep -c '^FAIL')
  [ "$n" -ge 5 ] && ok "gate denies all 5 violations in the bad plan" || bad "gate denied only $n of 5 violations (silent pass?)"
  conftest test --no-color -p policy policy/tests/remediator-wrong-sa.json >/dev/null 2>&1 \
    && bad "gate allowed a remediator on the wrong identity" || ok "gate denies a remediator on the wrong identity"
else
  bad "conftest not installed (brew install conftest)"
fi

echo "== Lab guide code blocks parse =="
tmp=$(mktemp -d); blocks=0; broken=0
for g in labs/*/README.md docs/SETUP.md; do
  [ -f "$g" ] || continue
  awk -v dir="$tmp" -v base="$(echo "$g" | tr '/' '_')" '
    /^```bash$/ {n++; f=dir "/" base "." n ".sh"; inb=1; next}
    /^```$/ && inb {inb=0; close(f); next}
    inb {print > f}' "$g"
done
for f in "$tmp"/*.sh; do
  [ -e "$f" ] || continue
  blocks=$((blocks+1))
  bash -n "$f" 2>/dev/null || { broken=$((broken+1)); echo "    syntax error: $(basename "$f")"; }
done
rm -rf "$tmp"
[ "$broken" -eq 0 ] && ok "$blocks bash blocks in the guides parse" || bad "$broken of $blocks guide bash blocks do not parse"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -S warning labs/*/*.sh stages/01-discovery/discover.sh self-check.sh >/dev/null 2>&1 \
    && ok "shellcheck clean on lab scripts" || bad "shellcheck warnings in lab scripts"
fi

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
