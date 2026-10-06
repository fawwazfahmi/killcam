"""MAC-10, modelled from published dimensions.

Stamped box receiver with the magazine in the grip, cocking knob on top,
short threaded barrel, front strap, wire stock collapsed along the sides.
Overall 269 mm with the stock in, barrel 146 mm. Millimetres, bore on the Y
axis, +Y toward the muzzle, +Z up, +X right.
"""

NAME = "MAC10"
STUDS_PER_METRE = 5.5
GRIP = (0, -20, -100)
MUZZLE = (0, 178, 0)


def build(g):
    receiver = g.part("Receiver", "Steel")
    barrel = g.part("Barrel", "Steel")
    stock = g.part("Stock", "Steel")
    grip = g.part("Grip", "Steel")
    trigger = g.part("Trigger", "Steel", group="Trigger")
    selector = g.part("Selector", "Steel", group="Selector")
    magazine = g.part("Magazine", "Steel", group="Magazine")
    charging = g.part("ChargingHandle", "Bare", group="ChargingHandle")
    bolt = g.part("Bolt", "Bare", group="Bolt")

    # --- receiver ------------------------------------------------------------
    rec = g.slab(receiver, [(-112, -36), (132, -36), (132, 30), (-112, 30)], 50, bevel=3)
    g.cut(rec, g.cutter("box", (0, 40, 30), (6, 110, 10)))  # cocking slot on top
    g.cut(rec, g.cutter("box", (24, 64, 6), (10, 44, 18)))  # ejection port
    for y in (-96, 116):  # rivets
        for z in (-26, 20):
            g.tube(receiver, (-25.6, y, z), (25.6, y, z), 2.5, segments=10)
    g.slab(receiver, [(-110, 30), (-94, 30), (-94, 44), (-110, 44)], 30, bevel=2)  # rear sight ears
    g.cut(g.shapes[-1][0], g.cutter("box", (0, -102, 42), (8, 30, 10)))
    g.slab(receiver, [(118, 30), (130, 30), (130, 44), (118, 44)], 16, bevel=1.5)  # front sight
    # Front strap under the muzzle end.
    strap = g.slab(receiver, [(70, -36), (132, -36), (132, -62), (112, -66), (70, -46)], 8, bevel=1.5)
    g.cut(strap, g.cutter("slab", [(86, -40), (124, -40), (124, -56), (110, -58), (86, -46)], 12))

    g.lathe(barrel, [(0, 0), (0, 10), (46, 10), (46, 0)], (0, 132, 0), segments=24)
    for k in range(10):  # threads
        y = 140 + k * 3.6
        g.tube(barrel, (0, y, 0), (0, y + 1.6, 0), 11, segments=24)
    g.cut(g.shapes[-1][0], g.cutter("tube", (0, 120, 0), (0, 182, 0), 4.5, segments=14))

    # --- grip with the magazine inside, trigger guard ---------------------
    g.slab(grip, [(-48, -34), (8, -34), (6, -160), (-44, -164)], 40, bevel=5, segments=3)
    tg = g.slab(grip, [(8, -36), (52, -36), (52, -48), (26, -92), (6, -96)], 10, bevel=2)
    g.cut(tg, g.cutter("slab", [(10, -30), (42, -30), (42, -44), (22, -82), (10, -84)], 14))
    g.slab(trigger, [(10, -38), (18, -38), (16, -54), (8, -64), (4, -62), (10, -50)], 6, bevel=1.2)
    g.slab(magazine, [(-42, -150), (4, -150), (6, -186), (-40, -190)], 30, bevel=2)
    g.slab(magazine, [(-46, -186), (10, -182), (10, -194), (-46, -198)], 34, bevel=2)
    g.slab(selector, [(-30, -10), (-10, -6), (-8, -14), (-26, -20)], 3, x=26.5, bevel=0.8)

    # --- cocking knob and bolt ---------------------------------------------
    g.tube(charging, (0, 52, 26), (0, 52, 38), 3.5, segments=12)
    g.lathe(charging, [(0, 0), (0, 9), (8, 9), (12, 6), (13, 0)], (0, 52, 36), direction=(0, 0, 1), segments=18)
    g.box(bolt, (0, 64, 6), (38, 44, 18), bevel=1)

    # --- wire stock, collapsed along the sides -------------------------------
    for sign in (1, -1):
        g.tube(stock, (sign * 28, -126, -10), (sign * 28, 100, -10), 3.5, segments=10)
        g.tube(stock, (sign * 28, -126, -26), (sign * 28, -40, -26), 3.5, segments=10)
    g.slab(stock, [(-120, 4), (-120, -40), (-130, -40), (-130, 4)], 62, bevel=3)

    return GRIP, MUZZLE
