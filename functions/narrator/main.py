"""Stage 5 narrator (optional, walkthrough-only, never graded).

Describe, never decide. Reads the latest SAR and POA&M, which were already generated from
the evidence store, and asks Gemini for a plain-language weekly digest. It never reads raw
findings, never assigns severity, never changes anything. Runs as grc-narrator: read the
reports bucket, create one object, call Vertex AI. Delete this stage and the pipeline still works.
"""
import datetime
import json
import os

import functions_framework
import google.auth
import google.auth.transport.requests
import requests
from google.cloud import storage

PROJECT = os.environ["GCP_PROJECT_ID"]
BUCKET = os.environ["REPORTS_BUCKET"]
MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.5-flash-lite")

PROMPT = """You write a weekly compliance digest for people who will never open a POA&M.
Rules:
- Use ONLY the two reports below. Do not add facts, advice, severities or opinions.
- After every sentence that states a fact, cite its source as [file:line].
- If nothing failed, say "No open items." and stop.
- Plain language, at most 150 words. No headings, no bullet lists.

{reports}"""


def latest(bucket, prefix, suffix):
    blobs = [b for b in bucket.list_blobs(prefix=prefix) if b.name.endswith(suffix)]
    return max(blobs, key=lambda b: b.name) if blobs else None


def numbered(name, text):
    return f"=== {name} ===\n" + "\n".join(f"{i}: {l}" for i, l in enumerate(text.splitlines(), 1))


@functions_framework.http
def handler(request):
    bucket = storage.Client(project=PROJECT).bucket(BUCKET)
    sources = [b for b in (latest(bucket, "sar/", ".md"), latest(bucket, "poam/", ".csv")) if b]
    if len(sources) < 2:
        return {"error": "need a SAR and a POA&M in the reports bucket first (run Stage 4)"}, 409
    reports = "\n\n".join(numbered(b.name, b.download_as_text()) for b in sources)

    creds, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    creds.refresh(google.auth.transport.requests.Request())
    url = (f"https://aiplatform.googleapis.com/v1/projects/{PROJECT}/locations/global"
           f"/publishers/google/models/{MODEL}:generateContent")
    r = requests.post(url, headers={"Authorization": f"Bearer {creds.token}"}, timeout=120, json={
        "contents": [{"role": "user", "parts": [{"text": PROMPT.format(reports=reports)}]}],
        "generationConfig": {"temperature": 0},
    })
    r.raise_for_status()
    text = r.json()["candidates"][0]["content"]["parts"][0]["text"].strip()

    now = datetime.datetime.now(datetime.timezone.utc)
    body = (f"AI-generated summary (Vertex AI {MODEL}). It describes the reports below; it decides nothing.\n"
            f"Sources: {', '.join(b.name for b in sources)}\n\n{text}\n")
    name = f"digest/{now:%Y-%m-%dT%H%M%SZ}-digest.md"
    bucket.blob(name).upload_from_string(body, content_type="text/markdown")
    print(json.dumps({"severity": "INFO", "message": "digest written", "object": name, "model": MODEL}))
    return {"written": f"gs://{BUCKET}/{name}", "model": MODEL, "sources": [b.name for b in sources]}
