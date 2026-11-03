"""Stage 4 reporter: Firestore in, auditor deliverables out to the locked bucket.

Runs as grc-reporter, which can READ Firestore and CREATE objects in the reports bucket.
It cannot write Firestore and cannot call Asset Inventory: reports come from the evidence
store and nothing else, so every report agrees with every other report.

?report=poam  every open failure with its controls, severity and days open (JSON + CSV)
?report=sar   assessment results summarized by control (Markdown)
?report=ssp   OSCAL 1.1.2 System Security Plan built from the same data (JSON)
"""
import csv
import datetime
import io
import json
import os
import uuid

import functions_framework
from google.cloud import firestore, storage

PROJECT = os.environ["GCP_PROJECT_ID"]
BUCKET = os.environ["REPORTS_BUCKET"]
NS = uuid.UUID("6f1c3c2e-6c1b-4c55-9d0e-6367656763a0")  # stable UUIDs for OSCAL objects


def load(db):
    assessments = [d.to_dict() | {"id": d.id} for d in db.collection("assessments").stream()]
    mappings = {d.id: d.to_dict() for d in db.collection("mappings").stream()}
    frameworks = {d.id: d.to_dict() for d in db.collection("frameworks").stream()}
    return assessments, mappings, frameworks


def put(name, body, content_type):
    # Unique names: the bucket is locked, so nothing is ever overwritten.
    blob = storage.Client(project=PROJECT).bucket(BUCKET).blob(name)
    blob.upload_from_string(body, content_type=content_type)
    return f"gs://{BUCKET}/{name}"


def poam(assessments, now):
    rows = []
    for a in sorted(assessments, key=lambda x: (x["severity"] != "high", x["check_id"], x["resource"])):
        if a["status"] != "fail":
            continue
        opened = a.get("first_failed_at") or a["collected_at"]
        rows.append({
            "poam_id": a["id"], "check_id": a["check_id"], "weakness": a["title"],
            "resource": a["resource"], "severity": a["severity"],
            "csf": ";".join(a["csf"]), "sp800_53": ";".join(a["sp800_53"]),
            "first_detected": opened.isoformat(), "days_open": (now - opened).days,
            "last_collected": a["collected_at"].isoformat(), "run_id": a["run_id"],
        })
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=list(rows[0]) if rows else ["poam_id"])
    w.writeheader(); w.writerows(rows)
    return rows, buf.getvalue()


def sar(assessments, mappings, frameworks, now):
    by_ctl = {}
    for a in assessments:
        for c in a["csf"]:
            s = by_ctl.setdefault(c, {"pass": 0, "fail": 0, "resolved": 0})
            s[a["status"]] = s.get(a["status"], 0) + 1
    lines = [f"# Security Assessment Report: {PROJECT}", "",
             f"Generated {now:%Y-%m-%d %H:%M} UTC from the evidence store (Firestore). "
             f"{len(assessments)} assessment results.", "",
             "| CSF 2.0 | Outcome | Pass | Fail | Result |", "|---|---|---|---|---|"]
    for c in sorted(by_ctl):
        s = by_ctl[c]
        title = frameworks.get(c, {}).get("title", "")
        lines.append(f"| {c} | {title} | {s['pass']} | {s['fail']} | {'Not satisfied' if s['fail'] else 'Satisfied'} |")
    lines += ["", "## Checks", ""]
    for cid, m in sorted(mappings.items()):
        rs = [a for a in assessments if a["check_id"] == cid]
        fails = [a["resource"] for a in rs if a["status"] == "fail"]
        lines.append(f"- **{cid}** {m['title']} (800-53: {', '.join(m['sp800_53'])}): "
                     f"{len(rs) - len(fails)} pass, {len(fails)} fail")
        lines += [f"  - fail: `{r}`" for r in fails]
    return "\n".join(lines) + "\n"


def ssp(assessments, mappings, now):
    comp = str(uuid.uuid5(NS, f"{PROJECT}/component"))
    status_by_ctl = {}
    for a in assessments:
        for c in a["sp800_53"]:
            status_by_ctl.setdefault(c.lower(), set()).add(a["status"])
    reqs = []
    for ctl, statuses in sorted(status_by_ctl.items()):
        checks = sorted(k for k, m in mappings.items() if ctl.upper() in m["sp800_53"])
        reqs.append({
            "uuid": str(uuid.uuid5(NS, f"{PROJECT}/{ctl}")),
            "control-id": ctl,
            "by-components": [{
                "component-uuid": comp,
                "uuid": str(uuid.uuid5(NS, f"{PROJECT}/{ctl}/by")),
                "description": f"Tested daily by {', '.join(checks)} over Cloud Asset Inventory; "
                               f"results stored in Firestore and reported from there.",
                "implementation-status": {"state": "partial" if "fail" in statuses else "implemented"},
            }],
        })
    level = "fips-199-moderate"
    doc = {"system-security-plan": {
        "uuid": str(uuid.uuid5(NS, f"{PROJECT}/ssp/{now:%Y%m%d%H%M%S}")),
        "metadata": {"title": f"System Security Plan: {PROJECT}", "last-modified": now.isoformat(),
                     "version": now.strftime("%Y.%m.%d"), "oscal-version": "1.1.2"},
        "import-profile": {"href": "https://raw.githubusercontent.com/usnistgov/oscal-content/main/nist.gov/SP800-53/rev5/json/NIST_SP-800-53_rev5_MODERATE-baseline_profile.json"},
        "system-characteristics": {
            "system-ids": [{"identifier-type": "https://ietf.org/rfc/rfc4122", "id": comp}],
            "system-name": PROJECT,
            "description": "Google Cloud project assessed by the CGE-GCP evidence pipeline.",
            "security-sensitivity-level": level,
            "system-information": {"information-types": [{
                "uuid": str(uuid.uuid5(NS, f"{PROJECT}/info")),
                "title": "Compliance evidence", "description": "Check results and generated reports.",
                "confidentiality-impact": {"base": level}, "integrity-impact": {"base": level},
                "availability-impact": {"base": level}}]},
            "security-impact-level": {"security-objective-confidentiality": level,
                                      "security-objective-integrity": level,
                                      "security-objective-availability": level},
            "status": {"state": "operational"},
            "authorization-boundary": {"description": f"The single Google Cloud project {PROJECT}; no Organization."},
        },
        "system-implementation": {
            "users": [{"uuid": str(uuid.uuid5(NS, f"{PROJECT}/user/owner")), "title": "Project owner"}],
            "components": [{"uuid": comp, "type": "this-system", "title": PROJECT,
                            "description": "The assessed project.", "status": {"state": "operational"}}],
        },
        "control-implementation": {
            "description": "Implementation status derived from the latest check results in the evidence store.",
            "implemented-requirements": reqs,
        },
    }}
    return json.dumps(doc, indent=2, default=str)


@functions_framework.http
def handler(request):
    kind = request.args.get("report", "poam")
    now = datetime.datetime.now(datetime.timezone.utc)
    stamp = now.strftime("%Y-%m-%dT%H%M%SZ")
    assessments, mappings, frameworks = load(firestore.Client(project=PROJECT))
    out = []
    if kind == "poam":
        rows, csv_body = poam(assessments, now)
        out.append(put(f"poam/{stamp}-poam.json", json.dumps(rows, indent=2), "application/json"))
        out.append(put(f"poam/{stamp}-poam.csv", csv_body, "text/csv"))
    elif kind == "sar":
        out.append(put(f"sar/{stamp}-sar.md", sar(assessments, mappings, frameworks, now), "text/markdown"))
    elif kind == "ssp":
        out.append(put(f"ssp/{stamp}-ssp.json", ssp(assessments, mappings, now), "application/json"))
    else:
        return {"error": f"unknown report {kind}"}, 400
    summary = {"report": kind, "written": out, "assessments_read": len(assessments)}
    print(json.dumps({"severity": "INFO", "message": "report written", **summary}))
    return summary
