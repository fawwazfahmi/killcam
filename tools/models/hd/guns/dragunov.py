"""Dragunov SVD, modelled from published dimensions.

Semi-automatic. Skeleton thumbhole stock with cheek pad, vented wooden
handguard, long slotted flash hider, PSO-1 style scope on a left-side mount,
10-round magazine. Overall 1225 mm, barrel 620 mm. Millimetres, bore on the Y
axis, +Y toward the muzzle, +Z up, +X right.
"""

import math

from kit import arc, scope

NAME = "Dragunov"
STUDS_PER_METRE = 5.5
GRIP = (0, -104, -92)
MUZZLE = (0, 805, 0)


def build(g):
    receiver = g.part("Receiver", "Steel")
    cover = g.part("DustCover", "Steel")
    barrel = g.part("Barrel", "Steel")
    fittings = g.part("Fittings", "Steel")
    stock = g.part("Stock", "Wood")
    pad = g.part("ButtPlate", "Polymer")
    handguard = g.part("Handguard", "Wood")
    optic = g.part("Scope", "Steel")
    guard = g.part("TriggerGuard", "Steel")
    trigger = g.part("Trigger", "Steel", group="Trigger")
    selector = g.part("Selector", "Steel", group="Selector")
    magazine = g.part("Magazine", "Steel", group="Magazine")
    bolt = g.part("Bolt", "Bare", group="Bolt")

    # --- receiver (long Kalashnikov pattern) -----------------------------
    body = g.slab(receiver, [(-122, 8), (150, 8), (150, -42), (-60, -42), (-122, -32)], 30, bevel=1.2)
    g.cut(body, g.cutter("box", (14, 60, 0), (14, 80, 14)))
    for y, z in [(132, -8), (140, -28), (-108, -8), (-104, -24), (-26, -28)]:
        g.tube(receiver, (-15.6, y, z), (15.6, y, z), 2.3, segments=10)
    g.slab(cover, [(-128, 8), (-128, 20), (-124, 26), (144, 26), (150, 18), (150, 8)], 31, bevel=5, segments=4)
    g.tube(cover, (0, -134, 16), (0, -124, 16), 4.2, segments=14, bevel=0.8)

    # --- barrel, gas block, front sight, flash hider ---------------------
    g.lathe(barrel, [(0, 0), (0, 13), (40, 13), (42, 11), (300, 10), (610, 8.5), (610, 0)], (0, 150, 0))
    hider = g.lathe(barrel, [(0, 0), (0, 9), (4, 12), (44, 12), (46, 10.5), (46, 0)], (0, 759, 0), segments=28)
    g.cut(hider, g.cutter("tube", (0, 750, 0), (0, 810, 0), 6, segments=16))
    for angle in range(0, 360, 72):
        a = math.radians(angle + 90)
        g.cut(hider, g.cutter("box", (math.cos(a) * 12, 784, math.sin(a) * 12), (5, 34, 5)))
    g.slab(fittings, [(400, -14), (400, 40), (444, 40), (452, 22), (452, -14)], 22, bevel=3)
    g.tube(fittings, (0, 150, 30), (0, 404, 30), 8, segments=18)
    g.slab(fittings, [(700, -12), (700, 40), (722, 40), (722, -12)], 18, bevel=2)
    for sign in (1, -1):
        g.slab(fittings, [(704, 30), (704, 50), (712, 54), (720, 50), (720, 30)], 3, x=sign * 8, bevel=0.8)
    g.tube(fittings, (0, 712, 36), (0, 712, 50), 1.5, segments=8)
    g.slab(fittings, [(150, -38), (150, 40), (158, 40), (158, -38)], 42, bevel=2)

    # --- vented wooden handguard -----------------------------------------
    hg = g.slab(handguard, [(160, -30), (160, 30), (170, 38), (388, 38), (398, 30), (398, -30), (388, -38),
                            (170, -38)], 42, bevel=11, segments=4)
    for y in range(190, 380, 30):
        g.cut(hg, g.cutter("box", (0, y, 4), (60, 9, 34)))

    # --- skeleton thumbhole stock -----------------------------------------
    s = g.slab(stock, [(-120, 10), (-120, -40), (-64, -44), (-82, -150), (-122, -158), (-410, -150),
                       (-428, -140), (-428, -18), (-416, -8), (-200, 4), (-132, 12)], 36, bevel=8, segments=3)
    g.taper(s, 1, [(-428, 1.0), (-120, 0.82)])
    g.cut(s, g.cutter("slab", [(-150, -24), (-370, -30), (-392, -44), (-392, -112), (-372, -126),
                                (-160, -126), (-142, -112), (-132, -62)], 60))
    g.slab(stock, [(-205, 4), (-335, -4), (-335, 16), (-212, 22)], 32, bevel=7, segments=3)  # cheek pad
    g.slab(pad, [(-428, -16), (-428, -142), (-438, -144), (-438, -14)], 38, bevel=3)

    # --- controls ---------------------------------------------------------
    tg = g.slab(guard, [(-66, -40), (-60, -58), (-48, -76), (-40, -80), (12, -80), (18, -74), (18, -40)], 10, bevel=1.5)
    g.cut(tg, g.cutter("slab", [(-54, -30), (-52, -56), (-42, -71), (8, -71), (12, -66), (12, -30)], 14))
    g.slab(trigger, [(-16, -42), (-8, -42), (-12, -58), (-22, -70), (-28, -69), (-20, -56)], 6, bevel=1.2)
    g.slab(selector, [(-110, -16), (-106, -4), (4, -4), (14, -8), (18, -22), (10, -24), (4, -14), (-102, -18)],
           2.4, x=16.2, bevel=0.8)
    g.tube(selector, (14.5, -106, -10), (18, -106, -10), 5.2, segments=16, bevel=0.6)
    g.box(bolt, (0, 60, 0), (22, 92, 14), bevel=1)
    g.tube(bolt, (10, 106, 2), (30, 106, 4), 4.2, segments=12)
    g.lathe(bolt, [(0, 0), (0, 7), (5, 7.6), (9, 6.4), (10.5, 0)], (28, 106, 3.8), direction=(1, 0, 0.1), segments=18)

    # --- PSO-1 style scope on a left-side rail ---------------------------
    g.slab(optic, [(-40, -20), (110, -20), (110, 10), (-40, 10)], 6, x=-18, bevel=1)  # side rail
    g.slab(optic, [(-20, -10), (90, -10), (90, 62), (-20, 62)], 10, x=-24, bevel=2)  # mount plate
    scope(g, optic, -95, 205, 76, x=-8, tube=13, objective=19, eyepiece=18, mounts=(0, 70), base=60, mount_x=-24)
    g.lathe(optic, [(0, 0), (0, 22), (40, 22), (40, 0)], (-8, -135, 76), segments=24)  # rubber eyecup

    # --- magazine: 10-round -------------------------------------------
    centre = arc((60, -26), 1200, 132, 10)
    g.sweep(magazine, centre, lambda t: 34 - 2 * t, 24, bevel=2.5)
    g.sweep(magazine, centre[2:-2], lambda t: 6, 26, bevel=1)
    g.sweep(magazine, centre[-2:], lambda t: 36, 27, bevel=2.5)

    return GRIP, MUZZLE
