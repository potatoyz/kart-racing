"""Bounded native V8 review and no-capture comparisons, via GodotClient."""
import argparse
import json
from pathlib import Path
import sys
import time

from _project import ROOT, GodotClient, import_project, checked_godot

parser=argparse.ArgumentParser()
parser.add_argument('mode',choices=['before','after','check','gallery','bench-off','bench-on','stress'])
args=parser.parse_args()
folder=ROOT/'evidence/vfx_v8';folder.mkdir(parents=True,exist_ok=True)
log=folder/(args.mode+'.log');log.write_text('',encoding='utf-8')
config=json.loads((ROOT/'engine.json').read_text())
client=GodotClient(project_path=str(ROOT/'project'),godot_executable=config['executable'])
flags=['--log-file',str(log),'--resolution','1280x720']
scene=''
if args.mode in ['before','after']:
    flags+=['--max-fps','60','--fixed-fps','60','--','--skills-qa','--vfx-record']
    if args.mode=='before':flags+=['--vfx-before']
    marker='SKILLS_COMPLETE';report=folder/args.mode/'report.json'
else:
    scene='res://tests/vfx_qa.tscn'
    flags+=['--max-fps','0' if args.mode.startswith('bench') else '60','--','--vfx-mode='+args.mode]
    marker='VFX_QA_COMPLETE';report=folder/(args.mode+'.json')
result=client.runtime.launch_game(scene_path=scene,headless=args.mode=='stress',extra_args=flags)
if not result['ok']:raise SystemExit(result['errors'])
print('VFX review',args.mode,'process',result['payload']['process_id'],flush=True)
deadline=time.monotonic()+240
try:
    while time.monotonic()<deadline:
        content=log.read_text(encoding='utf-8',errors='replace')
        if 'SCRIPT ERROR' in content or 'ERROR:' in content:raise SystemExit(content[-5000:])
        if marker in content:
            time.sleep(2)
            content=log.read_text(encoding='utf-8',errors='replace')
            data=json.loads(report.read_text(encoding='utf-8'))
            if not data['ok'] or 'ERROR:' in content:raise SystemExit(content[-5000:])
            print(json.dumps({k:v for k,v in data.items() if k not in ['vfx_samples','samples','input_counts','events']},ensure_ascii=False,indent=2))
            break
        time.sleep(1)
    else:raise SystemExit('VFX review timed out')
finally:client.runtime.stop_game(result['payload']['process_id'])
