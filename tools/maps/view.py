"""Render a 3D preview of a map layout, in the colours the game will use.

    python tools/maps/view.py CraterStation

Writes assets/maps/<Name>_view.png. It is a cutaway: tall walls and blocks are
drawn low and roofs are left out, so the inside can be seen. Lighting is a
fixed preview light, not the map's own lamps, and signboards are drawn blank.

To look at part of a map as it stands, roofs and all:

    python tools/maps/view.py LebuhLama --full --crop=-62,-12,50,24 --yaw 90 --pitch 12 --tag market

`--crop` is x1,z1,x2,z2 in studs. `--yaw 90` looks north, -90 south, 0 west
and 180 east. `--tag` goes in the file name, so one view does not overwrite
another.

Run from the project root. Needs Lune, numpy and Pillow.
"""

import argparse
import math
import re
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "models"))
sys.path.insert(0, str(Path(__file__).parent))

from meshkit import _flat, box, cylinder, merge  # noqa: E402
from plan import instances, load  # noqa: E402
from render import render  # noqa: E402

# Cutaway: anything standing on the ground and at least CUT_FROM tall is drawn
# CUT_TO tall, and anything that starts at ROOF_FROM or higher is left out.
CUT_FROM, CUT_TO, ROOF_FROM = 20, 4, 13.5
PROP_COLORS = {
    "Crate": (112, 88, 60), "CrateStack": (112, 88, 60), "Container": (120, 60, 46),
    "Barrier": (118, 120, 124), "PalletLoad": (66, 74, 90), "Screen": (74, 82, 96),
}


def default_styles():
    """Colours from the STYLES table in MapBuilder."""
    source = (ROOT / "src" / "server" / "MapBuilder.luau").read_text(encoding="utf-8")
    pattern = r"(\w+) = \{ Color3\.fromRGB\((\d+), (\d+), (\d+)\), Enum\.Material\.(\w+) \}"
    return {
        name: {"color": (int(r), int(g), int(b)), "emissive": material == "Neon"}
        for name, r, g, b, material in re.findall(pattern, source)
    }


def turned(piece, yaw, center):
    """Rotate a piece about a vertical axis through `center`, as CFrame.Angles(0, yaw, 0) does."""
    c, s = math.cos(yaw), math.sin(yaw)
    spin = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    tris, normals = piece
    return (tris - center) @ spin.T + center, normals @ spin.T


def _closed(faces, center):
    """Flat-shaded triangles from polygons, each wound to face away from `center`."""
    tris = []
    for face in faces:
        for index in range(1, len(face) - 1):
            a, b, c = face[0], face[index], face[index + 1]
            if np.dot(np.cross(b - a, c - a), (a + b + c) / 3 - center) < 0:
                b, c = c, b
            tris.append([a, b, c])
    return _flat(tris)


def wedge(center, size):
    """A box cut corner to corner as Roblox cuts it: upright on +Z, down to nothing on -Z."""
    c = np.asarray(center, dtype=float)
    hx, hy, hz = np.asarray(size, dtype=float) / 2
    a, b = c + (-hx, -hy, -hz), c + (hx, -hy, -hz)
    d, e = c + (-hx, -hy, hz), c + (hx, -hy, hz)
    f, g = c + (-hx, hy, hz), c + (hx, hy, hz)
    # The box's own middle lies on the slope, so faces are judged from inside the wedge.
    return _closed([[a, b, e, d], [d, e, g, f], [a, f, g, b], [a, d, f], [b, g, e]], c + (0, -hy / 3, hz / 3))


def ball(center, size, rings=5, segments=8):
    c = np.asarray(center, dtype=float)
    h = np.asarray(size, dtype=float) / 2
    point = lambda i, j: c + h * (
        math.sin(math.pi * i / rings) * math.cos(2 * math.pi * j / segments),
        math.cos(math.pi * i / rings),
        math.sin(math.pi * i / rings) * math.sin(2 * math.pi * j / segments),
    )
    faces = [
        [point(i, j), point(i, j + 1), point(i + 1, j + 1), point(i + 1, j)]
        for i in range(rings)
        for j in range(segments)
    ]
    return _closed(faces, c)


def shaped(item, center, size):
    """The piece for a box, in the shape the game will give it, before it is turned."""
    shape = item.get("shape")
    if shape == "Wedge":
        return wedge(center, size)
    if shape == "Ball":
        return ball(center, size)
    if shape == "Cylinder":
        axis = {"X": 0, "Z": 2}.get(item.get("axis"), 1)
        half = np.zeros(3)
        half[axis] = size[axis] / 2
        return cylinder(center - half, center + half, size[(axis + 1) % 3] / 2, segments=10)
    return box(center, size)


def clipped(center, size, crop):
    """A box cut down to the part of it inside `crop`, or None if it has none."""
    x1, x2 = max(center[0] - size[0] / 2, crop[0]), min(center[0] + size[0] / 2, crop[2])
    z1, z2 = max(center[2] - size[2] / 2, crop[1]), min(center[2] + size[2] / 2, crop[3])
    if x1 >= x2 or z1 >= z2:
        return None
    return np.array([(x1 + x2) / 2, center[1], (z1 + z2) / 2]), [x2 - x1, size[1], z2 - z1]


def ramp_piece(ramp, sign):
    start = np.array(ramp["from"], dtype=float) * (sign, 1, 1)
    end = np.array(ramp["to"], dtype=float) * (sign, 1, 1)
    forward = (end - start) / np.linalg.norm(end - start)
    right = np.cross(forward, [0.0, 1.0, 0.0])
    right /= np.linalg.norm(right)
    up = np.cross(right, forward)
    thick = ramp.get("thick", 1)
    tris, normals = box((0, -thick / 2, 0), (ramp["width"], thick, np.linalg.norm(end - start)))
    axes = np.array([right, up, forward])  # local X, Y, Z in world space
    return tris @ axes + (start + end) / 2, normals @ axes


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("name", nargs="?", default="NightYard")
    parser.add_argument("--full", action="store_true", help="no cutaway: walls at full height, roofs on")
    parser.add_argument("--crop", help="x1,z1,x2,z2: draw only this part of the map")
    parser.add_argument("--yaw", type=float, default=62)
    parser.add_argument("--pitch", type=float, default=38)
    parser.add_argument("--tag", help="added to the file name")
    args = parser.parse_args()
    name = args.name
    crop = [float(v) for v in args.crop.split(",")] if args.crop else None
    layout = load(name)
    styles = default_styles()
    palette = {}

    def key_for(kind, sign, prop=None):
        custom = layout.get("styles", {}).get(kind)
        if prop in PROP_COLORS:
            key, entry = prop, {"color": PROP_COLORS[prop]}
        elif custom:
            mirrored = sign < 0 and custom.get("mirrorColor")
            key = f"{kind}{'-mirror' if mirrored else ''}"
            entry = {"color": tuple(mirrored or custom["color"]), "emissive": custom["material"] == "Neon"}
        else:
            key, entry = kind, styles.get(kind, styles["Wall"])
        palette[key] = entry
        return key

    glass = lambda kind: (layout.get("styles", {}).get(kind) or {}).get("transparency", 0) >= 0.5

    meshes = {}
    for item, sign in instances(layout, decor=True):
        center = np.array(item["pos"], dtype=float) * (sign, 1, 1)
        size = list(item["size"])
        bottom, top = center[1] - size[1] / 2, center[1] + size[1] / 2
        if bottom >= ROOF_FROM and not args.full:
            continue
        if glass(item["kind"]):
            continue  # glass: this renderer cannot see through it, so leave it out
        if bottom < 1 and top >= CUT_FROM and not args.full:
            size[1] = CUT_TO
            center[1] = bottom + CUT_TO / 2
        yaw = item.get("yaw", 0)
        if crop:
            inside = crop[0] <= center[0] <= crop[2] and crop[1] <= center[2] <= crop[3]
            if item.get("shape") or yaw:
                if not inside:
                    continue
            else:
                cut = clipped(center, size, crop)
                if cut is None:
                    continue
                center, size = cut
        piece = turned(shaped(item, center, size), math.radians(180 - yaw if sign < 0 else yaw), center)
        meshes.setdefault(key_for(item["kind"], sign, item.get("prop")), []).append(piece)
    for ramp in layout["ramps"]:
        if glass(ramp["kind"]) or (ramp.get("decor") and not args.full):
            continue
        middle = (np.array(ramp["from"]) + np.array(ramp["to"])) / 2
        if crop and not (crop[0] <= middle[0] <= crop[2] and crop[1] <= middle[2] <= crop[3]):
            continue
        for sign in (1, -1) if ramp.get("mirror") else (1,):
            meshes.setdefault(key_for(ramp["kind"], sign), []).append(ramp_piece(ramp, sign))
    # Signboards have no writing here: each is a blank board in its own colour.
    for board in layout.get("signboards", []):
        center = np.array(board["pos"], dtype=float)
        if crop and not (crop[0] <= center[0] <= crop[2] and crop[1] <= center[2] <= crop[3]):
            continue
        if center[1] >= ROOF_FROM and not args.full:
            continue
        key = "sign-" + "-".join(str(v) for v in board["color"])
        palette[key] = {"color": tuple(board["color"]), "emissive": bool(board.get("lit"))}
        flat = box(center, (board["size"][0], board["size"][1], 0.3))
        meshes.setdefault(key, []).append(turned(flat, math.radians(board.get("yaw", 0)), center))

    out = ROOT / "assets" / "maps" / f"{name}_{args.tag or 'view'}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    view = render([(key, merge(pieces)) for key, pieces in meshes.items()], palette, (1200, 760), yaw=args.yaw, pitch=args.pitch)
    view.save(out)
    print(f"{layout['name']} -> {out.relative_to(ROOT)}")

    # The backdrop, as a flat elevation seen from the map looking south. It is
    # not a perspective view: it shows the shapes and how they line up.
    if layout.get("backdrop") and not crop and not args.tag:
        scenery = {}
        for item in layout["backdrop"]:
            if item["size"][0] > 1000:
                continue  # the ground
            center = np.array(item["pos"], dtype=float)
            piece = turned(shaped(item, center, item["size"]), math.radians(item.get("yaw", 0)), center)
            scenery.setdefault(key_for(item["kind"], 1), []).append(piece)
        skyline = ROOT / "assets" / "maps" / f"{name}_skyline.png"
        image = render([(key, merge(pieces)) for key, pieces in scenery.items()], palette, (1500, 520), yaw=-90, pitch=2)
        image.save(skyline)
        print(f"{layout['name']} -> {skyline.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
