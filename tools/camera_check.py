"""Analyze native per-frame camera data; identical gates for before/after takes."""
import json
import math
import re
from pathlib import Path


def angle(a, b):
    return (a - b + math.pi) % (2 * math.pi) - math.pi


def vector(value):
    if isinstance(value, list):
        return value
    return [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?", value)]


def analyze(folder):
    folder = Path(folder)
    rows = [json.loads(line) for line in (folder / "camera.jsonl").read_text(encoding="utf-8").splitlines()]
    transitions = []
    for before, after in zip(rows, rows[1:]):
        if before["stage"] < 0 or before["stage"] != after["stage"]:
            continue  # Explicit fixture resets are camera cuts.
        if before["phase"] == "grip" or after["phase"] != "grip":
            continue
        cam_a, cam_b = vector(before["camera_position"]), vector(after["camera_position"])
        car_a, car_b = vector(before["player_position"]), vector(after["player_position"])
        transitions.append({
            "time": after["time"], "stage": after["stage"],
            "yaw_step_degrees": math.degrees(abs(angle(after["camera_yaw"], before["camera_yaw"]))),
            "relative_yaw_step_degrees": math.degrees(abs(angle(angle(after["camera_yaw"], after["player_yaw"]), angle(before["camera_yaw"], before["player_yaw"])))),
            "offset_step_metres": math.dist([cam_a[i] - car_a[i] for i in range(3)], [cam_b[i] - car_b[i] for i in range(3)]),
            "fov_step_degrees": abs(after["fov"] - before["fov"]),
        })
    failures = []
    if len(rows) < 1000 or not {0, 1, 2}.issubset({item["stage"] for item in transitions}):
        failures.append("incomplete fixed-step camera take")
    if any(abs(row["dt"] - 1 / 60) > 0.001 for row in rows):
        failures.append("take does not use the required 60 Hz render step")
    for item in transitions:
        if item["yaw_step_degrees"] > 2.0 or item["relative_yaw_step_degrees"] > 2.0:
            failures.append(f"abrupt camera turn in stage {item['stage']}")
        if item["offset_step_metres"] > 0.30:
            failures.append(f"abrupt camera offset in stage {item['stage']}")
        if item["fov_step_degrees"] > 1.0:
            failures.append(f"abrupt FOV change in stage {item['stage']}")
    result = {"ok": not failures, "frames": len(rows), "transitions": transitions, "failures": failures, "sampling": "fixed 60 render steps per simulated second, not hardware FPS"}
    (folder / "camera-check.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    return result
