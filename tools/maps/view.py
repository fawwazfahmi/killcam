"""Render a 3D preview of a map layout, in the colours the game will use.

    python tools/maps/view.py CraterStation

Writes assets/maps/<Name>_view.png. It is a cutaway: tall walls and blocks are
drawn low and roofs are left out, so the inside can be seen. Lighting is a
fixed preview light, not the map's own lamps.

Run from the project root. Needs Lune, numpy and Pillow.
"""

import math
import re
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "models"))
sys.path.insert(0, str(Path(__file__).parent))

from meshkit import box, merge  # noqa: E402
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


def ramp_piece(ramp, sign):
    start = np.array(ramp["from"], dtype=float) * (sign, 1, 1)
    end = np.array(ramp["to"], dtype=float) * (sign, 1, 1)
    forward = (end - start) / np.linalg.norm(end - start)
    right = np.cross(forward, [0.0, 1.0, 0.0])
    right /= np.linalg.norm(right)
    up = np.cross(right, forward)
    tris, normals = box((0, -0.5, 0), (ramp["width"], 1, np.linalg.norm(end - start)))
    axes = np.array([right, up, forward])  # local X, Y, Z in world space
    return tris @ axes + (start + end) / 2, normals @ axes


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "NightYard"
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

    meshes = {}
    for item, sign in instances(layout):
        center = np.array(item["pos"], dtype=float) * (sign, 1, 1)
        size = list(item["size"])
        bottom, top = center[1] - size[1] / 2, center[1] + size[1] / 2
        if bottom >= ROOF_FROM:
            continue
        own = layout.get("styles", {}).get(item["kind"])
        if own and own.get("transparency", 0) >= 0.5:
            continue  # glass: this renderer cannot see through it, so leave it out
        if bottom < 1 and top >= CUT_FROM:
            size[1] = CUT_TO
            center[1] = bottom + CUT_TO / 2
        yaw = item.get("yaw", 0)
        piece = turned(box(center, size), math.radians(180 - yaw if sign < 0 else yaw), center)
        meshes.setdefault(key_for(item["kind"], sign, item.get("prop")), []).append(piece)
    for ramp in layout["ramps"]:
        for sign in (1, -1) if ramp.get("mirror") else (1,):
            meshes.setdefault(key_for(ramp["kind"], sign), []).append(ramp_piece(ramp, sign))

    out = ROOT / "assets" / "maps" / f"{name}_view.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    image = render([(key, merge(pieces)) for key, pieces in meshes.items()], palette, (1200, 760), yaw=62, pitch=38)
    image.save(out)
    print(f"{layout['name']} -> {out.relative_to(ROOT)}")

    # The backdrop, as a flat elevation seen from the map looking south. It is
    # not a perspective view: it shows the shapes and how they line up.
    if layout.get("backdrop"):
        scenery = {}
        for item in layout["backdrop"]:
            if item["size"][0] > 1000:
                continue  # the ground
            center = np.array(item["pos"], dtype=float)
            piece = turned(box(center, item["size"]), math.radians(item.get("yaw", 0)), center)
            scenery.setdefault(key_for(item["kind"], 1), []).append(piece)
        skyline = ROOT / "assets" / "maps" / f"{name}_skyline.png"
        image = render([(key, merge(pieces)) for key, pieces in scenery.items()], palette, (1500, 520), yaw=-90, pitch=2)
        image.save(skyline)
        print(f"{layout['name']} -> {skyline.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
