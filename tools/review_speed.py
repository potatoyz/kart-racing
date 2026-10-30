"""Native speed VFX review with explicit fixtures; never writes the player profile."""
import json
from pathlib import Path
import sys
import time

from _project import ROOT, GodotClient, import_project, checked_godot

folder = ROOT / 'evidence/speed_v10'
folder.mkdir(parents=True, exist_ok=True)
log = folder / 'native.log'
log.write_text('', encoding='utf-8')
config = json.loads((ROOT / 'engine.json').read_text())
client = GodotClient(project_path=str(ROOT / 'project'), godot_executable=config['executable'])
result = client.runtime.launch_game(scene_path='res://tests/speed_qa.tscn', extra_args=[
    '--log-file', str(log), '--resolution', '1280x720', '--max-fps', '60', '--fixed-fps', '60'])
if not result['ok']:
    raise SystemExit(result['errors'])
print('Speed review process', result['payload']['process_id'], flush=True)
try:
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        content = log.read_text(encoding='utf-8', errors='replace')
        if 'ERROR:' in content or 'crashed' in content:
            raise SystemExit(content[-5000:])
        if 'SPEED_QA_COMPLETE' in content:
            time.sleep(1)
            report = json.loads((folder / 'report.json').read_text(encoding='utf-8'))
            print(json.dumps(report, ensure_ascii=False, indent=2))
            if not report['ok']:
                raise SystemExit(1)
            break
        time.sleep(0.5)
    else:
        raise SystemExit('Speed review timed out')
finally:
    client.runtime.stop_game(result['payload']['process_id'])
