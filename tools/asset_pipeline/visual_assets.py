"""Sunny Drift V6 art production, using native GameFactory Mivo pipelines.

images -> inspect -> meshes -> inspect/import. No embedded credentials.
Each request uses the shared persistent cache; interrupted jobs resume.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys

from factory_context import ROOT, REPO
from pipeline.common import paths

GAME = "sunny_drift"
RUN = "20261026_visual_v6"
SPEC = ROOT / 'docs' / 'visual_asset_plan.json'


def credential():
    # A long-lived Codex shell may predate the user's environment update.
    if not os.environ.get("MIVO_USER_SUB") and sys.platform == "win32":
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as key:
                os.environ["MIVO_USER_SUB"] = winreg.QueryValueEx(key, "MIVO_USER_SUB")[0]
        except FileNotFoundError:
            pass
    if not os.environ.get("MIVO_USER_SUB"):
        raise SystemExit("MIVO_USER_SUB is not configured; no generation submitted.")


def output(kind, asset_id):
    return paths.task_output_dir(GAME, kind, asset_id, RUN, create=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["status", "images", "meshes", "import"])
    parser.add_argument("--only", action="append", default=[])
    args = parser.parse_args()
    plan = json.loads(SPEC.read_text(encoding="utf-8"))
    selected = [a for a in plan["assets"] if not args.only or a["id"] in args.only]
    unknown = set(args.only) - {a["id"] for a in selected}
    if unknown:
        parser.error(f"Unknown assets: {sorted(unknown)}")
    if args.action == "status":
        for a in selected:
            print(json.dumps({"id": a["id"], "image": (output("image", a["id"]) / "image.png").exists(),
                              "mesh": (output("3d_object", a["id"]) / "model.glb").exists(),
                              "image_reviewed": a.get("image_reviewed", False)}, ensure_ascii=False))
        return
    if args.action in ("images", "meshes"):
        credential()
        if args.action == "images":
            from pipeline.assets_gen.gen_image.run import load_model, make_operator, generate
            model = load_model("gpt-image-2", device="cpu", cache_dir=str(REPO / ".cache/mivo"), timeout=1800, poll_interval=8)
        else:
            from pipeline.assets_gen.gen_3d_object.run import load_model, make_operator, generate
            model = load_model("P1", device="cpu", backend="mivo", cache_dir=str(REPO / ".cache/mivo"), timeout=1800, poll_interval=8)
        try:
            op = make_operator(model, run_id=RUN, default_game_id=GAME)
            for a in selected:
                if args.action == "meshes" and a["kind"] != "mesh":
                    continue
                print(f"START {args.action} {a['id']}", flush=True)
                task = {"game_id": GAME, "task_id": a["id"]}
                if args.action == "images":
                    task.update(prompt=a["prompt"], parameters={"quality": "medium", "imgRatio": a.get("ratio", "1:1"), **a.get("parameters", {})})
                    if a.get("reference"):
                        task["image_path"] = str(output("image", a["reference"]) / "image.png")
                else:
                    if not a.get("image_reviewed"):
                        raise SystemExit(f"Inspect the concept image before meshing {a['id']}.")
                    task.update(image_path=str(output("image", a["id"]) / "image.png"),
                                decimation_target=a["triangles"], texture_size=2048,
                                strip_ground_plate=False)
                result = generate(task, op)
                print(json.dumps(result, ensure_ascii=False), flush=True)
        finally:
            model.unload()
        return
    from engine_adapters.godot import GodotClient
    config = json.loads((ROOT / "engine.json").read_text(encoding="utf-8"))
    client = GodotClient(project_path=str(ROOT / "project"), godot_executable=config["executable"])
    for a in selected:
        kind = "3d_object" if a["kind"] == "mesh" else "image"
        metadata = json.loads((output(kind, a["id"]) / "meta.json").read_text(encoding="utf-8"))
        artifact_key = "game_glb_path" if kind == "3d_object" and metadata.get("game_glb_path") else "glb_path" if kind == "3d_object" else "image_path"
        result = client.assets.import_asset(
            {"game_id": GAME, "run_id": RUN, "task_kind": kind, "task_id": a["id"],
             "artifact_key": artifact_key},
            "prop" if kind == "3d_object" else "texture", destination="assets/imported/visual_v6",
            options={"name": a["id"], "replace_existing": True})
        evidence = ROOT / "evidence" / "imports"
        evidence.mkdir(parents=True, exist_ok=True)
        (evidence / (a["id"] + ".json")).write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps({"asset": a["id"], "ok": result["ok"], "errors": result["errors"],
                          "resource": result.get("payload", {}).get("resource_path")}, ensure_ascii=False), flush=True)
        if not result["ok"]:
            raise SystemExit(1)


if __name__ == "__main__":
    main()
