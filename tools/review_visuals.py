"""Launch bounded native visual reviews through GodotClient."""
import argparse
import json
from pathlib import Path
import sys
import time

from _project import ROOT, GodotClient, import_project, checked_godot

p = argparse.ArgumentParser()
p.add_argument("mode", choices=["art", "ui", "rig"])
p.add_argument("--all-rigs", action="store_true")
p.add_argument("--ids", default="")
p.add_argument("--width", type=int, default=1280)
p.add_argument("--height", type=int, default=720)
args = p.parse_args()
config = json.loads((ROOT / "engine.json").read_text(encoding="utf-8"))
client = GodotClient(project_path=str(ROOT / "project"), godot_executable=config["executable"])
log = ROOT / "evidence" / f"visual-{args.mode}.log"
log.parent.mkdir(parents=True, exist_ok=True)
log.write_text("", encoding="utf-8")
flags = ["--log-file", str(log), "--resolution", f"{args.width}x{args.height}", "--max-fps", "60", "--"]
flags += ["--asset-ids=" + args.ids] if args.mode == "art" else (["--all-rigs"] if args.all_rigs else []) if args.mode == "rig" else ["--visual-qa"]
scene = {"art":"res://tests/art_review.tscn", "rig":"res://tests/rig_qa.tscn", "ui":""}[args.mode]
result = client.runtime.launch_game(scene_path=scene, extra_args=flags)
if not result["ok"]:
    raise SystemExit(result["errors"])
print("Review process", result["payload"]["process_id"], flush=True)
marker = {"art":"ART_REVIEW_COMPLETE","ui":"VISUAL_QA_COMPLETE","rig":"RIG_QA_COMPLETE"}[args.mode]
deadline = time.monotonic() + 180
try:
    while time.monotonic() < deadline:
        text = log.read_text(encoding="utf-8", errors="replace")
        if "SCRIPT ERROR" in text or "ERROR:" in text:
            raise SystemExit(text[-5000:])
        if marker in text:
            time.sleep(2)
            text = log.read_text(encoding="utf-8", errors="replace")
            if "SCRIPT ERROR" in text or "ERROR:" in text: raise SystemExit(text[-5000:])
            if args.mode == "rig" and not json.loads((ROOT/'evidence/rig_v7/qa/report.json').read_text())['ok']:
                raise SystemExit(text[-1600:])
            print(text[-1600:])
            break
        time.sleep(1)
    else:
        raise SystemExit("Visual review timed out")
finally:
    client.runtime.stop_game(result["payload"]["process_id"])
