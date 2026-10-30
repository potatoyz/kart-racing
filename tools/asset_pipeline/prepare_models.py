"""Preserve Mivo originals; prepare game-sized textures and separable wheel nodes.

Wheel membership uses connected geometry, never copies material images per face.
Source facing is unchanged and remains an explicitly reviewed catalogue setting.
"""
import argparse
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image
import trimesh

from factory_context import ROOT, REPO
from pipeline.common import paths
from models.common.glb_utils import glb_summary


def part(mesh, face_ids, center):
    faces = mesh.faces[face_ids]
    indices, inverse = np.unique(faces.ravel(), return_inverse=True)
    visual = trimesh.visual.texture.TextureVisuals(uv=mesh.visual.uv[indices], material=mesh.visual.material)
    return trimesh.Trimesh(vertices=mesh.vertices[indices]-center, faces=inverse.reshape(-1,3),
                           vertex_normals=mesh.vertex_normals[indices], visual=visual, process=False)


def split_wheels(mesh):
    # Weld positions only for adjacency. Keep original UV seams in the output.
    vertices, inverse = np.unique(np.round(mesh.vertices,5), axis=0, return_inverse=True)
    topology = trimesh.Trimesh(vertices=vertices,faces=inverse[mesh.faces],process=False)
    components = trimesh.graph.connected_components(topology.face_adjacency,
                                                    nodes=np.arange(len(mesh.faces)),min_len=1)
    groups = {}
    candidates = []
    for component in components:
        points = topology.vertices[topology.faces[component]].reshape(-1,3)
        lo, hi = points.min(0), points.max(0)
        center = (lo+hi)/2
        extent = hi-lo
        if len(component)>150 and 0.12<extent[0]<0.3 and 0.12<extent[1]<0.3 and extent[2]<0.15 and abs(center[2])>0.12 and hi[1]<0.11:
            key = (int(center[0]>0),int(center[2]>0))
            if key not in groups or len(component)>len(groups[key][0]):
                groups[key] = (component,lo,hi)
        candidates.append((component,center,lo,hi))
    if len(groups)!=4:
        raise ValueError(f"Expected four separate wheel shells, found {len(groups)}; manual review needed")
    assigned = np.zeros(len(mesh.faces),dtype=bool)
    result = []
    for key,(_,lo,hi) in groups.items():
        selected=[]
        for component,center,component_lo,component_hi in candidates:
            if np.all(component_lo>=lo-0.012) and np.all(component_hi<=hi+0.012):
                selected.extend(component.tolist())
        ids=np.array(selected,dtype=int)
        if assigned[ids].any(): raise ValueError("Overlapping wheel assignments")
        assigned[ids]=True
        name=("Front" if key[0] else "Rear")+("Left" if key[1] else "Right")
        result.append((name,ids,(lo+hi)/2,float((hi[1]-lo[1])/2)))
    return np.where(~assigned)[0],result


def prepare(asset_id):
    directory=paths.task_output_dir("sunny_drift","3d_object",asset_id,"20261026_visual_v6",create=False)
    source=directory/'model.glb'
    scene=trimesh.load(source,force='scene',process=False)
    texture_limit=1536 if asset_id.startswith(('car_','driver_')) else 1024
    for mesh in scene.geometry.values():
        material=mesh.visual.material
        for key in ('baseColorTexture','normalTexture','metallicRoughnessTexture','occlusionTexture'):
            image=getattr(material,key,None)
            if image is not None and max(image.size)>texture_limit:
                ratio=texture_limit/max(image.size)
                setattr(material,key,image.resize(tuple(max(1,round(n*ratio)) for n in image.size),Image.Resampling.LANCZOS))
        # Palm fronds are thin surfaces; both sides are intentionally visible.
        material.doubleSided=asset_id=='palm'
        if asset_id.startswith('driver_'):
            material.metallicFactor=0.3
            orm=material.metallicRoughnessTexture
            if orm is not None:
                pixels=np.array(orm.convert('RGB'))
                pixels[:,:,1]=np.maximum(pixels[:,:,1],100)
                material.metallicRoughnessTexture=Image.fromarray(pixels)
    wheel_metadata=[]
    if asset_id.startswith('car_'):
        if len(scene.geometry)!=1: raise ValueError('Unexpected multi-mesh car')
        mesh=next(iter(scene.geometry.values()))
        body,wheels=split_wheels(mesh)
        processed=trimesh.Scene()
        processed.add_geometry(part(mesh,body,np.zeros(3)),node_name='Body',geom_name='Body')
        for name,ids,center,radius in wheels:
            matrix=np.eye(4);matrix[:3,3]=center
            pivot='Wheel'+name
            processed.graph.update(frame_to=pivot,matrix=matrix)
            processed.add_geometry(part(mesh,ids,center),parent_node_name=pivot,
                                   node_name='Spin'+name,geom_name='Tire'+name)
            wheel_metadata.append({'name':pivot,'center':center.tolist(),'radius':radius,'faces':len(ids)})
        scene=processed
    target=directory/'game_model.glb'
    target.write_bytes(scene.export(file_type='glb'))
    meta_path=directory/'meta.json'
    meta=json.loads(meta_path.read_text(encoding='utf-8'))
    meta['game_glb_path']=str(target.resolve())
    meta['game_preparation']={'texture_limit':texture_limit,'source_preserved':True,'wheels':wheel_metadata,
                              'summary':glb_summary(target.read_bytes())}
    meta_path.write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'id':asset_id,**meta['game_preparation']},ensure_ascii=False),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ids',nargs='+')
    args=parser.parse_args()
    for asset_id in args.ids: prepare(asset_id)
