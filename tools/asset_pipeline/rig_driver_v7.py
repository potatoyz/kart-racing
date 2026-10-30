"""Project-owned rig calibration tasks; no cloud model call or baked landmark preset."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
import trimesh

from factory_context import ROOT, REPO
from pipeline.common import paths
from operators.gen_motion.funcs.vibe_motion_utils.rigging_utils.mesh import CreatureMesh
from operators.gen_motion.funcs.vibe_motion_utils.rigging_utils.estimation import prepare_projection

RUN='20261026_rig_v7'

def directory(index):
    return paths.task_output_dir('sunny_drift','motion',f'driver_{index}',RUN)

def prepare(index):
    source=paths.task_output_dir('sunny_drift','3d_object',f'driver_{index}','20261026_visual_v6',create=False)/'game_model.glb'
    scene=trimesh.load(source,force='scene',process=False)
    assert len(scene.geometry)==1
    raw=next(iter(scene.geometry.values()))
    vertices,mapping=np.unique(np.round(raw.vertices,7),axis=0,return_inverse=True)
    mesh=CreatureMesh(f'driver_{index}',vertices,mapping[raw.faces],mapping,source)
    audit={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'normalization':{'scale':1.0,'translation':[0,0,0],'units':'source mesh units'}}
    request={'reconstruction':{'axis_tolerance':1e-8}}
    projection={'width':768,'height':768,'padding_ratio':0.08,'views':{
        'front':{'right':[0,0,-1],'up':[0,1,0]},
        'right':{'right':[1,0,0],'up':[0,1,0]},
        'left':{'right':[-1,0,0],'up':[0,1,0]},
        'top':{'right':[1,0,0],'up':[0,0,-1]},
        'back':{'right':[0,0,1],'up':[0,1,0]}}}
    output=directory(index)
    if (output/'projection').exists():raise SystemExit('Projection already exists; preserve existing calibrated evidence')
    manifest=prepare_projection(mesh,audit,request,projection,output)
    (output/'input.json').write_text(json.dumps({'source':str(source.resolve()),'audit':audit,'request':request,'projection':projection},indent=2),encoding='utf-8')
    np.savez(output/'mesh.npz',vertices=vertices,faces=mapping[raw.faces],weld_map=mapping)
    print(json.dumps({'driver':index,'output':str(output),'calibration':manifest['cameras']},indent=2),flush=True)

def bind(index):
    from operators.gen_motion.operator import GenMotionOperator
    exe=Path.home()/'AppData/Local/A3Game/Blender/4.5.12/blender-4.5.12-windows-x64/blender.exe'
    op=GenMotionOperator(run_id=RUN,default_game_id='sunny_drift')
    print(json.dumps(op.run({'task_type':'seated_rig','task_id':f'driver_{index}',
                            'calibration_dir':str(directory(index)),'blender_executable':str(exe),
                            'binding_config_path':str(ROOT / 'docs' / 'rig_binding_v7.json')}),indent=2))

def import_rig(index):
    from engine_adapters.godot import GodotClient
    engine=json.loads((ROOT/'engine.json').read_text(encoding='utf-8'))
    client=GodotClient(project_path=str(ROOT/'project'),godot_executable=engine['executable'])
    result=client.assets.import_asset({'game_id':'sunny_drift','run_id':RUN,'task_kind':'motion',
                                      'task_id':f'driver_{index}','artifact_key':'rigged_glb_path'},'avatar',
        destination='assets/imported/rig_v7',options={'name':f'driver_{index}','asset_id':f'rig_v7_driver_{index}','replace_existing':True})
    evidence=ROOT/'evidence/rig_v7';evidence.mkdir(exist_ok=True,parents=True)
    (evidence/f'driver_{index}_import.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    if not result['ok']:raise SystemExit(result['errors'])
    catalogue_path=ROOT/'project/assets/visual_v6.json'
    catalogue=json.loads(catalogue_path.read_text(encoding='utf-8'))
    catalogue['assets'][f'driver_{index}']['path']=result['payload']['resource_path']
    catalogue['assets'][f'driver_{index}']['rigged']=True
    catalogue_path.write_text(json.dumps(catalogue,indent=2),encoding='utf-8')
    print('Imported skinned avatar',index,result['payload']['resource_path'])

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['prepare','bind','import'])
    p.add_argument('--index',type=int,default=0)
    a=p.parse_args()
    {'prepare':prepare,'bind':bind,'import':import_rig}[a.action](a.index)
