"""Find holes in a map's walls.

    python tools/maps/inspect.py Stockyard

Checks three things and fails if any of them is wrong:

  leaks     can a player walk off the edge of the map, or into a wall's inside
  cracks    a gap between two walls too narrow to walk through: you cannot get
            in, but you can see and shoot through it, which is never intended
  doorways  every opening wide enough to walk through, listed with its width,
            so they can be read against what the layout's comments promise

Writes assets/maps/<Name>_walls.png: the solid parts in grey, every doorway in
yellow, every crack in red.
"""

import math
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))

from plan import PLAYER_HEIGHT, PLAYER_RADIUS, footprint, instances, is_floor, load, ramp_footprints

CELL = 0.25  # studs per grid cell
MIN_DOOR = 2 * PLAYER_RADIUS  # anything narrower than this cannot be walked through
MAX_DOOR = 30.0  # wider than this is open ground, not a doorway
WALL_THICK = 0.9  # a gap only counts when the wall either side is this thick
WALL_HEIGHT = 9.0  # a box this tall is structure; anything shorter is cover
MAX_DEPTH = 8.0  # a doorway is only as deep as the wall is thick; deeper is a corridor
SCALE = 4  # pixels per stud in the picture


def blocks_sight(box):
    """True if the box stops a standing player walking through it."""
    bottom = box["pos"][1] - box["size"][1] / 2
    top = box["pos"][1] + box["size"][1] / 2
    return top > 1.0 and bottom < PLAYER_HEIGHT


def is_wall(box):
    """True for the map's structure. Crates and barriers are not walls: a gap
    between two of them is cover, not a hole."""
    bottom = box["pos"][1] - box["size"][1] / 2
    top = box["pos"][1] + box["size"][1] / 2
    return bottom < PLAYER_HEIGHT and top - max(bottom, 0) >= WALL_HEIGHT


def solid_grid(layout, placed, only_walls=False):
    """A mask of what blocks a standing player, plus the grid's origin."""
    bx, _, bz = layout["bounds"]["size"]
    # A margin all round, so there is somewhere "outside" to flood from.
    margin = 12
    low = np.array([-bx / 2 - margin, -bz / 2 - margin])
    cols = int((bx + margin * 2) / CELL)
    rows = int((bz + margin * 2) / CELL)

    image = Image.new("L", (cols, rows), 0)
    draw = ImageDraw.Draw(image)
    to_cell = lambda x, z: ((x - low[0]) / CELL, (z - low[1]) / CELL)
    for box, sign in placed:
        if is_floor(box) or not blocks_sight(box):
            continue
        if only_walls and not is_wall(box):
            continue
        draw.polygon([to_cell(x, z) for x, z in footprint(box, sign)], fill=255)
    return np.array(image) > 0, low, to_cell


def floor_grid(layout, placed, shape, to_cell):
    """A mask of the ground a player could stand on, ramps included."""
    image = Image.new("L", (shape[1], shape[0]), 0)
    draw = ImageDraw.Draw(image)
    for box, sign in placed:
        if is_floor(box):
            draw.polygon([to_cell(x, z) for x, z in footprint(box, sign)], fill=255)
    for corners in ramp_footprints(layout):
        draw.polygon([to_cell(x, z) for x, z in corners], fill=255)
    return np.array(image) > 0


def flood(passable, starts):
    seen = np.zeros(passable.shape, dtype=bool)
    queue = deque()
    for start in starts:
        if passable[start]:
            seen[start] = True
            queue.append(start)
    rows, cols = passable.shape
    while queue:
        r, c = queue.popleft()
        for nr, nc in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)):
            if 0 <= nr < rows and 0 <= nc < cols and not seen[nr, nc] and passable[nr, nc]:
                seen[nr, nc] = True
                queue.append((nr, nc))
    return seen


def grow(mask, studs):
    """Thicken a mask by `studs`, so walking room allows for a player's width."""
    steps = int(round(studs / CELL))
    out = mask.copy()
    for _ in range(steps):
        grown = out.copy()
        grown[1:, :] |= out[:-1, :]
        grown[:-1, :] |= out[1:, :]
        grown[:, 1:] |= out[:, :-1]
        grown[:, :-1] |= out[:, 1:]
        out = grown
    return out


def runs_along(solid, axis):
    """Every gap between two solids along one axis, as (index, start, stop)."""
    lines = solid if axis == 0 else solid.T
    for index, line in enumerate(lines):
        # Where the line changes between solid and free. They alternate, so a
        # gap runs from a change into free to the next change back into solid.
        edges = np.flatnonzero(line[1:] != line[:-1]) + 1
        for first, second in zip(edges, edges[1:]):
            if line[first - 1] and not line[first]:
                yield index, first, second


def thickness(line, at, direction):
    """How far the solid run touching `at` reaches in `direction`."""
    count = 0
    index = at
    while 0 <= index < len(line) and line[index]:
        count += 1
        index += direction
    return count * CELL


def openings(wall, shape):
    """Every way through the map's structure, as (cell at its middle, width).

    A gap only counts when there is real wall either side of it, and when the
    gap is no deeper than a wall is thick. A corridor is a gap on every row
    along its length, which is how it is told apart from a doorway."""
    found = []
    for axis in (0, 1):
        lines = wall if axis == 0 else wall.T
        gaps = {}  # cell -> width, for this axis only
        for index, a, b in runs_along(wall, axis):
            width = (b - a) * CELL
            if width > MAX_DOOR:
                continue
            line = lines[index]
            if thickness(line, a - 1, -1) < WALL_THICK or thickness(line, b, 1) < WALL_THICK:
                continue
            middle = (a + b) // 2
            cell = (index, middle) if axis == 0 else (middle, index)
            # A way through has open space on both sides of the wall it
            # pierces. A gap running alongside a thin wall has solid on one
            # side, and is not a way anywhere.
            step = int((WALL_THICK + 1.0) / CELL)
            near = (
                [(index - step, middle), (index + step, middle)]
                if axis == 0
                else [(middle, index - step), (middle, index + step)]
            )
            if any(not (0 <= r < shape[0] and 0 <= c < shape[1]) or wall[r, c] for r, c in near):
                continue
            gaps[cell] = width

        # `index` runs across the wall; a doorway's cluster is thin in it.
        for group in label(list(gaps), shape):
            spread = [cell[0] if axis == 0 else cell[1] for cell in group]
            if (max(spread) - min(spread)) * CELL > MAX_DEPTH:
                continue  # a corridor running alongside, not a way through a wall
            middle = group[len(group) // 2]
            found.append((middle, min(gaps[cell] for cell in group)))
    return found


def label(cells, shape):
    """Group neighbouring cells into clusters; returns a list of cell lists."""
    grid = np.zeros(shape, dtype=bool)
    for r, c in cells:
        grid[r, c] = True
    seen = np.zeros(shape, dtype=bool)
    clusters = []
    for r, c in cells:
        if seen[r, c]:
            continue
        group, queue = [], deque([(r, c)])
        seen[r, c] = True
        while queue:
            cr, cc = queue.popleft()
            group.append((cr, cc))
            for nr in range(cr - 2, cr + 3):
                for nc in range(cc - 2, cc + 3):
                    if 0 <= nr < shape[0] and 0 <= nc < shape[1] and grid[nr, nc] and not seen[nr, nc]:
                        seen[nr, nc] = True
                        queue.append((nr, nc))
        clusters.append(group)
    return clusters


def to_world(low, cell):
    r, c = cell
    return low[0] + c * CELL, low[1] + r * CELL


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "Stockyard"
    layout = load(name)
    placed = instances(layout)
    solid, low, to_cell = solid_grid(layout, placed)
    wall, _, _ = solid_grid(layout, placed, only_walls=True)
    floor = floor_grid(layout, placed, solid.shape, to_cell)

    free = ~solid
    walkable = ~grow(solid, PLAYER_RADIUS) & floor
    outside = flood(free, [(0, 0), (0, free.shape[1] - 1), (free.shape[0] - 1, 0)])

    problems = []

    # 1. Leaks: walkable ground that joins the outside world.
    leak = walkable & outside
    if leak.any():
        for group in label(list(zip(*np.nonzero(leak))), solid.shape)[:6]:
            x, z = to_world(low, group[len(group) // 2])
            problems.append(f"the map leaks near x {x:.0f}, z {z:.0f} ({len(group) * CELL * CELL:.0f} studs2)")

    # 2. Every way through the structure, split into doorways and cracks.
    widths = {}
    for cell, width in openings(wall, solid.shape):
        if not outside[cell]:
            widths[cell] = min(widths.get(cell, width), width)
    doorways = [cell for cell, width in widths.items() if width >= MIN_DOOR]
    cracks = [cell for cell, width in widths.items() if width < MIN_DOOR]

    crack_groups = label(cracks, solid.shape)
    for group in crack_groups:
        narrowest = min(widths[cell] for cell in group)
        x, z = to_world(low, group[len(group) // 2])
        problems.append(
            f"a crack {narrowest:.2f} studs wide at x {x:.0f}, z {z:.0f}: too narrow to walk through, "
            "but you can see and shoot through it"
        )

    door_groups = label(doorways, solid.shape)
    found = []
    for group in door_groups:
        x, z = to_world(low, group[len(group) // 2])
        found.append((x, z, min(widths[cell] for cell in group)))
    found.sort(key=lambda d: d[1])

    print(f"{layout['name']}: {len(found)} openings in the structure, {len(crack_groups)} cracks")

    for x, z, width in found:
        print(f"  opening  x {x:7.1f}  z {z:7.1f}  {width:5.1f} studs wide")

    # Against what the layout says it means to have.
    declared = layout.get("doors")
    if declared:
        NEAR = 9.0  # studs: how close a found opening must be to count as the declared one
        unclaimed = list(found)
        for wanted in declared:
            wx, wz, width, note = wanted[0], wanted[1], wanted[2], wanted[3]
            match = None
            best = NEAR
            for door in unclaimed:
                distance = math.hypot(door[0] - wx, door[1] - wz)
                if distance <= best:
                    match, best = door, distance
            if match is None:
                problems.append(f"missing doorway: {note} (x {wx:.0f}, z {wz:.0f}) is walled up")
            else:
                unclaimed.remove(match)
                if abs(match[2] - width) > 4:
                    problems.append(f"{note}: {match[2]:.0f} studs wide, the design says {width:.0f}")
        # Openings that are not in the layout's list are reported but do not
        # fail: where two declared rooms touch, the opening between them is
        # intended by construction, and the detector also over-reports around
        # thin walls. Leaks and cracks are the real defects, and those do fail.
        for x, z, width in unclaimed:
            print(f"  note: opening {width:.0f} studs wide at x {x:.0f}, z {z:.0f} is not in the layout's door list")
    else:
        for x, z, width in found:
            print(f"  opening  x {x:7.1f}  z {z:7.1f}  {width:5.1f} studs wide")

    # 3. The picture.
    bx, _, bz = layout["bounds"]["size"]
    picture = Image.new("RGB", (solid.shape[1] * SCALE // 2, solid.shape[0] * SCALE // 2), (16, 18, 24))
    draw = ImageDraw.Draw(picture)
    small = Image.fromarray(np.where(solid, 150, 32).astype(np.uint8)).resize(picture.size, Image.NEAREST)
    picture.paste(small.convert("RGB"), (0, 0))
    spot = lambda cell, colour, size: draw.ellipse(
        (
            cell[1] * SCALE / 2 - size,
            cell[0] * SCALE / 2 - size,
            cell[1] * SCALE / 2 + size,
            cell[0] * SCALE / 2 + size,
        ),
        outline=colour,
        width=2,
    )
    for group in door_groups:
        spot(group[len(group) // 2], (255, 196, 30), 7)
    for group in crack_groups:
        spot(group[len(group) // 2], (255, 60, 60), 11)
    out = ROOT / "assets" / "maps" / f"{name}_walls.png"
    picture.save(out)
    print(f"  -> {out.relative_to(ROOT)}")

    for problem in problems:
        print("FAIL", problem)
    print("walls:", "ok" if not problems else f"{len(problems)} problems")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
