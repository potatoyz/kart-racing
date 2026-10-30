"""V11 native operations through the public Godot client; no player-save writes."""
import json, sys, time, os
from pathlib import Path
from _project import ROOT, GodotClient, import_project, checked_godot
client=GodotClient(project_path=str(ROOT/'project'),godot_executable=json.loads((ROOT/'engine.json').read_text(encoding='utf-8'))['executable'])
if __name__=='__main__':
 op=sys.argv[1] if len(sys.argv)>1 else 'test'
 stamp=time.strftime('%Y%m%d_%H%M%S')+'_'+str(os.getpid())
 out=ROOT/'evidence/maps_v11'/stamp;out.mkdir(parents=True,exist_ok=True)
 if op=='test':
  r=client.testing.run_automation_tests(test_filter=sys.argv[2] if len(sys.argv)>2 else '',test_root='res://tests',report_path='reports/maps-v11-tests.json',timeout=120)
  (out/'tests.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
  print(json.dumps({'ok':r['ok'],'errors':r['errors'],'cases':r['payload'].get('cases'), 'stderr':r['payload'].get('stderr','')},ensure_ascii=False))
  sys.exit(0 if r['ok'] and 'SCRIPT ERROR' not in r['payload'].get('stderr','') else 1)

 if op=='sim':
  report=out/'simulation.json';log=out/'godot.log'
  args=['--fixed-fps','60','--log-file',str(log),'--script','res://tests/maps_simulation.gd','--','--maps-qa','--out='+str(report),*sys.argv[2:]]
  r=client.runtime.launch_game(headless=True,extra_args=args)
  if not r['ok']:print(r);sys.exit(1)
  deadline=time.monotonic()+180
  while time.monotonic()<deadline and not report.exists():
   time.sleep(.3)
   if log.exists() and ('SCRIPT ERROR' in log.read_text(encoding='utf-8',errors='replace') or 'Parse Error' in log.read_text(encoding='utf-8',errors='replace')):break
  time.sleep(.3)
  client.runtime.stop_game(r['payload']['process_id'])
  if report.exists():
   data=json.loads(report.read_text(encoding='utf-8'))
   print(json.dumps({k:v for k,v in data.items() if k!='trace'},ensure_ascii=False));print('REPORT',str(report))
   sys.exit(0 if data['ok'] else 1)
  print(log.read_text(encoding='utf-8',errors='replace') if log.exists() else 'No report');sys.exit(1)

 if op in ['visual','assets','checks','record','ui','performance','techniques']:
  report=out/'report.json';log=out/'godot.log'
  r=client.runtime.launch_game(headless=op=='checks',extra_args=([] if op=='performance' else ['--fixed-fps','60'])+['--resolution','1600x900' if '--large' in sys.argv else '1280x720','--log-file',str(log),'--script','res://tests/maps_'+op+'.gd','--','--maps-qa','--out='+str(out),*sys.argv[2:]])
  if not r['ok']:print(r);sys.exit(1)
  deadline=time.monotonic()+(1000 if op=='record' else 180)
  while time.monotonic()<deadline and not report.exists():
   time.sleep(.3)
   if log.exists() and 'SCRIPT ERROR' in log.read_text(encoding='utf-8',errors='replace'):break
  time.sleep(.5);client.runtime.stop_game(r['payload']['process_id'])
  logtext=log.read_text(encoding='utf-8',errors='replace') if log.exists() else 'No log'
  print('OUTPUT',str(out));print(logtext[-4000:])
  sys.exit(0 if report.exists() and json.loads(report.read_text(encoding='utf-8')).get('ok',False) and 'SCRIPT ERROR' not in logtext and 'ERROR:' not in logtext else 1)
