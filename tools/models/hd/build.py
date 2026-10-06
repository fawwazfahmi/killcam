"""Build the high-detail weapons in Blender.

    pip install bpy numpy pillow      (bpy needs the Python version Blender ships for)
    python tools/models/hd/build.py               every weapon
    python tools/models/hd/build.py AK47 MP5      just these
    python tools/models/hd/build.py --fast AK47   quicker, noisier previews

Writes assets/weapons_hd/<Name>.glb, <Name>.png (studio renders) and
<Name>.json (parts, finishes, animation groups, muzzle position in studs).
"""

import importlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from kit import Gun  # noqa: E402
from preview import render  # noqa: E402

ROOT = HERE.parents[2]
OUT = ROOT / "assets" / "weapons_hd"


def designs():
    return {
        module.NAME: module
        for module in (importlib.import_module(f"guns.{path.stem}") for path in sorted((HERE / "guns").glob("*.py")))
        if hasattr(module, "NAME")
    }


def main(args):
    fast = "--fast" in args
    names = [a for a in args if not a.startswith("--")]
    available = designs()
    unknown = [n for n in names if n not in available]
    if unknown:
        sys.exit(f"unknown weapon(s): {', '.join(unknown)}; have {', '.join(available)}")

    OUT.mkdir(parents=True, exist_ok=True)
    for name in names or list(available):
        design = available[name]
        gun = Gun(name)
        grip, muzzle = design.build(gun)
        gun.finish(grip, muzzle, design.STUDS_PER_METRE)
        gun.export(OUT / f"{name}.glb")

        triangles = gun.triangles()
        manifest = {
            "name": name,
            "studsPerMetre": design.STUDS_PER_METRE,
            "muzzle": [round(c, 4) for c in (gun.muzzle.x, gun.muzzle.z, -gun.muzzle.y)],
            "parts": {
                part: {**info, "triangles": triangles[part]} for part, info in gun.parts.items()
            },
        }
        (OUT / f"{name}.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        render(gun, OUT / f"{name}.png", samples=24 if fast else 96)
        print(f"{name}: {sum(triangles.values())} triangles in {len(triangles)} parts, largest "
              f"{max(triangles, key=triangles.get)} {max(triangles.values())}")


if __name__ == "__main__":
    main(sys.argv[1:])
