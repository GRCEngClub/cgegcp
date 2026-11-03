"""Run the pipeline's five checks from your laptop, against your project, and print the results.

Same code the Stage 3 collector runs (functions/collector), minus the Firestore write.
Usage (repo root):  python3 labs/02-toolkit/run_checks.py <PROJECT_ID> [CHECK_ID]
"""
import os
import pathlib
import sys

if len(sys.argv) < 2:
    sys.exit(__doc__)
os.environ["GCP_PROJECT_ID"] = sys.argv[1]
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "functions" / "collector"))
import main  # noqa: E402  (the collector module, imported after GCP_PROJECT_ID is set)

token = os.environ.get("GOOGLE_OAUTH_ACCESS_TOKEN")  # optional; ADC otherwise
if token:
    from google.oauth2.credentials import Credentials
    _client = main.asset_v1.AssetServiceClient
    main.asset_v1.AssetServiceClient = lambda: _client(
        credentials=Credentials(token, quota_project_id=sys.argv[1]))

only = sys.argv[2] if len(sys.argv) > 2 else None
for r in main.run_checks():
    if only and r["check_id"] != only:
        continue
    print(f'{r["check_id"]}  {r["status"].upper():4}  {r["resource"]}')
    if r["status"] == "fail":
        print(f'      evidence: {r["evidence"]}')
