"""A military fighting knife of the classic pattern: clip-point blade with a
fuller, steel crossguard, a handle of stacked leather washers and a flat steel
pommel. An original design; dimensions are typical of the type. Overall 300
mm, blade 178 mm.

Laid out like the guns so the same tools fit it: the handle lies on the Y
axis, the blade points toward +Y, the edge faces down. Millimetres, +Z up,
+X right. `MUZZLE` is the tip.
"""

NAME = "CombatKnife"
STUDS_PER_METRE = 5.5
GRIP = (0, -58, 0)
MUZZLE = (0, 178, -3)


def build(g):
    blade = g.part("Blade", "Bare")
    guard = g.part("Guard", "Steel")
    handle = g.part("Handle", "Wood")
    pommel = g.part("Pommel", "Steel")

    # --- blade: full thickness at the spine, ground to nothing at the edge ----
    b = g.slab(blade, [(0, 15), (118, 15), (150, 9), (178, -3), (164, -11), (140, -15.5), (0, -16)], 4.4, bevel=0.5)
    g.taper(b, 2, [(-16, 0.08), (-4, 1.0)])
    for sign in (1, -1):  # the fuller
        g.cut(b, g.cutter("box", (sign * 2.3, 62, 7), (1.6, 96, 5)))
    g.slab(blade, [(-6, 9), (2, 9), (2, -9), (-6, -9)], 5.2, bevel=0.6)  # ricasso, under the guard

    g.box(guard, (0, -3.5, 0), (10, 7, 48), bevel=2.2, segments=3)

    # --- handle: an oval of leather washers, grooved for grip --------------------
    profile = [(0, 0), (0, 11.5)]
    for k in range(6):
        y = 3 + k * 17
        swell = 12.2 + 2.2 * (1 - abs(k - 2.5) / 2.5)
        profile += [(y, swell - 1.3), (y + 2, swell), (y + 13, swell), (y + 15, swell - 1.3)]
    profile += [(104, 11.5), (104, 0)]
    h = g.lathe(handle, profile, (0, -111, 0), segments=28)
    g.taper(h, 1, [(-200, 0.78), (200, 0.78)])

    p = g.lathe(pommel, [(0, 0), (0, 11), (2, 13.5), (9, 13.5), (11, 11.5), (11, 0)], (0, -122, 0), segments=28, bevel=0.6)
    g.taper(p, 1, [(-200, 0.8), (200, 0.8)])
    g.tube(pommel, (0, -126, 0), (0, -122, 0), 4, segments=12)  # the peened tang

    return GRIP, MUZZLE
