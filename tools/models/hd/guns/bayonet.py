"""A modern knife bayonet: clip-point blade with a saw along the spine, a
fuller and a wire-cutter hole, a crossguard carrying the muzzle ring, a ribbed
polymer handle and a latch pommel. An original design; dimensions are typical
of the type. Overall 305 mm, blade 182 mm.

The handle lies on the Y axis, the blade points toward +Y, the edge faces
down. Millimetres, +Z up, +X right. `MUZZLE` is the tip.
"""

NAME = "Bayonet"
STUDS_PER_METRE = 5.5
GRIP = (0, -60, 0)
MUZZLE = (0, 182, -2)


def build(g):
    blade = g.part("Blade", "Bare")
    guard = g.part("Guard", "Steel")
    handle = g.part("Handle", "Olive")
    pommel = g.part("Pommel", "Steel")
    latch = g.part("Latch", "Steel", group="Latch")

    # --- blade ---------------------------------------------------------------
    b = g.slab(blade, [(0, 17), (112, 17), (150, 10), (182, -2), (166, -12), (140, -17), (0, -17)], 5.6, bevel=0.5)
    g.taper(b, 2, [(-17, 0.08), (-5, 1.0)])
    for k in range(9):  # saw teeth cut into the spine
        y = 28 + k * 8.5
        g.cut(b, g.cutter("slab", [(y, 19), (y + 6.5, 19), (y + 1.5, 12.5)], 10))
    for sign in (1, -1):  # fuller
        g.cut(b, g.cutter("box", (sign * 2.9, 66, 3), (1.8, 86, 5)))
    g.cut(b, g.cutter("tube", (-5, 146, -3), (5, 146, -3), 4.2, segments=16))  # wire-cutter hole

    # --- guard, with the ring that goes over the muzzle ---------------------------
    g.box(guard, (0, -4, -2), (9, 8, 50), bevel=2, segments=3)
    ring = g.tube(guard, (0, -8, 36), (0, 0, 36), 15, segments=32, bevel=0.8)
    g.cut(ring, g.cutter("tube", (0, -10, 36), (0, 2, 36), 11.2, segments=24))

    # --- handle: round, with grip ribs ---------------------------------------------
    profile = [(0, 0), (0, 13.5)]
    for k in range(8):
        y = 4 + k * 12.5
        profile += [(y, 13.5), (y + 1.5, 15.2), (y + 8, 15.2), (y + 9.5, 13.5)]
    profile += [(104, 13.5), (104, 0)]
    g.lathe(handle, profile, (0, -112, 0), segments=28)

    # --- pommel, with the catch that locks it to the rifle -----------------------
    p = g.box(pommel, (0, -120, 0), (27, 16, 34), bevel=3, segments=3)
    g.cut(p, g.cutter("box", (0, -124, 13), (9, 12, 12)))  # the slot the bayonet lug slides into
    for sign in (1, -1):
        g.tube(latch, (sign * 12, -120, -6), (sign * 16.5, -120, -6), 5, segments=16, bevel=0.6)

    return GRIP, MUZZLE
