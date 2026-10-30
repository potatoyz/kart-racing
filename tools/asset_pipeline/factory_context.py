"""Explicit optional GameFactory connection for regenerating existing assets."""
import os
import json
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
value = os.environ.get('GAMEFACTORY_ROOT', '')
if not value:
    raise SystemExit('Asset regeneration requires GAMEFACTORY_ROOT pointing to the original GameFactory checkout. Playing and testing do not require it.')
REPO = Path(value).expanduser().resolve()
if not (REPO/'pipeline/common/paths.py').is_file() or not (REPO/'operators').is_dir():
    raise SystemExit(f'Invalid GAMEFACTORY_ROOT: {REPO}')
# Do not load the vendored pipeline: regeneration needs the original paths module.
configured = json.loads((ROOT/'engine.json').read_text(encoding='utf-8')).get('executable')
local = Path(os.environ.get('LOCALAPPDATA', ''))/'A3Game/Godot/4.5.1-stable/windows-x86_64/Godot_v4.5.1-stable_win64.exe'
executable = configured or shutil.which('godot4') or shutil.which('godot') or (str(local) if local.is_file() else '')
if executable:
    os.environ.setdefault('A3GAME_GODOT_EXECUTABLE', executable)
sys.path.insert(0, str(REPO))
