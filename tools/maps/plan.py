"""Draw a top-down plan of a map layout and check that it is playable.

    python tools/maps/plan.py NightYard

Writes assets/maps/<Name>_plan.png. Fails if any spawn point is blocked or if a
player cannot walk at ground level from Alpha's spawns to Bravo's.

Run from the project root. Needs Lune (to read the layout) and Pillow.
"""

import json
import math
import subprocess
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SCALE = 6  # pixels per stud
MARGIN = 6  # studs around the map
PLAYER_HEIGHT = 5.0
PLAYER_RADIUS = 1.0
CELL = 0.5  # studs per walk-grid cell

BACKGROUND = (16, 18, 24)
FILL = {
    "Floor": (34, 37, 46),
    "Wall": (150, 156, 168),
    "Building": (146, 122, 108),
    "Cover": (196, 160, 110),
    "Catwalk": (88, 120, 150),
    "Post": (255, 190, 120),
    "Glow": (255, 140, 60),
    "Regolith": (44, 46, 52),
    "Rim": (96, 98, 106),
    "Hull": (196, 200, 208),
    "Solar": (70, 100, 190),
    "Ramp": (88, 120, 150),
    "Team": (220, 70, 70),
    "Mass": (150, 156, 168),
    "House": (255, 196, 30),
    "Deck": (88, 120, 150),
    "Terrace": (190, 80, 80),
    "Balcony": (70, 110, 200),
}
SIGHT_HEIGHT = 5.5  # a box at least this tall hides a standing player
PROP_FILL = {
    "Crate": (150, 118, 80), "CrateStack": (150, 118, 80), "Container": (160, 80, 62),
    "Barrier": (150, 152, 156), "PalletLoad": (96, 106, 128), "Screen": (104, 114, 132),
}
TEAM = {1: (220, 70, 70), -1: (70, 120, 230)}


def load(name):
    result = subprocess.run(
        ["lune", "run", "tools/maps/dump", name], cwd=ROOT, capture_output=True, text=True, check=True
    )
    return json.loads(result.stdout)


def footprint(box, sign):
    """Corners of a box seen from above, as (x, z), using MapBuilder's mirroring rules."""
    cx, _, cz = box["pos"]
    cx *= sign
    sx, _, sz = box["size"]
    yaw = box.get("yaw", 0)
    angle = math.radians(180 - yaw if sign < 0 else yaw)
    # CFrame.Angles(0, a, 0) carries local +X to (cos a, -sin a) in (x, z).
    ax, az = math.cos(angle), -math.sin(angle)
    bx, bz = math.sin(angle), math.cos(angle)
    return [
        (cx + ax * dx * sx / 2 + bx * dz * sz / 2, cz + az * dx * sx / 2 + bz * dz * sz / 2)
        for dx, dz in ((-1, -1), (1, -1), (1, 1), (-1, 1))
    ]


def carve_solids(bounds, open_rects):
    """The rectangles filling `bounds` everywhere `open_rects` does not. The
    same rule as Shared.Logic.Carve, so the tools see the map the game builds."""
    inside = lambda r, x, z: r[0] < x < r[2] and r[1] < z < r[3]
    xs = sorted({bounds[0], bounds[2]} | {v for r in open_rects for v in (r[0], r[2]) if bounds[0] < v < bounds[2]})
    zs = sorted({bounds[1], bounds[3]} | {v for r in open_rects for v in (r[1], r[3]) if bounds[1] < v < bounds[3]})
    solids = []
    for i in range(len(xs) - 1):
        mx = (xs[i] + xs[i + 1]) / 2
        j = 0
        while j < len(zs) - 1:
            solid = lambda k: not any(inside(r, mx, (zs[k] + zs[k + 1]) / 2) for r in open_rects)
            if solid(j):
                k = j
                while k + 1 < len(zs) - 1 and solid(k + 1):
                    k += 1
                solids.append((xs[i], zs[j], xs[i + 1], zs[k + 1]))
                j = k + 1
            else:
                j += 1
    return solids


def instances(layout):
    """Every placed box as (box, sign), including mirrored copies and lamp posts."""
    placed = []
    fill = layout.get("fill")
    if fill:
        for x1, z1, x2, z2 in carve_solids(fill["bounds"], fill["open"]):
            placed.append((
                {
                    "kind": fill["kind"],
                    "pos": [(x1 + x2) / 2, fill["height"] / 2, (z1 + z2) / 2],
                    "size": [x2 - x1, fill["height"], z2 - z1],
                },
                1,
            ))
    for box in layout["boxes"]:
        placed.append((box, 1))
        if box.get("mirror"):
            placed.append((box, -1))
    for lamp in layout["lamps"]:
        if not lamp.get("post"):
            continue
        x, y, z = lamp["pos"]
        post = {"kind": "Post", "pos": [x - 0.95, (y - 0.45) / 2, z], "size": [0.6, y - 0.45, 0.6]}
        placed.append((post, 1))
        if lamp.get("mirror"):
            placed.append((post, -1))
    return placed


def is_floor(box):
    """Ground to walk on: its top is at or below ground level."""
    return box["pos"][1] + box["size"][1] / 2 <= 0.01


def blocks_walking(box):
    """True if the box stands in the way of someone walking on the ground."""
    bottom = box["pos"][1] - box["size"][1] / 2
    top = box["pos"][1] + box["size"][1] / 2
    return top > 1.0 and bottom < PLAYER_HEIGHT


def ramp_footprints(layout):
    for ramp in layout["ramps"]:
        for sign in (1, -1) if ramp.get("mirror") else (1,):
            (fx, _, fz), (tx, _, tz) = ramp["from"], ramp["to"]
            fx, tx = fx * sign, tx * sign
            length = math.hypot(tx - fx, tz - fz)
            ux, uz = (tx - fx) / length, (tz - fz) / length
            nx, nz = -uz * ramp["width"] / 2, ux * ramp["width"] / 2
            yield [(fx + nx, fz + nz), (tx + nx, tz + nz), (tx - nx, tz - nz), (fx - nx, fz - nz)]


def top_down(layout, placed, include, grow=0.0):
    """Mask of the ground covered by the boxes `include` accepts, plus every ramp."""
    bx, _, bz = layout["bounds"]["size"]
    image = Image.new("L", (int(bx / CELL), int(bz / CELL)), 0)
    draw = ImageDraw.Draw(image)
    to_cell = lambda x, z: ((x + bx / 2) / CELL, (z + bz / 2) / CELL)
    for box, sign in placed:
        if not include(box):
            continue
        corners = [to_cell(x, z) for x, z in footprint(box, sign)]
        draw.polygon(corners, fill=255)
        if grow:
            draw.line(corners + corners[:1], fill=255, width=int(grow * 2))
            for cx, cz in corners:
                draw.ellipse((cx - grow, cz - grow, cx + grow, cz + grow), fill=255)
    return image, draw, to_cell


def walk_grid(layout, placed):
    image, draw, to_cell = top_down(
        layout, placed, lambda box: not is_floor(box) and blocks_walking(box), PLAYER_RADIUS / CELL
    )
    # Ramps are walkable but their undersides are not, so the plan treats them as solid.
    for corners in ramp_footprints(layout):
        draw.polygon([to_cell(x, z) for x, z in corners], fill=255)
    return image, to_cell


def runs(mask):
    """For every True cell, the length of the horizontal run of True cells it is in."""
    out = np.zeros(mask.shape, dtype=np.int32)
    for row in range(mask.shape[0]):
        line = np.concatenate([[False], mask[row], [False]])
        edges = np.flatnonzero(line[1:] != line[:-1])
        for start, stop in zip(edges[::2], edges[1::2]):
            out[row, start:stop] = stop - start
    return out


def metrics(layout, placed):
    """The same measurements taken of the reference maps, for comparison."""
    floor, _, _ = top_down(layout, placed, is_floor)
    hides = lambda box: (
        not is_floor(box)
        and box["pos"][1] + box["size"][1] / 2 >= SIGHT_HEIGHT
        and box["pos"][1] - box["size"][1] / 2 < PLAYER_HEIGHT - 1
    )
    blocked, draw, to_cell = top_down(layout, placed, hides)
    for corners in ramp_footprints(layout):
        draw.polygon([to_cell(x, z) for x, z in corners], fill=255)
    floor, blocked = np.array(floor) > 0, np.array(blocked) > 0
    free = floor & ~blocked

    cover = [box for box, _ in placed if box["kind"] == "Cover"]
    crouch = sum(1 for box in cover if box["size"][1] < SIGHT_HEIGHT)
    area = floor.sum() * CELL * CELL
    across, along = runs(free), runs(free.T).T
    width = np.percentile(np.minimum(across, along)[free] * CELL, [25, 50, 75])
    return [
        f"floor {area:,.0f} studs2, {100 * (floor & blocked).sum() / floor.sum():.0f}% hidden behind standing-height pieces",
        f"cover: {crouch} crouch + {len(cover) - crouch} standing = {1000 * len(cover) / area:.2f} per 1,000 studs2",
        f"longest straight clear line: {max(across.max(), along.max()) * CELL:.0f} studs",
        f"passage width quartiles: {width[0]:.0f} / {width[1]:.0f} / {width[2]:.0f} studs",
    ]


def reachable(grid, start):
    cols, rows = grid.size
    pixels = grid.load()
    seen = {start}
    queue = deque([start])
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < cols and 0 <= ny < rows and (nx, ny) not in seen and pixels[nx, ny] == 0:
                seen.add((nx, ny))
                queue.append((nx, ny))
    return seen


def spawn_points(layout):
    """(x, z) of each team's spawns: first team, second team."""
    spawns = layout["spawns"]
    if not spawns:  # the lobby has no team spawns
        return [], []
    if isinstance(spawns, list):  # one list, mirrored for the second team
        return [(x, z) for x, _, z in spawns], [(-x, z) for x, _, z in spawns]
    sides = [[(x, z) for x, _, z in spawns[team]] for team in layout["teams"]]
    return sides[0], sides[1] if len(sides) > 1 else []  # the test range has one side


def check_stations(layout, placed):
    """The lobby: every station must be reachable on foot from where players arrive."""
    grid, to_cell = walk_grid(layout, placed)
    pixels = grid.load()
    cell = lambda x, z: tuple(int(v) for v in to_cell(x, z))
    start = cell(layout["arrival"][0], layout["arrival"][2])
    if pixels[start] != 0:
        return ["the arrival point is blocked"]
    seen = reachable(grid, start)
    problems = []
    for station in layout["stations"]:
        # A player stands in front of a station, not inside it.
        facing = math.radians(station["facing"])
        x = station["pos"][0] + math.sin(facing) * -4
        z = station["pos"][1] + math.cos(facing) * -4
        if cell(x, z) not in seen:
            problems.append(f"station {station['name']} cannot be reached")
    return problems


def check_range(layout, placed):
    """The test range: every dummy has room to stand, and it and every place on
    the ground a player can be sent to can be walked to from where players arrive."""
    grid, to_cell = walk_grid(layout, placed)
    pixels = grid.load()
    cell = lambda x, z: tuple(int(v) for v in to_cell(x, z))
    arrivals, _ = spawn_points(layout)
    problems = [f"spawn {i + 1} is blocked" for i, (x, z) in enumerate(arrivals) if pixels[cell(x, z)] != 0]
    if problems:
        return problems
    seen = reachable(grid, cell(*arrivals[0]))
    half_x, half_z = layout["bounds"]["size"][0] / 2, layout["bounds"]["size"][2] / 2
    cx, _, cz = layout["bounds"]["pos"]
    for dummy in layout["dummies"]:
        x, z = dummy["pos"]
        if cell(x, z) not in seen:
            problems.append(f"the dummy {dummy['label']} is walled in or has no room to stand")
    for spot in layout["spots"]:
        x, y, z = spot["pos"]
        if abs(x - cx) > half_x or abs(z - cz) > half_z:
            problems.append(f"the place {spot['name']} is outside the map")
        elif y < PLAYER_HEIGHT and cell(x, z) not in seen:  # those higher up are on the drop tower
            problems.append(f"the place {spot['name']} cannot be walked to")
    return problems


def check(layout, placed):
    if layout.get("stations"):
        return check_stations(layout, placed)
    if layout.get("dummies"):
        return check_range(layout, placed)
    grid, to_cell = walk_grid(layout, placed)
    pixels = grid.load()
    cell = lambda x, z: tuple(int(v) for v in to_cell(x, z))
    first, second = layout["teams"]
    alpha, bravo = ([cell(x, z) for x, z in points] for points in spawn_points(layout))
    problems = [f"{first} spawn {i + 1} is blocked" for i, c in enumerate(alpha) if pixels[c] != 0]
    problems += [f"{second} spawn {i + 1} is blocked" for i, c in enumerate(bravo) if pixels[c] != 0]
    if not problems:
        seen = reachable(grid, alpha[0])
        problems += [f"{first} spawn {i + 1} is cut off" for i, c in enumerate(alpha) if c not in seen]
        problems += [f"{second} spawn {i + 1} cannot be reached from {first}" for i, c in enumerate(bravo) if c not in seen]
        for site in layout.get("sites", []):
            if cell(*site["pos"]) not in seen:
                problems.append(f"site {site['name']} cannot be reached")
    return problems


def draw_plan(layout, placed, path):
    bx, _, bz = layout["bounds"]["size"]
    width, height = int((bx + MARGIN * 2) * SCALE), int((bz + MARGIN * 2) * SCALE)
    image = Image.new("RGB", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(image)
    to_pixel = lambda x, z: ((x + bx / 2 + MARGIN) * SCALE, (z + bz / 2 + MARGIN) * SCALE)

    # Lowest first, so upper floors and catwalks draw over what is under them.
    for box, sign in sorted(placed, key=lambda item: item[0]["pos"][1] + item[0]["size"][1] / 2):
        corners = [to_pixel(x, z) for x, z in footprint(box, sign)]
        overhead = box["pos"][1] - box["size"][1] / 2 >= PLAYER_HEIGHT
        own = layout.get("styles", {}).get(box["kind"])
        fill = PROP_FILL.get(box.get("prop"), FILL.get(box["kind"], tuple(own["color"]) if own else (120, 120, 120)))
        if box["kind"] == "Team":
            fill = TEAM[sign]
        if overhead:
            draw.line(corners + corners[:1], fill=fill, width=2)
        else:
            draw.polygon(corners, fill=fill)

    for ramp in layout["ramps"]:
        for sign in (1, -1) if ramp.get("mirror") else (1,):
            a = to_pixel(ramp["from"][0] * sign, ramp["from"][2])
            b = to_pixel(ramp["to"][0] * sign, ramp["to"][2])
            draw.line([a, b], fill=(88, 120, 150), width=int(ramp["width"] * SCALE * 0.5))
            draw.ellipse((b[0] - 5, b[1] - 5, b[0] + 5, b[1] + 5), fill=(210, 230, 250))  # high end

    for lamp in layout["lamps"]:
        if lamp.get("bare"):
            continue
        for sign in (1, -1) if lamp.get("mirror") else (1,):
            x, z = to_pixel(lamp["pos"][0] * sign, lamp["pos"][2])
            draw.ellipse((x - 4, z - 4, x + 4, z + 4), fill=(255, 190, 120))

    for site in layout.get("sites", []):
        (cx, cz), (sx, sz) = site["pos"], site["size"]
        a, b = to_pixel(cx - sx / 2, cz - sz / 2), to_pixel(cx + sx / 2, cz + sz / 2)
        draw.rectangle((*a, *b), outline=(255, 196, 30), width=3)
        draw.text(to_pixel(cx - 1, cz - 2), site["name"], fill=(255, 196, 30))

    for station in layout.get("stations", []):
        x, z = to_pixel(*station["pos"])
        draw.rectangle((x - 12, z - 5, x + 12, z + 5), fill=(255, 196, 30))
        draw.text((x - 22, z + 9), station["name"], fill=(255, 196, 30))
    if "arrival" in layout:
        x, z = to_pixel(layout["arrival"][0], layout["arrival"][2])
        draw.ellipse((x - 7, z - 7, x + 7, z + 7), outline=(120, 220, 140), width=3)

    for dummy in layout.get("dummies", []):
        x, z = to_pixel(*dummy["pos"])
        draw.ellipse((x - 5, z - 5, x + 5, z + 5), fill=(255, 120, 60))
        draw.text((x + 8, z - 5), dummy["label"], fill=(255, 160, 110))
    for spot in layout.get("spots", []):
        x, z = to_pixel(spot["pos"][0], spot["pos"][2])
        draw.rectangle((x - 4, z - 4, x + 4, z + 4), outline=(120, 220, 140), width=2)
        draw.text((x + 8, z + 4), spot["name"], fill=(120, 220, 140))

    for sign, points in zip((1, -1), spawn_points(layout)):
        for x, z in points:
            px, pz = to_pixel(x, z)
            draw.rectangle((px - 6, pz - 6, px + 6, pz + 6), fill=TEAM[sign])

    draw.text((10, 8), f"{layout['name']}  -  {bx - 6:.0f} x {bz - 6:.0f} studs, 10 stud grid", fill=(210, 214, 224))
    for stud in range(0, int(bx / 2), 10):
        for sign in (1, -1):
            x, _ = to_pixel(stud * sign, 0)
            draw.line([(x, height - 14), (x, height - 8)], fill=(90, 96, 110))
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "NightYard"
    layout = load(name)
    placed = instances(layout)
    out = ROOT / "assets" / "maps" / f"{name}_plan.png"
    draw_plan(layout, placed, out)
    props = sum(1 for box, _ in placed if box.get("prop"))
    print(f"{layout['name']}: {len(placed)} boxes, {props} dressed with props -> {out.relative_to(ROOT)}")
    for line in metrics(layout, placed):
        print("  " + line)
    problems = check(layout, placed)
    for problem in problems:
        print("FAIL", problem)
    passed = "ok, both spawns connect at ground level"
    if layout.get("stations"):
        passed = "ok, every station can be reached"
    elif layout.get("dummies"):
        passed = "ok, every dummy and every place on the ground can be reached"
    print("walk check:", passed if not problems else "failed")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
