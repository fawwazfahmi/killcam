"""MP7A1, modelled from published dimensions.

Compact polymer body with the magazine in the grip, large integral trigger
guard, folded front grip, full-length top rail with folding sights, T-shaped
charging handle, retractable stock pulled out, 40-round magazine. Barrel 180
mm. Millimetres, bore on the Y axis, +Y toward the muzzle, +Z up, +X right.
"""

from kit import rail

NAME = "MP7"
STUDS_PER_METRE = 5.5
GRIP = (0, -22, -96)
MUZZLE = (0, 206, 0)


def build(g):
    body = g.part("Body", "Polymer")
    rails = g.part("Rail", "Steel")
    barrel = g.part("Barrel", "Steel")
    foregrip = g.part("Foregrip", "Polymer")
    stock = g.part("Stock", "Steel")
    pad = g.part("ButtPad", "Polymer")
    trigger = g.part("Trigger", "Steel", group="Trigger")
    selector = g.part("Selector", "Steel", group="Selector")
    magazine = g.part("Magazine", "Polymer", group="Magazine")
    charging = g.part("ChargingHandle", "Steel", group="ChargingHandle")
    bolt = g.part("Bolt", "Bare", group="Bolt")

    # --- body: receiver, grip and trigger guard in one moulding -------------
    b = g.slab(body, [(-140, 26), (150, 26), (164, 12), (164, -30), (22, -30), (14, -56), (0, -152), (-46, -154),
                      (-38, -62), (-46, -42), (-140, -32)], 44, bevel=7, segments=3)
    g.taper(b, 2, [(-154, 0.78), (-60, 0.78), (-30, 1.0)])
    g.cut(b, g.cutter("box", (20, 40, 8), (14, 46, 16)))  # ejection port
    tg = g.slab(body, [(20, -28), (76, -28), (76, -44), (40, -96), (10, -96), (12, -84)], 18, bevel=3)
    g.cut(tg, g.cutter("slab", [(24, -40), (64, -40), (36, -84), (18, -84)], 24))
    for y in (-110, -80):  # stock rail slots along the sides
        g.box(body, (0, y, -2), (46, 18, 4), bevel=1)
    rail(g, rails, -136, 150, (0, 26))

    g.lathe(barrel, [(0, 0), (0, 12), (8, 12), (10, 9), (42, 9), (42, 0)], (0, 164, 0), segments=24)
    g.cut(g.shapes[-1][0], g.cutter("tube", (0, 150, 0), (0, 212, 0), 3.5, segments=14))
    # Folding sights, standing up.
    g.slab(rails, [(-128, 34), (-108, 34), (-108, 54), (-118, 58), (-128, 54)], 20, bevel=2)
    g.cut(g.shapes[-1][0], g.cutter("tube", (0, -132, 48), (0, -104, 48), 3, segments=12))
    g.slab(rails, [(128, 34), (144, 34), (144, 56), (128, 56)], 20, bevel=2)
    g.cut(g.shapes[-1][0], g.cutter("box", (0, 136, 52), (12, 24, 10)))

    # --- folded front grip --------------------------------------------------
    g.slab(foregrip, [(84, -30), (160, -30), (160, -50), (92, -50)], 30, bevel=6, segments=3)
    g.tube(foregrip, (-16, 156, -38), (16, 156, -38), 6, segments=14)

    # --- controls, magazine ------------------------------------------------
    g.slab(trigger, [(24, -32), (32, -32), (30, -48), (22, -58), (18, -56), (24, -46)], 6, bevel=1.2)
    for sign in (1, -1):
        g.slab(selector, [(-34, -6), (-18, -2), (-14, -10), (-30, -16)], 3, x=sign * 22.5, bevel=0.8)
    g.slab(magazine, [(-42, -140), (-2, -140), (2, -204), (-40, -208)], 30, bevel=2.5)
    g.slab(magazine, [(-44, -204), (6, -200), (6, -212), (-44, -216)], 34, bevel=2.5)
    g.box(bolt, (0, 40, 8), (28, 44, 14), bevel=1)
    g.slab(charging, [(-152, 18), (-138, 18), (-138, 26), (-152, 26)], 20, bevel=1)
    g.slab(charging, [(-158, 16), (-148, 16), (-148, 28), (-158, 28)], 48, bevel=2.5, segments=3)

    # --- retractable stock, pulled out --------------------------------------
    for sign in (1, -1):
        g.box(stock, (sign * 20, -200, -2), (5, 140, 12), bevel=1.5)
    g.slab(stock, [(-262, 22), (-262, -52), (-272, -54), (-272, 24)], 44, bevel=3)
    g.slab(pad, [(-272, 26), (-272, -56), (-284, -52), (-284, 22)], 48, bevel=5, segments=3)

    return GRIP, MUZZLE
