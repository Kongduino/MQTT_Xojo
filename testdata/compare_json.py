# Compares the JSON the Xojo app published (the "  JSON -> topic: {...}" lines in a saved
# MessagesArea output) with the official converter's JSON in testdata/*.json.
# Usage: python3 compare_json.py [saved output]   (default: the newest results/result*.txt)
import sys, glob, os, json
here = os.path.dirname(os.path.abspath(__file__))
if len(sys.argv) > 1:
    output = sys.argv[1]
else:
    candidates = glob.glob(os.path.join(here, "..", "results", "result*.txt")) + glob.glob(os.path.join(here, "..", "result*.txt"))
    if not candidates:
        sys.exit("No saved output given and no result*.txt in results/.\nUsage: python3 compare_json.py <saved output>")
    output = max(candidates, key=os.path.getmtime)
print("Comparing", os.path.relpath(output))
golden = {}
for f in sorted(glob.glob(os.path.join(here, "*.json"))):
    text = open(f).read().strip()
    if text:
        golden[json.loads(text)["id"]] = (os.path.basename(f), text)
got = {}
for line in open(output, encoding="utf-8"):
    if line.startswith("  JSON -> "):
        text = line.split(": ", 1)[1].strip()
        got[json.loads(text)["id"]] = text
ok = 0
for pid, (name, exp) in golden.items():
    if pid not in got:
        print(f"MISSING   {name}")
    elif got[pid] == exp:
        ok += 1
    else:
        print(f"DIFFERENT {name}\n  converter: {exp}\n  xojo:      {got[pid]}")
extra = set(got) - set(golden)
for pid in extra:
    print(f"EXTRA     id {pid}: {got[pid]}")
print(f"{ok}/{len(golden)} identical" + (f", {len(extra)} unexpected" if extra else ""))
