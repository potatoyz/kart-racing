"""Independent native races; union of vehicle/mode and five-seed AI matrices."""
import concurrent.futures,json,os,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'evidence/maps_v11'/('matrix_'+time.strftime('%Y%m%d_%H%M%S'));out.mkdir(parents=True)
cases=[]
for track in ['sunny_coast','harbor_loop','ridge_hairpins']:
 for mode in ['speed','item']:
  for car in range(3):cases.append((track,mode,car,20261021,False))
for track in ['harbor_loop','ridge_hairpins']:
 for mode in ['speed','item']:
  for seed in range(20261022,20261026):cases.append((track,mode,0,seed,False))
for track in ['harbor_loop','ridge_hairpins']:
 for car in range(3):cases.append((track,'speed',car,20261021,True))
def run(case):
 track,mode,car,seed,basic=case
 args=[sys.executable,str(ROOT/'tools/maps_ops.py'),'sim','--track='+track,'--mode='+mode,'--car='+str(car),'--seed='+str(seed)]
 if basic:args.append('--basic')
 env=os.environ.copy();env['PYTHONIOENCODING']='utf-8'
 r=subprocess.run(args,capture_output=True,text=True,encoding='utf-8',errors='replace',env=env,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0),timeout=220)
 key=f'{track}_{mode}_{car}_{seed}'+('_basic' if basic else '')
 (out/(key+'.log')).write_text(r.stdout+'\n'+r.stderr,encoding='utf-8')
 report_path=next((line[7:] for line in r.stdout.splitlines() if line.startswith('REPORT ')),None)
 data=json.loads(Path(report_path).read_text(encoding='utf-8')) if report_path else {'ok':False,'error':r.stdout[-2000:]+r.stderr[-1000:]}
 data['exit_code']=r.returncode;data['basic_driver']=basic;data['evidence_path']=report_path
 data['case']=list(case)
 return key,data
results={}
print('MATRIX_START',len(cases),str(out),flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
 futures={executor.submit(run,c):c for c in cases}
 for future in concurrent.futures.as_completed(futures):
  try:key,data=future.result()
  except Exception as e:key=str(futures[future]);data={'ok':False,'error':repr(e)}
  results[key]=data
  print('MATRIX_PROGRESS',len(results),'/',len(cases),key,'PASS' if data['ok'] else 'FAIL',flush=True)
  (out/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
failed=[k for k,v in results.items() if not v['ok'] or v.get('exit_code',1)!=0]
resets={k:sum(c['resets'] for c in v.get('cars',[])) for k,v in results.items()}
summary={'ok':not failed,'count':len(results),'failed':failed,'reset_counts':resets,'results':'results.json','matrix':'18 track/mode/car + 16 additional AI seeds + 6 basic-driving races','autonomous_not_human':True}
(out/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print('MATRIX_COMPLETE',json.dumps(summary,ensure_ascii=False),str(out),flush=True)
sys.exit(0 if not failed else 1)
