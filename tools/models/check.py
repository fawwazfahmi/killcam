"""Checks on the generated GLB files and on how map layouts use the props.

    python tools/models/check.py

Fails if a mesh is not a closed, outward-facing surface, if a marker is missing
or misplaced, if a part name has no palette entry, if a prop does not fill its
stated box, or if a map layout names a prop that does not exist or stretches
one too far.
"""

import json
import re
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))

from palette import PALETTE  # noqa: E402
from props import PROPS  # noqa: E402
from weapons import WEAPONS  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
FRAME = {"MarkOrigin": (0, 0, 0), "MarkForward": (0, 0, -1), "MarkUp": (0, 1, 0), "MarkRight": (1, 0, 0)}
COMPONENT = {5123: np.uint16, 5125: np.uint32, 5126: np.float32}
WIDTH = {"SCALAR": 1, "VEC3": 3}
MAX_STRETCH = 1.5  # a prop may be scaled by at most this factor, either way, on any axis


def load(path):
    data = path.read_bytes()
    magic, version, total = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF" and version == 2 and total == len(data), "bad GLB header"
    json_length, json_kind = struct.unpack_from("<I4s", data, 12)
    assert json_kind == b"JSON"
    document = json.loads(data[20:20 + json_length])
    bin_start = 20 + json_length
    bin_length, bin_kind = struct.unpack_from("<I4s", data, bin_start)
    assert bin_kind == b"BIN\0" and bin_length == document["buffers"][0]["byteLength"]
    blob = data[bin_start + 8:bin_start + 8 + bin_length]

    def read(index):
        accessor = document["accessors"][index]
        view = document["bufferViews"][accessor["bufferView"]]
        array = np.frombuffer(
            blob, COMPONENT[accessor["componentType"]],
            accessor["count"] * WIDTH[accessor["type"]], view["byteOffset"],
        )
        return array.reshape(accessor["count"], -1)

    meshes = {}
    for node in document["nodes"]:
        primitive = document["meshes"][node["mesh"]]["primitives"][0]
        positions = read(primitive["attributes"]["POSITION"]).astype(np.float64)
        normals = read(primitive["attributes"]["NORMAL"]).astype(np.float64)
        index = read(primitive["indices"]).reshape(-1, 3)
        meshes[node["name"]] = (positions[index], normals[index])
    return meshes


def surface_problems(tris, normals):
    problems = []
    face = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    if (np.linalg.norm(face, axis=1) < 1e-9).any():
        problems.append("has zero-area triangles")
    if (np.einsum("ij,ij->i", face, normals.mean(axis=1)) <= 0).any():
        problems.append("has triangles wound against their normals")

    # Closed surface: every directed edge is matched by its reverse exactly once.
    edges = {}
    for tri in np.round(tris, 5):
        for a, b in ((0, 1), (1, 2), (2, 0)):
            edge = (tuple(tri[a]), tuple(tri[b]))
            edges[edge] = edges.get(edge, 0) + 1
    if any(edges.get((b, a), 0) != count for (a, b), count in edges.items()):
        problems.append("is not a closed surface")

    if np.einsum("ij,ij->", tris[:, 0], np.cross(tris[:, 1], tris[:, 2])) <= 0:
        problems.append("is inside out")
    return problems


def center_of(mesh):
    points = mesh[0].reshape(-1, 3)
    return (points.min(axis=0) + points.max(axis=0)) / 2


def check_model(path, required_markers):
    failures = []
    meshes = load(path)
    for marker in required_markers:
        if marker not in meshes:
            failures.append(f"{marker} missing")
        elif marker in FRAME and np.abs(center_of(meshes[marker]) - FRAME[marker]).max() > 1e-5:
            failures.append(f"{marker} is misplaced")
    visible = {name: mesh for name, mesh in meshes.items() if not name.startswith("Mark")}
    for name, (tris, normals) in visible.items():
        if name not in PALETTE:
            failures.append(f"part {name} has no palette entry")
        failures += [f"{name} {problem}" for problem in surface_problems(tris, normals)]
    points = np.concatenate([mesh[0].reshape(-1, 3) for mesh in visible.values()])
    return failures, points, list(visible)


def check_layouts():
    """Every `prop = "Name"` in a map layout must exist and fit its box without much stretch."""
    failures, uses = [], 0
    number = r"(-?[\d.]+)"
    for path in sorted((ROOT / "src" / "server" / "Maps").glob("*.luau")):
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            match = re.search(r'prop = "(\w+)"', line)
            if not match:
                continue
            uses += 1
            where = f"{path.name}:{line_number}"
            name = match.group(1)
            if name not in PROPS:
                failures.append(f"{where}: unknown prop {name}")
                continue
            size = re.search(rf"size = \{{ {number}, {number}, {number} \}}", line)
            if not size:
                continue  # placed at its own size
            box = [float(v) for v in size.groups()]
            if "propTurn = true" in line:
                box = [box[2], box[1], box[0]]
            for axis, (wanted, made) in enumerate(zip(box, PROPS[name][1])):
                ratio = wanted / made
                if not 1 / MAX_STRETCH <= ratio <= MAX_STRETCH:
                    failures.append(f"{where}: {name} stretched x{ratio:.2f} on {'XYZ'[axis]}")
    return failures, uses


def main():
    failures = []

    for name in WEAPONS:
        problems, _, parts = check_model(ROOT / "assets" / "weapons" / f"{name}.glb", [*FRAME, "MarkMuzzle"])
        failures += [f"weapon {name}: {p}" for p in problems]
        print(f"weapon {name:11} {'ok' if not problems else 'FAIL'}  parts: {', '.join(parts)}")

    for name, (_, size) in PROPS.items():
        problems, points, parts = check_model(ROOT / "assets" / "props" / f"{name}.glb", list(FRAME))
        low, high = points.min(axis=0), points.max(axis=0)
        if np.abs(high - low - size).max() > 1e-4:
            problems.append(f"fills {np.round(high - low, 3)}, stated {size}")
        if np.abs(high + low).max() > 1e-4:
            problems.append(f"is off centre by {np.round((high + low) / 2, 3)}")
        failures += [f"prop {name}: {p}" for p in problems]
        print(f"prop   {name:11} {'ok' if not problems else 'FAIL'}  parts: {', '.join(parts)}")

    problems, uses = check_layouts()
    failures += problems
    print(f"layouts: {uses} prop placements checked")

    for failure in failures:
        print("FAIL", failure)
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
