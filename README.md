# cgegcp: CGE-GCP labs and capstone starter

**Tenancy assumption: one Google Cloud project on a personal @gmail.com account, with no Organization above it.** Nothing in this repo needs an Organization. If you work inside one, see "If you have an Organization" in `docs/SETUP.md`.

This is the lab and capstone repo for **Certified GRC Engineer, GCP Specialty (CGE-GCP)** from the GRC Engineering Club Training Academy. You build a six-stage GRC engineering pipeline in your own project:

| Stage | Folder | What it does | Runs as |
|---|---|---|---|
| 0 | `stages/00-foundation` | APIs as code; six pipeline identities created with zero permissions | you |
| 1 | `stages/01-discovery` | Measures what's running. Changes nothing. Outputs a gap map | you / CI (read-only) |
| 2 | `stages/02-activation` | Enables only what's missing: Data Access logs, 365-day audit log bucket + sink | you |
| 3 | `stages/03-evidence-store` | Firestore evidence store, locked reports bucket, daily collector running five checks over Cloud Asset Inventory | `grc-collector` |
| 4 | `stages/04-reporting` | POA&M, SAR and OSCAL 1.1.2 SSP from Firestore only | `grc-reporter` |
| 5 | `stages/05-narrative` | Optional Gemini weekly digest. Describes, never decides | `grc-narrator` |
| 6 | `stages/06-enforcement` | Fixes public buckets on a ladder: report-only → approve → auto | `grc-remediator` |

The policy gate (`policy/*.rego`) checks every pull request's plan. `drift.yml` plans nightly and opens an issue if reality and code disagree.

## Start here

1. `docs/SETUP.md` (account, budget, logins), then the labs in order: `labs/01-sandbox` to `labs/06-loop`.
2. One repo for every lab and the capstone: fork it, and build in your fork.
3. Before you submit: `./self-check.sh`, then read `docs/RUBRIC.md`.

Every expected output in the lab guides comes from a real run on a fresh project, recorded in `docs/VALIDATION-LOG.md`. If something surprises you, look there first.

*Built by the community, for the community · www.grcengclub.com*
