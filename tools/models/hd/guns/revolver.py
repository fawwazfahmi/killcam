"""A six-shot double-action revolver with a four-inch barrel, in the manner of
the .357 service revolvers. An original design; dimensions are typical of the
type rather than taken from one gun.

Stainless frame open round a fluted cylinder, barrel with a full underlug and
a ribbed top, ramp front sight, spur hammer, rounded trigger guard and wooden
combat grips. Overall 240 mm, barrel 102 mm. Millimetres, bore on the Y axis,
+Y toward the muzzle, +Z up, +X right.
"""

import math

NAME = "Revolver"
STUDS_PER_METRE = 5.5
GRIP = (0, -64, -80)
MUZZLE = (0, 134, 0)

AXIS = -13  # the cylinder turns about a line this far below the bore
CHAMBER = 13  # distance from that line to the middle of each chamber


def build(g):
    frame = g.part("Frame", "Bare")
    barrel = g.part("Barrel", "Bare")
    sights = g.part("Sights", "Steel")
    cylinder = g.part("Cylinder", "Bare", group="Cylinder")
    hammer = g.part("Hammer", "Bare", group="Hammer")
    trigger = g.part("Trigger", "Bare", group="Trigger")
    latch = g.part("Latch", "Bare", group="Latch")
    grips = g.part("Grip", "Wood")

    # --- frame, with the window the cylinder sits in --------------------------
    f = g.slab(frame, [(-48, 12), (32, 12), (32, -37), (16, -42), (-26, -42), (-34, -36), (-54, -30), (-60, -8),
                       (-54, 6)], 17, bevel=2)
    g.cut(f, g.cutter("box", (0, -1, AXIS), (40, 44, 42)))
    g.box(frame, (0, -30, AXIS), (33, 14, 36), bevel=3, segments=3)  # recoil shield behind the cylinder
    guard = g.slab(frame, [(-32, -40), (16, -40), (23, -49), (21, -65), (9, -75), (-32, -75), (-38, -66)], 12, bevel=2.4)
    g.cut(guard, g.cutter("slab", [(-27, -46), (13, -46), (17, -51), (15.5, -63), (6.5, -69.5), (-31, -69.5)], 20))

    # --- cylinder: six chambers, six flutes ------------------------------------
    c = g.lathe(cylinder, [(0, 0), (0, 18.4), (1.4, 19.6), (40.6, 19.6), (42, 18.4), (42, 0)], (0, -22, AXIS), segments=48)
    for k in range(6):
        a = math.radians(60 * k)
        g.cut(c, g.cutter("tube", (CHAMBER * math.sin(a), 12, AXIS + CHAMBER * math.cos(a)),
                          (CHAMBER * math.sin(a), 24, AXIS + CHAMBER * math.cos(a)), 4.7, segments=14))
        a += math.radians(30)
        g.cut(c, g.cutter("tube", (22.4 * math.sin(a), -2, AXIS + 22.4 * math.cos(a)),
                          (22.4 * math.sin(a), 24, AXIS + 22.4 * math.cos(a)), 5.6, segments=14))
    g.tube(cylinder, (0, 20, AXIS), (0, 30, AXIS), 3.2, segments=14)  # crane pin

    # --- barrel: round, with a rib above and a full lug below ---------------------
    b = g.tube(barrel, (0, 28, 0), (0, 134, 0), 9, segments=28)
    g.cut(b, g.cutter("tube", (0, 110, 0), (0, 138, 0), 4.6, segments=18))
    g.slab(barrel, [(30, -4), (134, -4), (134, -20), (128, -25), (30, -25)], 14, bevel=3, segments=3)
    g.slab(barrel, [(24, 7), (134, 7), (134, 12.5), (24, 13.5)], 8.5, bevel=1)
    for k in range(9):  # vents in the rib
        g.box(barrel, (0, 40 + k * 9, 10.2), (9.4, 4.4, 2.6), bevel=0.4, segments=1)
    g.slab(sights, [(110, 12.5), (132, 12.5), (132, 14), (120, 22)], 4, bevel=0.5)
    rear = g.slab(sights, [(-48, 12), (-34, 12), (-34, 16), (-48, 17)], 12, bevel=0.8)
    g.cut(rear, g.cutter("box", (0, -44, 16.5), (3.6, 18, 4)))

    # --- hammer, trigger, cylinder latch ---------------------------------------------
    g.slab(hammer, [(-58, -4), (-50, -4), (-46, 12), (-52, 18), (-64, 23), (-67, 19), (-57, 11)], 7.5, bevel=1.4)
    g.slab(trigger, [(-6, -42), (2, -42), (3, -54), (-2, -65), (-7, -64), (-3, -54)], 7, bevel=1.4)
    g.slab(latch, [(-46, -2), (-32, -2), (-30, -9), (-44, -11)], 3, x=-9.8, bevel=0.9)

    # --- grips ------------------------------------------------------------------
    w = g.slab(grips, [(-64, -6), (-54, -28), (-38, -42), (-38, -72), (-45, -100), (-49, -124), (-93, -113),
                       (-87, -78), (-77, -42), (-72, -20)], 30, bevel=7, segments=3)
    g.taper(w, 2, [(-124, 1.0), (-70, 1.0), (-10, 0.6)])
    g.tube(frame, (-16.4, -66, -74), (16.4, -66, -74), 3.4, segments=14)  # grip screw

    return GRIP, MUZZLE
