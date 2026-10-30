"""Rebuild V11 authored rigid props; stage Kenney CC0 vegetation and rocks."""
import json,sys,zipfile,hashlib,urllib.request
from pathlib import Path
from factory_context import ROOT, REPO
from operators.gen_3d_object.operator import Gen3DObjectOperator
from pipeline.common.paths import task_output_dir,write_task_meta
from engine_adapters.godot import GodotClient

def material(hexcolor):
 return {'baseColor':[int(hexcolor[i:i+2],16)/255 for i in (0,2,4)]+[1], 'roughness':.78}
MATS={k:material(v) for k,v in {'cream':'E7D8B4','roof':'DB816A','steel':'345569','glass':'64B6C0','white':'F5ECD8','yellow':'EEBC52','wood':'AC7A51','stone':'B1B9A6'}.items()}
def box(id,size,at,mat='cream',rot=None,bevel=.035):
 p={'id':id,'kind':'box','size':size,'at':at,'material':mat,'chamfer':bevel}
 if rot:p['rotation']=rot
 return p
specs={}
parts=[box('body',[16,6,11],[0,3,0]),box('foundation',[17,.5,12],[0,.25,0],'stone'),box('roof_a',[8.5,.35,12.5],[-4,6.9,0],'roof',[0,0,12]),box('roof_b',[8.5,.35,12.5],[4,6.9,0],'roof',[0,0,-12])]
for i,x in enumerate([-5,0,5]):
 parts += [box('door'+str(i),[3.5,4.1,.12],[x,2.15,-5.55],'steel'),box('window'+str(i),[2.9,.6,.15],[x,5.2,-5.55],'glass')]
for i,x in enumerate([-7.8,-2.5,2.5,7.8]):parts.append(box('column'+str(i),[.3,6.2,.4],[x,3.1,-5.6],'white'))
specs['warehouse']=(parts,8.0)
parts=[box('shell',[10,3,3.4],[0,1.5,0],'roof'),box('lower_frame',[10.2,.18,3.55],[0,.12,0],'steel'),box('upper_frame',[10.2,.18,3.55],[0,2.9,0],'cream')]
for i in range(17):
 for side in [-1,1]:parts.append(box('rib_%d_%s'%(i,side),[.08,2.66,.10],[-4.7+i*.59,1.5,side*1.73],'cream',bevel=0))
for i,z in enumerate([-.8,.8]):parts.append(box('door_bar'+str(i),[.12,2.5,.12],[-5.06,1.5,z],'steel'))
specs['container']=(parts,3.0)
parts=[]
for i,x in enumerate([-5.5,5.5]):
 parts += [box('leg'+str(i),[1.1,19,1.1],[x,9.5,0],'yellow'),box('foot'+str(i),[2.2,1,6],[x,.5,0],'steel')]
parts += [box('crossbeam',[13,1.4,1.8],[0,18.5,0],'yellow'),box('boom',[1.4,1.2,26],[0,20,-3],'yellow'),box('cab',[3.5,3,3.5],[1.7,17.5,-3],'cream'),box('cab_window',[3.6,1.5,.12],[1.7,18,-4.8],'glass'),box('rope',[.12,11,.12],[0,13.8,-12],'steel'),box('hook',[1.4,.6,1.0],[0,8.4,-12],'yellow')]
for i,z in enumerate(range(-14,9,4)):parts.append(box('beam_tie'+str(i),[1.7,1.1,.22],[0,20.8,z],'cream'))
specs['crane']=(parts,21.4)
parts=[box('base',[.85,.3,.85],[0,.15,0],'stone'),box('mast',[.22,6,.22],[0,3,0],'steel'),box('arm',[2.8,.22,.22],[1.25,5.9,0],'steel'),box('lamp',[1.2,.35,.7],[2.4,5.7,0],'cream'),box('lens',[1.05,.10,.58],[2.4,5.5,0],'yellow')]
specs['harbor_lamp']=(parts,6.1)
parts=[box('deck',[10,.45,7],[0,1.1,0],'wood')]
for i,x in enumerate([-4.7,4.7]):
 for j,z in enumerate([-3.2,3.2]):parts.append(box('post_%d_%d'%(i,j),[.38,3.4,.38],[x,1.7,z],'wood'))
parts += [box('back_rail',[10,.2,.2],[0,2.8,3.2],'cream'),box('side_a',[.2,.2,6.4],[-4.7,2.8,0],'cream'),box('side_b',[.2,.2,6.4],[4.7,2.8,0],'cream')]
for i,z in enumerate([-2.8,-2,-1.2,-.4,.4,1.2,2,2.8]):parts.append(box('deck_plank'+str(i),[9.7,.08,.68],[0,1.36,z],'cream'))
specs['lookout']=(parts,3.4)
parts=[box('left_pier',[2.6,8,2.6],[-10,4,0],'stone'),box('right_pier',[2.6,8,2.6],[10,4,0],'stone'),box('arch_beam',[23,1.4,3.0],[0,8.5,0],'wood'),box('sign',[11,1.9,.4],[0,8.1,-1.6],'steel'),box('cap',[24,.45,3.8],[0,9.4,0],'cream')]
specs['mountain_gate']=(parts,9.65)
operator=Gen3DObjectOperator(model=None,run_id='20261021',default_game_id='sunny_drift')
client=GodotClient(project_path=str(ROOT/'project'),godot_executable=json.loads((ROOT/'engine.json').read_text(encoding='utf-8'))['executable'])
records={};reports=[]
for name,(parts,height) in specs.items():
 spec={'subject':name.replace('_',' '),'units':'metres','forward':'-x' if name=='container' else '-z','asset_type':'scenery' if height>6 else 'prop','role':'scenery' if name not in ['crane','mountain_gate'] else 'landmark','height_metres':height,'materials':MATS,'parts':parts}
 result=operator.run({'game_id':'sunny_drift','task_id':'maps_v11_'+name,'spec':spec})
 if not result['spec_ok']:raise RuntimeError(json.dumps(result,ensure_ascii=False))
 reports.append(result)
 records[name]={'size':height,'source':'authored_spec','license':'project-original','spec_task_id':'maps_v11_'+name,'enabled':True,'size_axis':1,'rotation_degrees':[0,0,0],'verified_by':'spec_pending_native_visual_review'}
 print(name,result['triangles'],'triangles',flush=True)
# Only the explicitly selected archive entries are staged; never extract archive paths.
archive_path=ROOT/'.tools/kenney_nature-kit.zip'
if not archive_path.exists():
 archive_path.parent.mkdir(parents=True,exist_ok=True)
 with urllib.request.urlopen('https://kenney.nl/media/pages/assets/nature-kit/37ac38a37b-1677698939/kenney_nature-kit.zip',timeout=60) as response:
  archive_path.write_bytes(response.read())
with zipfile.ZipFile(ROOT/'.tools/kenney_nature-kit.zip') as archive:
 for name,filename,height in [('pine_tall','tree_pineTallA.glb',12),('pine_round','tree_pineRoundA.glb',8),('ridge_rock','rock_largeA.glb',7),('cliff','rock_tallB.glb',16)]:
  source_name='Models/GLTF format/'+filename
  output=task_output_dir('sunny_drift','3d_object','maps_v11_'+name,run_id='20261021')
  target=output/'model.glb';target.write_bytes(archive.read(source_name))
  license_text=archive.read('License.txt').decode('utf-8-sig')
  (output/'LICENSE.txt').write_text(license_text,encoding='utf-8')
  write_task_meta(output,{'game_id':'sunny_drift','run_id':'20261021','task_kind':'3d_object','task_id':'maps_v11_'+name,'glb_path':str(target),'source':'Kenney Nature Kit 2.1','source_url':'https://kenney.nl/assets/nature-kit','license':'CC0-1.0','sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
  records[name]={'size':height,'source':'Kenney Nature Kit 2.1','license':'CC0-1.0','source_url':'https://kenney.nl/assets/nature-kit','enabled':True,'size_axis':1,'rotation_degrees':[0,0,0],'verified_by':'pending_native_visual_review'}
 license_out=ROOT/'project/assets/imported/maps_v11';license_out.mkdir(parents=True,exist_ok=True)
 (license_out/'KENNEY_LICENSE.txt').write_text(license_text,encoding='utf-8')
for name,record in records.items():
 source={'game_id':'sunny_drift','run_id':'20261021','task_kind':'3d_object','task_id':'maps_v11_'+name,'artifact_key':'glb_path'}
 r=client.assets.import_prop(source,destination='assets/imported/maps_v11/'+name,options={'replace_existing':True})
 if not r['ok']:raise RuntimeError(json.dumps(r,ensure_ascii=False))
 (ROOT/'evidence/maps_v11'/('import_'+name+'.json')).write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
 artifact=r['artifacts'][0]
 record['path']=artifact['backend_path']
 record['artifact']=artifact
 print('IMPORTED',name,record['path'],flush=True)
(ROOT/'project/assets/maps_v11.json').write_text(json.dumps({'revision':11,'assets':{'map_'+k:v for k,v in records.items()}},ensure_ascii=False,indent=2),encoding='utf-8')
(ROOT/'evidence/maps_v11/asset_builds.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8')
