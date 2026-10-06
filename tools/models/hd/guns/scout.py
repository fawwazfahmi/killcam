"""Steyr Scout, modelled from published dimensions.

Light bolt-action: slim synthetic stock with a semi-pistol grip, round
receiver with a long top rail, forward-mounted long-eye-relief scope, short
detachable magazine. Overall 990 mm, barrel 508 mm. Millimetres, bore on the Y
axis, +Y toward the muzzle, +Z up, +X right.
"""

from kit import rail, scope

NAME = "Scout"
STUDS_PER_METRE = 5.5
GRIP = (0, -92, -84)
MUZZLE = (0, 600, 0)


def build(g):
    receiver = g.part("Receiver", "Steel")
    rails = g.part("Rail", "Steel")
    barrel = g.part("Barrel", "Steel")
    stock = g.part("Stock", "Polymer")
    pad = g.part("ButtPad", "Polymer")
    optic = g.part("Scope", "Steel")
    guard = g.part("TriggerGuard", "Steel")
    trigger = g.part("Trigger", "Steel", group="Trigger")
    magazine = g.part("Magazine", "Polymer", group="Magazine")
    bolt = g.part("Bolt", "Steel", group="Bolt")

    # --- receiver and barrel ----------------------------------------------
    g.lathe(receiver, [(0, 0), (0, 17), (230, 17), (236, 15), (236, 0)], (0, -110, 2), segments=28)
    rec = g.shapes[-1][0]
    g.cut(rec, g.cutter("box", (14, -40, 8), (14, 70, 14)))  # ejection port
    rail(g, rails, -110, 190, (0, 17))
    g.lathe(barrel, [(0, 0), (0, 14), (40, 14), (44, 11), (480, 9), (480, 0)], (0, 120, 0))
    g.lathe(barrel, [(0, 0), (0, 10.5), (6, 10.5), (8, 9), (8, 0)], (0, 592, 0), segments=24)  # crown
    # Folding backup sights.
    g.slab(rails, [(560, 8), (580, 8), (578, 26), (562, 26)], 12, bevel=1.5)
    g.tube(rails, (0, 570, 24), (0, 570, 32), 1.4, segments=8)

    # --- stock --------------------------------------------------------------
    s = g.slab(stock, [(440, -6), (440, -34), (420, -46), (130, -48), (24, -48), (-40, -50), (-62, -108),
                       (-118, -116), (-150, -80), (-376, -124), (-386, -118), (-386, -4), (-376, 2), (-150, 0),
                       (-112, -6), (110, -6)], 40, bevel=8, segments=3)
    g.taper(s, 1, [(-386, 1.05), (-150, 0.85), (100, 1.0), (440, 0.85)])
    g.taper(s, 2, [(-120, 0.8), (-60, 1.0)])
    g.slab(pad, [(-386, 2), (-386, -124), (-400, -126), (-400, 4)], 42, bevel=4, segments=3)
    for y in (300, 360):  # bipod leg seams in the forend
        g.box(stock, (0, y, -48), (30, 3, 2), bevel=0.5)

    # --- controls and magazine -------------------------------------------
    tg = g.slab(guard, [(-48, -44), (-44, -64), (-36, -72), (14, -72), (18, -64), (18, -44)], 10, bevel=1.5)
    g.cut(tg, g.cutter("slab", [(-40, -30), (-38, -62), (10, -62), (12, -56), (12, -30)], 14))
    g.slab(trigger, [(-14, -46), (-6, -46), (-10, -58), (-18, -66), (-23, -64), (-16, -54)], 6, bevel=1.2)
    g.slab(magazine, [(24, -30), (86, -30), (86, -60), (24, -60)], 30, bevel=3)

    g.lathe(bolt, [(0, 0), (0, 13), (24, 13), (30, 9), (30, 0)], (0, -140, 2), direction=(0, 1, 0), segments=24)
    g.tube(bolt, (14, -92, 4), (38, -100, -22), 4, segments=12)
    g.lathe(bolt, [(0, 0), (0, 6), (4, 9), (12, 9), (16, 0)], (36, -100, -20), direction=(0.5, -0.1, -0.86),
            segments=18)

    # --- forward-mounted scout scope ---------------------------------------
    scope(g, optic, 40, 250, 46, tube=12, objective=16, eyepiece=16, mounts=(90, 200), base=26)

    return GRIP, MUZZLE
