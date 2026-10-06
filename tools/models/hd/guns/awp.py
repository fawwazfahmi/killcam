"""Arctic Warfare (the "AWP"), modelled from published dimensions.

Bolt-action: green thumbhole stock on an aluminium chassis, heavy barrel with
a muzzle brake, large scope, 10-round magazine, adjustable cheek piece, folded
bipod and rear monopod. Overall 1230 mm, barrel 660 mm. Millimetres, bore on
the Y axis, +Y toward the muzzle, +Z up, +X right.
"""

import math

from kit import rail, scope

NAME = "AWP"
STUDS_PER_METRE = 5.5
GRIP = (0, -84, -104)
MUZZLE = (0, 760, 0)


def build(g):
    receiver = g.part("Receiver", "Steel")
    rails = g.part("Rail", "Steel")
    barrel = g.part("Barrel", "Steel")
    stock = g.part("Stock", "Olive")
    pad = g.part("ButtPad", "Polymer")
    bipod = g.part("Bipod", "Steel")
    optic = g.part("Scope", "Polymer")
    guard = g.part("TriggerGuard", "Steel")
    trigger = g.part("Trigger", "Steel", group="Trigger")
    magazine = g.part("Magazine", "Steel", group="Magazine")
    bolt = g.part("Bolt", "Steel", group="Bolt")

    # --- receiver and barrel ---------------------------------------------
    rec = g.slab(receiver, [(-112, -18), (150, -18), (150, 20), (-112, 20)], 36, bevel=3)
    g.cut(rec, g.cutter("box", (16, -20, 6), (12, 90, 16)))
    rail(g, rails, -112, 160, (0, 20))
    g.lathe(barrel, [(0, 0), (0, 16), (60, 16), (64, 14), (560, 11.5), (560, 0)], (0, 150, 0), segments=28)
    for k in range(6):  # flutes
        a = math.radians(k * 60)
        g.cut(g.shapes[-1][0], g.cutter("box", (math.cos(a) * 14.2, 420, math.sin(a) * 14.2), (5, 360, 5)))
    brake = g.lathe(barrel, [(0, 0), (0, 15), (50, 15), (52, 13), (52, 0)], (0, 708, 0), segments=28)
    g.cut(brake, g.cutter("tube", (0, 700, 0), (0, 770, 0), 6, segments=16))
    for y in (722, 740):
        g.cut(brake, g.cutter("box", (0, y, 0), (40, 10, 14)))

    # --- thumbhole stock --------------------------------------------------
    s = g.slab(stock, [(440, -10), (440, -44), (418, -62), (150, -66), (24, -66), (-40, -66), (-58, -150),
                       (-112, -156), (-124, -104), (-440, -142), (-462, -148), (-472, -138), (-472, 0),
                       (-460, 10), (-200, 14), (-118, 4), (-100, -10), (150, -10)], 52, bevel=7, segments=3)
    g.taper(s, 1, [(-472, 0.92), (-130, 0.82), (100, 1.0), (440, 0.88)])
    g.cut(s, g.cutter("slab", [(-138, -14), (-300, -6), (-330, -26), (-318, -84), (-150, -94), (-132, -76)], 70))
    g.slab(stock, [(-220, 14), (-420, 14), (-418, 30), (-226, 32)], 44, bevel=6, segments=3)  # cheek piece
    for y in (-250, -390):
        g.tube(rails, (0, y, 0), (0, y, 16), 4, segments=12)
    g.slab(pad, [(-472, 6), (-472, -140), (-488, -142), (-488, 8)], 48, bevel=5, segments=3)
    g.tube(bipod, (0, -400, -130), (0, -400, -176), 6, segments=14)  # rear monopod
    g.lathe(bipod, [(0, 0), (0, 12), (8, 12), (8, 0)], (0, -400, -184), direction=(0, 0, 1), segments=18)

    # --- bipod folded forward under the forend --------------------------
    g.box(bipod, (0, 400, -74), (34, 30, 16), bevel=3)
    for sign in (1, -1):
        g.tube(bipod, (sign * 11, 400, -80), (sign * 11, 520, -82), 5, segments=12)
        g.tube(bipod, (sign * 11, 520, -82), (sign * 11, 532, -82), 7, segments=12)

    # --- controls and magazine ------------------------------------------
    tg = g.slab(guard, [(-44, -60), (-40, -82), (-32, -90), (18, -90), (24, -82), (24, -60)], 12, bevel=2)
    g.cut(tg, g.cutter("slab", [(-36, -50), (-34, -80), (14, -80), (16, -72), (16, -50)], 16))
    g.slab(trigger, [(-14, -62), (-6, -62), (-10, -74), (-18, -84), (-23, -82), (-16, -70)], 6, bevel=1.2)
    g.slab(magazine, [(34, -40), (102, -40), (102, -98), (34, -98)], 30, bevel=3)
    g.slab(magazine, [(30, -96), (106, -96), (106, -104), (30, -104)], 33, bevel=2)

    g.lathe(bolt, [(0, 0), (0, 15), (26, 15), (34, 10), (34, 0)], (0, -146, 2), segments=24)
    g.tube(bolt, (16, -98, 4), (46, -98, 0), 4.5, segments=12)
    g.lathe(bolt, [(0, 0), (0, 10), (4, 13), (18, 13), (22, 0)], (44, -98, 0), direction=(1, 0, -0.1), segments=20)

    # --- scope ---------------------------------------------------------------
    scope(g, optic, -150, 300, 66, tube=16, objective=27, eyepiece=22, mounts=(-60, 150), base=28)

    return GRIP, MUZZLE
