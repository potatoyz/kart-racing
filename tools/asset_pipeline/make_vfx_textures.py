"""Deterministic soft-puff sprite atlas, imported through the public Godot client."""
from pathlib import Path
import json
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

from factory_context import ROOT, REPO
from pipeline.common import paths
from engine_adapters.godot import GodotClient

rng=np.random.default_rng(248)
atlas=np.zeros((512,512,4),dtype=np.uint8)
y,x=np.mgrid[-1:1:256j,-1:1:256j]
for n in range(4):
    noise=gaussian_filter(rng.random((256,256)),9)
    noise=(noise-noise.min())/(noise.max()-noise.min())
    density=np.zeros((256,256))
    for _ in range(7):
        cx,cy=rng.uniform(-.35,.35,2)
        sigma=rng.uniform(.18,.35)
        density+=np.exp(-((x-cx)**2+(y-cy)**2)/(2*sigma*sigma))*rng.uniform(.6,1)
    density/=density.max()
    alpha=np.clip(density*np.maximum(0,1-x*x-y*y)**2*(.5+.7*noise),0,1)
    shade=np.clip(.73+.23*noise-.10*y,0,1)
    tile=np.empty((256,256,4),dtype=np.uint8)
    tile[:,:,:3]=(shade[:,:,None]*255).astype(np.uint8)
    tile[:,:,3]=(alpha*255).astype(np.uint8)
    atlas[n//2*256:(n//2+1)*256,n%2*256:(n%2+1)*256]=tile
folder=paths.task_output_dir('sunny_drift','image','vfx_puff','20261026_vfx_v8')
target=folder/'image.png'
Image.fromarray(atlas).save(target)
paths.write_task_meta(folder,{'game_id':'sunny_drift','task_kind':'image','task_id':'vfx_puff','run_id':'20261026_vfx_v8','image_path':str(target.resolve()),'source':'project-native Gaussian/noise puff atlas','seed':248,'paid_generation_calls':0})
client=GodotClient(project_path=str(ROOT/'project'),godot_executable=json.loads((ROOT/'engine.json').read_text())['executable'])
result=client.assets.import_texture({'game_id':'sunny_drift','run_id':'20261026_vfx_v8','task_kind':'image','task_id':'vfx_puff','artifact_key':'image_path'},destination='assets/vfx_v8',options={'name':'puff_atlas','asset_id':'vfx_v8_puff','replace_existing':True})
print(json.dumps({'ok':result['ok'],'errors':result['errors']},indent=2))
if not result['ok']:raise SystemExit(1)
