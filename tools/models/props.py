"""Original map props for TDM Core.

Each prop fills a box of a stated size, centred on the origin, because a prop
is drawn over a collision box from the map layout (see MapBuilder) and
stretched to match it. Keep shapes close to their box so shots land where the
prop appears to be.

A prop is a list of (palette key, piece). +Y is up and X is the long side.
"""

from meshkit import box, cylinder, extrude


def crate(size, center=(0.0, 0.0, 0.0)):
    """Banded timber crate on skids, with the three-bar mark on its long sides."""
    sx, sy, sz = size
    cx, cy, cz = center
    bottom, top = cy - sy / 2, cy + sy / 2
    skid, lid = 0.3, 0.22
    wall = sy - skid - lid
    middle = bottom + skid + wall / 2

    parts = [
        ("Timber", box((cx, bottom + skid + (wall + lid / 2) / 2, cz), (sx - 0.2, wall + lid / 2, sz - 0.2))),
        ("Timber", box((cx, top - lid / 2, cz), (sx, lid, sz))),
    ]
    for dx in (-(sx / 2 - 0.5), 0.0, sx / 2 - 0.5):
        parts.append(("Dark", box((cx + dx, bottom + skid / 2, cz), (0.6, skid, sz))))
    for dx in (-sx * 0.3, sx * 0.3):
        parts.append(("Steel", box((cx + dx, middle, cz), (0.3, wall, sz))))
    for dx in (-0.45, 0.0, 0.45):
        parts.append(("Accent", box((cx + dx, middle, cz), (0.25, min(1.2, wall * 0.45), sz - 0.12))))
    return parts


def crate_stack():
    return crate((6.0, 3.6, 6.0), (0, -1.7, 0)) + crate((5.7, 3.4, 5.7), (0, 1.8, 0))


def container():
    """Short freight box: corrugated sides, doors on the +X end."""
    length, height, width = 8.0, 7.0, 4.0
    edge = 0.15
    parts = [("Oxide", box((0, 0, 0), (length - 0.3, height - 0.3, width - 0.3)))]
    for sx in (-1, 1):
        for sz in (-1, 1):
            parts.append(("Steel", box((sx * (length / 2 - edge), 0, sz * (width / 2 - edge)), (0.3, height, 0.3))))
    for sy in (-1, 1):
        for sz in (-1, 1):
            parts.append(("Steel", box((0, sy * (height / 2 - edge), sz * (width / 2 - edge)), (length, 0.3, 0.3))))
        for sx in (-1, 1):
            parts.append(("Steel", box((sx * (length / 2 - edge), sy * (height / 2 - edge), 0), (0.3, 0.3, width))))
    # Each rib passes through the body, so it shows on both sides and the roof.
    for index in range(14):
        parts.append(("Oxide", box((-3.25 + index * 0.5, 0, 0), (0.25, height - 0.14, width - 0.1))))
    for z in (-0.9, 0.9):
        parts.append(("Oxide", box((length / 2 - 0.1, 0, z), (0.12, height - 0.8, 1.6))))
    for z in (-1.45, -0.35, 0.35, 1.45):
        parts.append(("Bare", cylinder((3.94, -3.0, z), (3.94, 3.0, z), 0.05, segments=6)))
    for z in (-0.6, 0.6):
        parts.append(("Accent", box((3.95, -0.3, z), (0.1, 0.12, 0.5))))
    parts.append(("Dark", box((0, 1.2, 0), (2.0, 1.4, width - 0.04))))
    for dx in (-0.5, 0.0, 0.5):
        parts.append(("Accent", box((dx, 1.2, 0), (0.3, 0.9, width))))
    return parts


def barrier():
    """Two cast concrete road barriers pinned end to end."""
    profile = [(-1.5, -2), (1.5, -2), (1.5, -1.2), (1.15, -0.6), (1.1, 2), (-1.1, 2), (-1.15, -0.6), (-1.5, -1.2)]
    parts = [("Steel", box((0, 0, 0), (0.3, 2.4, 1.6)))]
    for cx in (-2.525, 2.525):
        parts.append(("Concrete", extrude(profile, 4.95, 0.12, x=cx)))
        for dx in (-0.6, 0.0, 0.6):
            parts.append(("Accent", box((cx + dx, 0.9, 0), (0.35, 1.0, 2.3))))
    return parts


def pallet(cx, bottom, cz, sx, sz):
    parts = [("Timber", box((cx, bottom + 0.44, cz), (sx, 0.12, sz)))]
    for dx in (-(sx / 2 - 0.3), 0.0, sx / 2 - 0.3):
        parts.append(("Timber", box((cx + dx, bottom + 0.05, cz), (0.6, 0.1, sz))))
    for dz in (-(sz / 2 - 0.2), 0.0, sz / 2 - 0.2):
        parts.append(("Timber", box((cx, bottom + 0.24, cz + dz), (sx, 0.28, 0.4))))
    return parts


def pallet_load():
    """Two loaded pallets: one wrapped and strapped, one with stacked crates."""
    left, right = -2.025, 2.025
    parts = pallet(left, -2.5, 0, 3.95, 4.0) + pallet(right, -2.5, 0, 3.95, 4.0)
    parts.append(("Wrap", box((left, 0.22, 0), (3.7, 4.44, 3.8))))
    for dx in (-1.1, 1.1):
        parts.append(("Dark", box((left + dx, 0.25, 0), (0.25, 4.5, 3.86))))
    for dx in (-0.45, 0.0, 0.45):
        parts.append(("Accent", box((left + dx, 0.6, 0), (0.25, 1.0, 3.9))))
    parts += crate((3.8, 2.25, 3.8), (right, -0.875, 0))
    parts += crate((3.8, 2.25, 3.8), (right, 1.375, 0))
    return parts


def screen():
    """Welded sheet-steel partition between three posts."""
    parts = []
    for x in (-4.75, 0.0, 4.75):
        parts.append(("Dark", box((x, 0, 0), (0.5, 5.0, 1.0))))
    for x in (-2.375, 2.375):
        parts.append(("Steel", box((x, 0.1, 0), (4.25, 4.4, 0.6))))
    for y in (-1.4, 1.6):
        parts.append(("Bare", box((0, y, 0), (9.5, 0.25, 0.8))))
    for dx in (-0.5, 0.0, 0.5):
        parts.append(("Accent", box((-2.375 + dx, 0.1, 0), (0.3, 1.0, 0.66))))
    return parts


def lamp_head():
    """Floodlight on a short arm. The collar at -X sits on a post or bracket."""
    return [
        ("Steel", box((-0.95, 0, 0), (0.5, 0.9, 0.5))),
        ("Dark", box((-0.2, 0.2, 0), (1.2, 0.16, 0.2))),
        ("Dark", box((0.55, 0.1, 0), (1.3, 0.5, 1.0))),
        ("Glow", box((0.55, -0.19, 0), (1.1, 0.1, 0.8))),
    ]


# name -> (builder, size of the box it fills). Names are used by the `prop`
# field of map layouts in src/server/Maps.
PROPS = {
    "Crate": (lambda: crate((6.0, 4.0, 4.0)), (6.0, 4.0, 4.0)),
    "CrateStack": (crate_stack, (6.0, 7.0, 6.0)),
    "Container": (container, (8.0, 7.0, 4.0)),
    "Barrier": (barrier, (10.0, 4.0, 3.0)),
    "PalletLoad": (pallet_load, (8.0, 5.0, 4.0)),
    "Screen": (screen, (10.0, 5.0, 1.0)),
    "LampHead": (lamp_head, (2.4, 0.9, 1.0)),
}
