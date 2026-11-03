# CGE-GCP Capstone Rubric

Your capstone is the pipeline itself, deployed as code in your own project and submitted as a public GitHub repo. This rubric is public on purpose: read it on day one, and run it against yourself before you submit.

The machine-graded version lives at **cert.grcengclub.com/rubric/cge-gcp**. If it and this file ever disagree, the Academy page wins.

**Pass = weighted average ≥ 70 across five dimensions AND no auto-fail triggers.** Two attempts, 24-hour cooldown between them. Written feedback either way. Appeals after both attempts: hello@grcengclub.com.

## Submission requirements

- Public GitHub repository, ≤ 50 MB, ≤ 10,000 files
- README.md that opens with your tenancy statement and explains how to deploy from an empty project
- Terraform for at least: the foundation, stages 1 to 3 (discovery, activation, evidence store with a locked reports bucket), and Stage 6 remediation in `report_only` mode or higher
- At least two reports generated from Firestore only, with real run history (the daily schedule, not a burst of manual runs the night before)
- The gate and drift workflows, armed on your fork
- `docs/CONTROLS.md` current with your code
- An `evidence/` folder with your WORM proof (failed delete), separation-of-duties proof (reporter denied), and a gate failure from a closed test PR
- Stage 5 is optional extra credit and never graded

## The five dimensions (20% each)

### 1. Infrastructure-as-code quality
One root module per stage with separate state; pinned provider; discovery-first (activation acts only on the measured gap and keeps managing what it created); APIs as code with `disable_on_destroy = false`; additive IAM only (`*_iam_member`).

### 2. Control implementation and identity design
Every pipeline job runs as its own identity with only its job's roles: no basic roles, no keys. Collector and reporter separated. Remediator on a custom role. **At least one check of your own beyond the five starters**, mapped in `controls.json` and `CONTROLS.md`.

### 3. Evidence integrity and traceability
Locked reports bucket, with the failed-delete proof. Collection stamped with `run_id` and `collected_at`, with deterministic document IDs. Reports read from Firestore only. Any POA&M line traceable to its Firestore document and the asset record behind it.

### 4. Pipeline operations
Run history that accumulates over time. The gate demonstrably blocks a non-compliant plan. Remediation behind a human approval or with a written justification for `auto`. Drift detection running.

### 5. Documentation and control mapping
Cold-readable README with deploy order. CONTROLS.md current with the code. Blast-radius notes on the remediator. The reason behind each non-obvious choice is written down.

## Auto-fail triggers

- Repository private or inaccessible at grading time
- Any stored credential: service account key, token, password (the design needs **zero**)
- Real PII or production credentials in the repo
- An unmodified or trivially modified fork of GRCEngClub/cgegcp
- No README

## Before you submit

```bash
./self-check.sh
```

This runs the mechanical half of this rubric locally. It can't judge your writing or your run history, but if it's red, the grader will be too.
