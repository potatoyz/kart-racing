"""Separate the reviewed Mivo steering-wheel component and preserve the body/wheels."""
import argparse
import json
from pathlib import Path
import sys
import numpy as np
import trimesh

from factory_context import ROOT, REPO
from pipeline.common import paths
from prepare_models import part
from engine_adapters.godot import GodotClient

def prepare(index):
    source=paths.task_output_dir('sunny_drift','3d_object',f'car_{index}','20261026_visual_v6',create=False)/'game_model.glb'
    scene=trimesh.load(source,force='scene',process=False)
    mesh=scene.geometry['Body']
    v,inv=np.unique(np.round(mesh.vertices,5),axis=0,return_inverse=True)
    topology=trimesh.Trimesh(vertices=v,faces=inv[mesh.faces],process=False)
    components=trimesh.graph.connected_components(topology.face_adjacency,nodes=np.arange(len(mesh.faces)),min_len=2)
    # These component identities were measured on the three preserved V6 meshes.
    counts=[248,356,264]
    candidates=[ids for ids in components if len(ids)==counts[index]]
    assert len(candidates)==1,'Steering geometry changed; re-review component identities'
    ids=candidates[0]
    envelope=mesh.vertices[mesh.faces[ids]].reshape(-1,3)
    lo,hi=envelope.min(0),envelope.max(0)
    included=[ids]
    for component in components:
        if len(component)>=len(ids):continue
        candidate_points=mesh.vertices[mesh.faces[component]].reshape(-1,3)
        if np.all(candidate_points.min(0)>=lo-0.004) and np.all(candidate_points.max(0)<=hi+0.004):included.append(component)
    ids=np.unique(np.concatenate(included))
    points=mesh.vertices[mesh.faces[ids]].reshape(-1,3)
    center=(points.min(0)+points.max(0))/2
    chosen=part(mesh,ids,center)
    covariance=np.cov(np.unique(points,axis=0).T)
    _,vectors=np.linalg.eigh(covariance)
    axle=vectors[:,0]
    if axle[0]<0:axle=-axle
    lateral=np.array([0.,0.,1.]);lateral-=axle*np.dot(lateral,axle);lateral/=np.linalg.norm(lateral)
    up=np.cross(lateral,axle)
    basis=np.stack([axle,up,lateral],axis=1)
    correction=np.eye(4);correction[:3,:3]=basis.T
    chosen.apply_transform(correction)
    keep=np.ones(len(mesh.faces),bool);keep[ids]=False
    scene.geometry['Body']=part(mesh,np.flatnonzero(keep),np.zeros(3))
    # Separate transform: original source facing and vehicle normalization stay unchanged.
    pivot=np.eye(4);pivot[:3,3]=center;pivot[:3,:3]=basis
    scene.graph.update(frame_to='SteeringWheel',matrix=pivot)
    scene.add_geometry(chosen,node_name='SteeringRim',geom_name='SteeringRim',parent_node_name='SteeringWheel')
    out=paths.task_output_dir('sunny_drift','3d_object',f'car_{index}','20261026_rig_v7')
    target=out/'model.glb';target.write_bytes(scene.export(file_type='glb'))
    meta={'game_id':'sunny_drift','run_id':'20261026_rig_v7','task_kind':'3d_object','task_id':f'car_{index}',
          'glb_path':str(target.resolve()),'source':str(source),'steering_component_faces':len(ids),
          'steering_center_source':center.tolist(),'steering_bounds_source':[points.min(0).tolist(),points.max(0).tolist()]}
    paths.write_task_meta(out,meta)
    engine=json.loads((ROOT/'engine.json').read_text(encoding='utf-8'))
    client=GodotClient(project_path=str(ROOT/'project'),godot_executable=engine['executable'])
    result=client.assets.import_prop({'game_id':'sunny_drift','run_id':'20261026_rig_v7','task_kind':'3d_object','task_id':f'car_{index}','artifact_key':'glb_path'},
        destination='assets/imported/rig_v7',options={'name':f'car_{index}','asset_id':f'rig_v7_car_{index}','replace_existing':True})
    if not result['ok']:raise SystemExit(result['errors'])
    catalogue_path=ROOT/'project/assets/visual_v6.json'
    catalogue=json.loads(catalogue_path.read_text(encoding='utf-8'))
    entry=catalogue['assets'][f'car_{index}']
    entry['path']=result['payload']['resource_path']
    entry['steering_control']={'center':[0,1.28 if index==2 else 0.94,-0.03],'radius':0.25 if index==2 else 0.235,'max_angle_degrees':32.0,
                               'source_center':center.tolist(),'source_radius':float(np.ptp(chosen.vertices[:,2])/2)}
    catalogue_path.write_text(json.dumps(catalogue,indent=2),encoding='utf-8')
    print(json.dumps(meta,indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--index',type=int,default=0);a=p.parse_args();prepare(a.index)
