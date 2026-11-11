"""Reproducible production-source inventory; tests/examples/generated interfaces excluded."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
files=[]
for p in sorted(root.glob("*.mbt")):
    if p.name.endswith(("_test.mbt","_wbtest.mbt")):
        continue
    lines=p.read_text(encoding="utf-8").splitlines()
    active=[s for s in lines if s.strip() and not s.lstrip().startswith("//")]
    files.append({"path":p.name,"physical_lines":len(lines),"nonblank_noncomment_lines":len(active)})
total=sum(f["physical_lines"] for f in files)
print(json.dumps({"production_files":files,"physical_lines":total,"nonblank_noncomment_lines":sum(f["nonblank_noncomment_lines"] for f in files)},ensure_ascii=False,indent=2))
assert total >= 1500, "Substantive production source floor not met"
