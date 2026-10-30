"""Package the independent source tree, including tools and all runtime assets."""
import argparse
import hashlib
import os
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
output = args.output.resolve()
output.parent.mkdir(parents=True, exist_ok=True)
excluded = {'.git','.godot','.a3game','__pycache__','.tools','.venv','evidence','reports','builds','release','test_data'}
count = 0
with ZipFile(output, 'x', ZIP_DEFLATED, compresslevel=1) as archive:
    for folder, dirs, names in os.walk(ROOT, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in excluded and not (Path(folder)/d).is_symlink())
        for name in sorted(names):
            path = Path(folder)/name
            if path.is_symlink() or path.resolve() == output or name.startswith('.env') or path.suffix.lower() in {'.log','.zip','.pyc','.pem','.key'}:
                continue
            archive.write(path, path.relative_to(ROOT))
            count += 1
with ZipFile(output) as archive:
    assert archive.testzip() is None
    for required in ['project/project.godot','run.py','tools/_project.py','tools/vendor/engine_adapters/godot/__init__.py','LICENSE.GameFactory']:
        assert required in archive.namelist(), required
print(output)
print('Files', count)
print('SHA256', hashlib.sha256(output.read_bytes()).hexdigest())
