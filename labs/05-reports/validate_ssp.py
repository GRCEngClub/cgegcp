import json, re, sys, jsonschema
# OSCAL patterns use XML Schema \p{..} classes; Python's re lacks them. Swap in the
# 'regex' module if present, otherwise approximate so structure is still validated.
try:
    import regex as rx
except ImportError:
    rx = None
schema = json.load(open(sys.argv[1])); doc = json.load(open(sys.argv[2]))
def fix(o):
    if isinstance(o, dict):
        if "pattern" in o and rx is None and "\\p{" in o["pattern"]:
            o["pattern"] = re.sub(r"\\p\{[^}]+\}", "\\\\w", o["pattern"])
        for v in o.values(): fix(v)
    elif isinstance(o, list):
        for v in o: fix(v)
fix(schema)
v = jsonschema.Draft7Validator(schema, format_checker=jsonschema.FormatChecker())
errs = sorted(v.iter_errors(doc), key=lambda e: list(e.path))
for e in errs[:15]: print("ERROR at", "/".join(map(str, e.path)), ":", e.message[:200])
print("VALID" if not errs else f"{len(errs)} errors")
