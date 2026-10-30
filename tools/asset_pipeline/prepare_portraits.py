"""Derive menu portraits from the reviewed Mivo character concept images."""
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import binary_propagation

from factory_context import ROOT, REPO
from pipeline.common import paths
from engine_adapters.godot import GodotClient

GAME='sunny_drift'
RUN='20261026_visual_v6'
config=json.loads((ROOT/'engine.json').read_text(encoding='utf-8'))
client=GodotClient(project_path=str(ROOT/'project'),godot_executable=config['executable'])
catalogue_path=ROOT/'project/assets/visual_v6.json'
derived_entries={}
for index in range(3):
    source=paths.task_output_dir(GAME,'image',f'driver_{index}',RUN,create=False)/'image.png'
    im=Image.open(source).convert('RGBA')
    if im.getextrema()[3][0]==255:
        rgb=np.array(im)[:,:,:3].astype(np.int16)
        allowed=(rgb.min(axis=2)>235)&((rgb.max(axis=2)-rgb.min(axis=2))<18)
        seed=np.zeros(allowed.shape,dtype=bool)
        seed[0,:]=allowed[0,:];seed[-1,:]=allowed[-1,:]
        seed[:,0]=allowed[:,0];seed[:,-1]=allowed[:,-1]
        background=binary_propagation(seed,mask=allowed)
        alpha=Image.fromarray(np.uint8(~background)*255).filter(ImageFilter.GaussianBlur(0.65))
        im.putalpha(alpha)
    bbox=im.getchannel('A').getbbox()
    x,y,r,b=bbox
    im=im.crop((x,y,int(x+(r-x)*0.90),int(y+(b-y)*0.57)))
    im.thumbnail((640,480),Image.Resampling.LANCZOS)
    asset_id=f'driver_portrait_{index}'
    directory=paths.task_output_dir(GAME,'image',asset_id,RUN)
    target=directory/'image.png';im.save(target)
    meta={'task_id':asset_id,'game_id':GAME,'run_id':RUN,'task_kind':'image','image_path':str(target.resolve()),
          'source_images':[str(source.resolve())],'derived_from':f'driver_{index}',
          'operation':'Upper body crop; exterior white background extraction for opaque source; resize, alpha retained.'}
    paths.write_task_meta(directory,meta)
    result=client.assets.import_texture({'game_id':GAME,'run_id':RUN,'task_kind':'image','task_id':asset_id,'artifact_key':'image_path'},
        destination='assets/imported/visual_v6',options={'name':asset_id,'replace_existing':True})
    if not result['ok']: raise SystemExit(result['errors'])
    derived_entries[asset_id]={'path':result['payload']['resource_path'],'enabled':True,'provider':'mivo',
                                  'derived_from':f'driver_{index}'}
    print(asset_id,'imported',flush=True)
catalogue=json.loads(catalogue_path.read_text(encoding='utf-8'))
catalogue['assets'].update(derived_entries)
catalogue_path.write_text(json.dumps(catalogue,ensure_ascii=False,indent=2),encoding='utf-8')
