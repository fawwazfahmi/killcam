"""MP5A3, modelled from published dimensions.

Rounded stamped receiver, cocking tube over the barrel with the handle on the
left, slim handguard, hooded front sight and drum rear sight, polymer trigger
group and grip, curved 30-round magazine, retractable stock pulled out.
Barrel 225 mm. Millimetres, bore on the Y axis, +Y toward the muzzle, +Z up,
+X right.
"""

from kit import arc

NAME = "MP5"
STUDS_PER_METRE = 5.5
GRIP = (0, -76, -92)
MUZZLE = (0, 336, 0)


def build(g):
    receiver = g.part("Receiver", "Steel")
    barrel = g.part("Barrel", "Steel")
    sights = g.part("Sights", "Steel")
    handguard = g.part("Handguard", "Polymer")
    lower = g.part("TriggerGroup", "Polymer")
    stock = g.part("Stock", "Steel")
    pad = g.part("ButtPad", "Polymer")
    trigger = g.part("Trigger", "Steel", group="Trigger")
    selector = g.part("Selector", "Steel", group="Selector")
    magazine = g.part("Magazine", "Steel", group="Magazine")
    charging = g.part("ChargingHandle", "Steel", group="ChargingHandle")
    bolt = g.part("Bolt", "Bare", group="Bolt")

    # --- receiver, cocking tube, barrel ---------------------------------
    rec = g.slab(receiver, [(-112, -22), (162, -22), (162, 22), (-112, 22)], 32, bevel=10, segments=4)
    g.cut(rec, g.cutter("box", (14, 26, 2), (12, 52, 16)))  # ejection port
    g.tube(receiver, (0, 150, 22), (0, 300, 22), 11, segments=20)  # cocking tube
    g.slab(receiver, [(30, -22), (74, -22), (74, -46), (30, -46)], 30, bevel=2)  # magazine well
    g.slab(receiver, [(-112, -18), (-112, 18), (-122, 14), (-122, -14)], 30, bevel=3)  # end cap
    g.lathe(barrel, [(0, 0), (0, 10), (160, 9), (160, 0)], (0, 162, 0))
    g.lathe(barrel, [(0, 0), (0, 11), (4, 12), (10, 12), (12, 11), (14, 0)], (0, 316, 0), segments=24)  # 3-lug
    g.cut(g.shapes[-1][0], g.cutter("tube", (0, 300, 0), (0, 340, 0), 4.5, segments=14))

    # Hooded front sight on the end of the cocking tube; drum rear sight.
    hood = g.lathe(sights, [(0, 0), (0, 15), (20, 15), (20, 0)], (0, 286, 34), segments=24)
    g.cut(hood, g.cutter("tube", (0, 280, 36), (0, 310, 36), 11, segments=20))
    g.slab(sights, [(286, 10), (306, 10), (306, 26), (286, 26)], 22, bevel=2)
    g.tube(sights, (0, 296, 26), (0, 296, 42), 1.6, segments=8)
    g.slab(sights, [(-100, 18), (-60, 18), (-64, 30), (-96, 30)], 22, bevel=2)
    g.lathe(sights, [(0, 0), (0, 13), (24, 13), (24, 0)], (-12, -80, 38), direction=(1, 0, 0), segments=24)

    # --- handguard ------------------------------------------------------
    g.slab(handguard, [(164, 8), (164, -24), (172, -30), (276, -30), (288, -22), (288, 8)], 34,
           bevel=12, segments=4)

    # --- trigger group and grip -----------------------------------------
    g.slab(lower, [(-100, -18), (22, -18), (22, -34), (-100, -34)], 34, bevel=3)
    g.slab(lower, [(-28, -32), (-74, -32), (-84, -60), (-110, -140), (-104, -152), (-78, -152), (-70, -142),
                   (-54, -86), (-46, -78), (-38, -56)], 30, bevel=8, segments=3)
    tg = g.slab(lower, [(-30, -34), (-26, -62), (16, -62), (22, -54), (22, -32)], 12, bevel=2)
    g.cut(tg, g.cutter("slab", [(-22, -24), (-20, -54), (10, -54), (14, -48), (14, -24)], 16))
    g.slab(trigger, [(-6, -36), (2, -36), (-2, -48), (-10, -56), (-14, -54), (-8, -46)], 6, bevel=1.2)
    g.slab(selector, [(-62, -18), (-48, -16), (-46, -24), (-58, -28)], 3, x=-17.5, bevel=0.8)
    g.tube(selector, (-19, -54, -22), (-16, -54, -22), 5, segments=14)
    g.slab(lower, [(76, -38), (86, -38), (88, -52), (78, -54)], 16, bevel=1.5)  # paddle release

    g.box(bolt, (0, 26, 2), (22, 50, 14), bevel=1)
    g.tube(charging, (-10, 268, 26), (-34, 278, 30), 4, segments=12)
    g.lathe(charging, [(0, 0), (0, 6), (10, 7), (12, 0)], (-32, 277, 30), direction=(-1, 0.3, 0.2), segments=16)

    # --- curved 30-round magazine ----------------------------------------
    centre = arc((52, -30), 300, 200, 18)
    g.sweep(magazine, centre, lambda t: 18, 23, bevel=2)
    g.sweep(magazine, centre[4:-3], lambda t: 4, 25, bevel=1)
    g.sweep(magazine, centre[-2:], lambda t: 20, 26, bevel=2)

    # --- retractable stock, pulled out ----------------------------------
    for sign in (1, -1):
        g.tube(stock, (sign * 12, -112, 4), (sign * 12, -318, 4), 4.2, segments=12)
    g.slab(stock, [(-112, -10), (-112, 16), (-120, 16), (-120, -10)], 36, bevel=1.5)
    g.slab(stock, [(-310, 26), (-310, -70), (-322, -72), (-322, 28)], 32, bevel=3)
    g.slab(pad, [(-322, 30), (-322, -74), (-334, -70), (-334, 26)], 40, bevel=5, segments=3)

    return GRIP, MUZZLE
