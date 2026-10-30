"""Standalone project commands using the bundled Godot client."""
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "tools"))
from _project import ROOT, GodotClient, import_project, checked_godot

config = json.loads((ROOT / "engine.json").read_text(encoding="utf-8"))
client = GodotClient(project_path=str(ROOT / "project"), godot_executable=config["executable"])
operation = sys.argv[1] if len(sys.argv) > 1 else "play"
operations = {"stop", "test", "validate", "framework", "qa", "record", "skills", "boundary", "camera", "play", "editor", "import", "smoke"}
if operation not in operations:
    raise SystemExit("Use: " + ", ".join(sorted(operations)))
if operation in operations - {"stop", "framework", "import"} and not (ROOT / "project/.godot/global_script_class_cache.cfg").is_file():
    imported = import_project()
    if not imported["ok"]:
        raise SystemExit("Godot import failed: " + "\n".join(imported["errors"]))
if operation == "import":
    result = import_project()
elif operation == "smoke":
    result = checked_godot(["--headless", "--fixed-fps", "60", "--quit-after", "90", "--", "--maps-qa"])
elif operation == "stop":
    result = client.runtime.stop_game(int(sys.argv[2]))
elif operation == "test":
    result = client.testing.run_automation_tests(test_filter=sys.argv[2] if len(sys.argv)>2 else "", test_root="res://tests", report_path="reports/Y-tests.json", timeout=120)
elif operation == "validate":
    result = client.project.validate(check_engine=True)
elif operation == "framework":
    result = client.plugin.install_framework()
elif operation in ["qa", "record", "skills", "boundary", "camera"]:
    qa_name = {"skills":"skills_qa", "boundary":"boundary_qa", "camera":"camera_qa"}.get(operation, "qa")
    marker = {"skills":"SKILLS_COMPLETE", "boundary":"BOUNDARY_COMPLETE", "camera":"SKILLS_COMPLETE"}.get(operation, "QA_COMPLETE")
    log_path = ROOT / (qa_name + ".log")
    qa_flag = {"skills":"--skills-qa", "boundary":"--boundary-qa", "camera":"--camera-qa"}.get(operation, "--qa")
    launch_args = ["--log-file", str(log_path)]
    if operation == "camera": launch_args += ["--max-fps", "60", "--fixed-fps", "60"]
    result = client.runtime.launch_game(extra_args=launch_args+["--",qa_flag])
    if result["ok"]:
        print("QA launched", result["payload"]["process_id"], flush=True)
        deadline = time.monotonic() + 370
        while time.monotonic() < deadline:
            time.sleep(1)
            log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
            if "SCRIPT ERROR" in log or "ERROR:" in log or marker in log:
                break
        # The QA script requests a natural quit. Let rendering/resource teardown
        # finish before asking the client to release the managed process.
        if marker in log:
            time.sleep(2)
        stopped = client.runtime.stop_game(result["payload"]["process_id"])
        log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else log
        if "SCRIPT ERROR" in log or "ERROR:" in log:
            result["ok"] = False
            result["errors"].append(log[-5000:])
        elif marker in log:
            qa_report = json.loads((ROOT / "evidence" / qa_name / "report.json").read_text(encoding="utf-8"))
            if not qa_report["ok"]:
                result["ok"] = False
                result["errors"].append(qa_report["error"])
            if operation == "camera":
                from camera_check import analyze
                checked = analyze(ROOT / "evidence" / qa_name)
                if not checked["ok"]:
                    result["ok"] = False
                    result["errors"].extend(checked["failures"])
        else:
            result["ok"] = False
            result["errors"].append("QA timed out")
elif operation == "play":
    result = client.runtime.launch_game(extra_args=["--log-file", str(ROOT / "game.log")])
elif operation == "editor":
    result = client.runtime.launch_editor()
else:
    raise SystemExit("Unsupported operation")
if operation == "test":
    diagnostics = str(result.get("payload", {}).get("stderr", ""))
    if "SCRIPT ERROR" in diagnostics or "ERROR:" in diagnostics:
        result["ok"] = False
        result["errors"].append(diagnostics[-5000:])
(ROOT / "evidence").mkdir(exist_ok=True)
(ROOT / "evidence" / ("Y-" + operation + "-result.json")).write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({"ok": result["ok"], "errors": result["errors"], "payload": {k:v for k,v in result["payload"].items() if k in ["process_id","stderr","cases","log_path","report_path","video_path","frame_count"]}}, ensure_ascii=False, indent=2))
raise SystemExit(0 if result["ok"] else 1)
