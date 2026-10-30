"""Shared paths and Godot discovery for this independent game repository."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / 'tools/vendor'
sys.path.insert(0, str(VENDOR))


def find_godot():
    config = json.loads((ROOT / 'engine.json').read_text(encoding='utf-8'))
    explicit = os.environ.get('A3GAME_GODOT_EXECUTABLE') or config.get('executable')
    if explicit:
        resolved = Path(explicit).expanduser()
        if resolved.is_file():
            return str(resolved.resolve())
        resolved_command = shutil.which(str(explicit))
        if resolved_command:
            return resolved_command
        raise SystemExit(f'Godot executable was not found: {explicit}')
    for command in ('godot4', 'godot'):
        resolved = shutil.which(command)
        if resolved:
            return resolved
    if os.name == 'nt':
        local = Path(os.environ.get('LOCALAPPDATA', '')) / 'A3Game/Godot/4.5.1-stable/windows-x86_64/Godot_v4.5.1-stable_win64.exe'
        if local.is_file():
            return str(local)
    if sys.platform == 'darwin':
        local = Path('/Applications/Godot.app/Contents/MacOS/Godot')
        if local.is_file():
            return str(local)
    raise SystemExit('Install Godot 4.5.1 and set A3GAME_GODOT_EXECUTABLE or add godot4 to PATH.')


os.environ['A3GAME_GODOT_EXECUTABLE'] = find_godot()
from engine_adapters.godot import GodotClient


def checked_godot(arguments, timeout=180):
    """Wait for this owned process and reject engine errors even on exit code zero."""
    command = [find_godot(), '--path', str(ROOT/'project'), *arguments]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
        encoding='utf-8', errors='replace', timeout=timeout,
        creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    output = result.stdout + result.stderr
    ok = result.returncode == 0 and 'SCRIPT ERROR' not in output and 'ERROR:' not in output
    return {'ok': ok, 'errors': [] if ok else [output[-8000:]],
        'payload': {'stderr': result.stderr, 'exit_code': result.returncode, 'stdout': result.stdout}}


def import_project():
    return checked_godot(['--headless', '--editor', '--import', '--quit'], timeout=300)
