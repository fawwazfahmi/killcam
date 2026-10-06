"""AK-47 (Type 3 milled receiver pattern), modelled from published dimensions.

Overall 880 mm, barrel 415 mm, 30-round curved steel magazine, wooden stock,
grip and handguards, thread protector at the muzzle. Millimetres, bore on the
Y axis, +Y toward the muzzle, +Z up, +X the right-hand side.
"""

import math

NAME = "AK47"
STUDS_PER_METRE = 5.5
GRIP = (0, -96, -100)  # where the firing hand holds the pistol grip
MUZZLE = (0, 534, 0)


def build(g):
    receiver = g.part("Receiver", "Steel")
    cover = g.part("DustCover", "Steel")
    barrel = g.part("Barrel", "Steel")
    fittings = g.part("Fittings", "Steel")
    front = g.part("FrontSight", "Steel")
    rear = g.part("RearSight", "Steel")
    stock = g.part("Stock", "Wood")
    buttplate = g.part("ButtPlate", "Steel")
    grip = g.part("Grip", "Wood")
    upper = g.part("UpperHandguard", "Wood")
    lower = g.part("LowerHandguard", "Wood")
    rod = g.part("CleaningRod", "Bare")
    guard = g.part("TriggerGuard", "Steel")
    trigger = g.part("Trigger", "Steel", group="Trigger")
    selector = g.part("Selector", "Steel", group="Selector")
    magazine = g.part("Magazine", "Steel", group="Magazine")
    bolt = g.part("Bolt", "Bare", group="Bolt")

    # --- receiver ---------------------------------------------------------
    body = g.slab(receiver, [(-122, 8), (152, 8), (152, -45), (-70, -45), (-100, -41), (-122, -30)], 30, bevel=1.2)
    # Ejection port and charging slot on the right, under the dust cover.
    g.cut(body, g.cutter("box", (14, 60, 0), (14, 84, 14)))
    g.cut(body, g.cutter("box", (14, 112, 2), (14, 30, 7)))
    # Milled lightening cut above the magazine well, both sides.
    for sign in (1, -1):
        g.cut(body, g.cutter("slab", [(18, -14), (96, -14), (102, -24), (96, -36), (18, -36)], 4, x=sign * 15.6))
    # Rivets and pins.
    for y, z in [(128, -8), (140, -30), (118, -34), (-110, -6), (-106, -24), (-30, -30), (-6, -34)]:
        g.tube(receiver, (-15.6, y, z), (15.6, y, z), 2.3, segments=10)

    g.slab(cover, [(-128, 8), (-128, 20), (-124, 26), (120, 26), (126, 18), (126, 8)], 31, bevel=5, segments=4)
    g.tube(cover, (0, -134, 16), (0, -124, 16), 4.2, segments=14, bevel=0.8)

    # --- barrel, gas system and sights -----------------------------------
    g.lathe(barrel, [(0, 0), (0, 13), (62, 13), (64, 11), (190, 11), (192, 10), (362, 10), (362, 0)], (0, 150, 0))
    muzzle = g.lathe(barrel, [(0, 0), (0, 11.5), (21, 11.5), (24, 9.5), (24, 0)], (0, 510, 0), segments=28)
    g.cut(muzzle, g.cutter("tube", (0, 500, 0), (0, 540, 0), 4.2, segments=16))
    for k in range(10):  # grip knurling on the thread protector
        y = 513 + k * 1.8
        g.tube(barrel, (0, y, 0), (0, y + 0.9, 0), 11.9, segments=28)

    g.tube(fittings, (0, 205, 32), (0, 352, 32), 9, segments=20)
    g.slab(fittings, [(344, -13), (344, 44), (366, 44), (390, 8), (390, -13)], 22, bevel=3)
    g.slab(fittings, [(330, -44), (330, 12), (344, 12), (344, -44)], 40, bevel=2.5)
    g.slab(fittings, [(147, -46), (147, 10), (156, 10), (156, -46)], 44, bevel=2)
    g.slab(fittings, [(-118, 4), (-118, 10), (-150, 6), (-150, 1)], 12, bevel=1)
    g.slab(fittings, [(-100, -44), (-142, -60), (-142, -53), (-100, -38)], 12, bevel=1)

    g.slab(rear, [(150, -14), (150, 22), (160, 30), (206, 30), (212, 14), (206, -14)], 26, bevel=2)
    leaf = g.slab(rear, [(165, 30), (165, 35), (214, 38.5), (214, 33.5)], 16, bevel=0.8)
    g.cut(leaf, g.cutter("box", (0, 166, 36), (3, 8, 8)))
    g.box(rear, (0, 192, 37.5), (18, 10, 6), bevel=1)
    g.slab(rear, [(196, 6), (211, 6), (213, 20), (198, 22)], 3, x=13.5, bevel=0.6)

    g.slab(front, [(470, -26), (470, 12), (478, 18), (480, 46), (500, 46), (502, 18), (512, 10), (512, -26)], 22, bevel=2.5)
    g.box(front, (0, 460, -28), (10, 24, 8), bevel=1.2)
    for sign in (1, -1):
        g.slab(front, [(476, 40), (476, 60), (484, 64), (494, 61), (494, 40)], 3, x=sign * 9.5, bevel=0.8)
    g.tube(front, (0, 485, 44), (0, 485, 58), 1.6, segments=8)

    g.tube(rod, (0, 180, -17), (0, 500, -17), 3.2, segments=12)
    g.lathe(rod, [(0, 0), (0, 4.6), (12, 4.6), (12, 0)], (0, 488, -17), segments=14)

    # --- furniture ----------------------------------------------------------
    s = g.slab(stock, [(-118, 6), (-118, -38), (-132, -48), (-240, -102), (-345, -154), (-345, -36), (-128, 6)], 36, bevel=10, segments=4)
    g.taper(s, 1, [(-345, 1.0), (-180, 0.86), (-118, 0.76)])
    g.slab(buttplate, [(-345, -36), (-345, -154), (-353, -155), (-353, -34)], 37, bevel=2)

    gr = g.slab(grip, [(-56, -38), (-102, -38), (-110, -62), (-136, -148), (-134, -156), (-124, -160),
                       (-100, -160), (-92, -152), (-70, -80), (-60, -58)], 28, bevel=8, segments=4)
    g.taper(gr, 2, [(-160, 1.08), (-90, 1.0), (-40, 0.9)])

    up = g.slab(upper, [(212, 18), (212, 38), (220, 46), (318, 46), (326, 40), (328, 18)], 30, bevel=11, segments=4)
    g.taper(up, 1, [(212, 1.0), (328, 0.92)])
    lo = g.slab(lower, [(156, 4), (156, -42), (170, -48), (225, -50), (255, -46), (290, -48), (318, -45),
                        (330, -36), (330, 4)], 46, bevel=12, segments=4)
    g.taper(lo, 1, [(156, 1.0), (330, 0.9)])

    # --- controls ---------------------------------------------------------
    tg = g.slab(guard, [(-62, -40), (-58, -58), (-48, -76), (-40, -80), (12, -80), (18, -74), (18, -40)], 10, bevel=1.5)
    g.cut(tg, g.cutter("slab", [(-52, -30), (-50, -56), (-42, -71), (8, -71), (12, -66), (12, -30)], 14))
    g.slab(guard, [(13, -44), (23, -44), (25, -70), (19, -75), (14, -66)], 14, bevel=1.2)

    g.slab(trigger, [(-14, -42), (-6, -42), (-10, -58), (-20, -70), (-26, -69), (-18, -56)], 6, bevel=1.2)

    g.slab(selector, [(-108, -16), (-104, -4), (4, -4), (14, -8), (18, -22), (10, -24), (4, -14), (-100, -18)],
           2.4, x=16.2, bevel=0.8)
    g.tube(selector, (14.5, -104, -10), (18, -104, -10), 5.2, segments=16, bevel=0.6)

    g.box(bolt, (0, 62, 0), (22, 96, 14), bevel=1)
    g.tube(bolt, (10, 108, 2), (30, 108, 4), 4.2, segments=12)
    g.lathe(bolt, [(0, 0), (0, 7), (5, 7.6), (9, 6.4), (10.5, 0)], (28, 108, 3.8), direction=(1, 0, 0.1), segments=18)

    # --- magazine: 30-round, steel, ribbed --------------------------------
    radius, top, length, steps = 360, (57, -24), 236, 24
    span = length / radius
    centre = [
        (top[0] + radius * (1 - math.cos(span * i / steps)), top[1] - radius * math.sin(span * i / steps))
        for i in range(steps + 1)
    ]
    g.sweep(magazine, centre, lambda t: 33 - 3.5 * t, 28, bevel=2.5)
    g.sweep(magazine, centre[3:-3], lambda t: 5.5, 30.6, bevel=1.2)  # stamped side rib
    g.sweep(magazine, centre[-2:], lambda t: 33, 31, bevel=2)  # floor plate
    g.box(magazine, (0, 92, -38), (10, 8, 10), bevel=1)  # front locking lug

    return GRIP, MUZZLE
