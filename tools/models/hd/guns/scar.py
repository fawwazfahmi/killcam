"""SCAR-L (Mk 16, standard 351 mm barrel), modelled from published dimensions.

Tan monolithic upper running forward as the handguard with side and bottom
rails, polymer lower, side-folding stock with cheek riser, left-side
reciprocating charging handle, birdcage flash hider, STANAG magazine.
Millimetres, bore on the Y axis, +Y toward the muzzle, +Z up, +X right.
"""

import math

from kit import arc, rail

NAME = "SCAR"
STUDS_PER_METRE = 5.5
GRIP = (0, -96, -100)
MUZZLE = (0, 482, 0)


def build(g):
    upper = g.part("UpperReceiver", "Tan")
    lower = g.part("LowerReceiver", "Tan")
    rails = g.part("Rail", "Steel")
    barrel = g.part("Barrel", "Steel")
    sights = g.part("Sights", "Steel")
    stock = g.part("Stock", "Tan")
    pad = g.part("ButtPad", "Polymer")
    hinge = g.part("StockHinge", "Steel")
    grip = g.part("Grip", "Polymer")
    trigger = g.part("Trigger", "Steel", group="Trigger")
    selector = g.part("Selector", "Steel", group="Selector")
    magazine = g.part("Magazine", "Polymer", group="Magazine")
    charging = g.part("ChargingHandle", "Steel", group="ChargingHandle")
    bolt = g.part("Bolt", "Bare", group="Bolt")

    # --- upper: one long block from the stock hinge to the gas block ------
    up = g.slab(upper, [(-125, -12), (92, -12), (112, -38), (322, -38), (330, -28), (330, 22), (-125, 22)],
                44, bevel=3, segments=2)
    g.cut(up, g.cutter("box", (19, 15, -1), (12, 72, 18)))  # ejection port
    g.cut(up, g.cutter("box", (-19, 60, 8), (12, 150, 9)))  # charging handle track, left side
    for y in (140, 172, 204, 236, 268, 300):  # lightening pockets in the handguard section
        g.cut(up, g.cutter("box", (0, y, -22), (60, 22, 16)))
    rail(g, rails, -125, 330, (0, 22), "up")
    rail(g, rails, 122, 322, (22, -14), "right", width=19)
    rail(g, rails, 122, 322, (-22, -14), "left", width=19)
    rail(g, rails, 118, 322, (0, -38), "down", width=21)

    # --- lower ---------------------------------------------------------------
    low = g.slab(lower, [(-125, -11), (100, -11), (98, -40), (96, -86), (22, -86), (20, -56), (-30, -52),
                         (-70, -46), (-118, -42), (-125, -30)], 36, bevel=3)
    g.cut(low, g.cutter("box", (0, 59, -62), (25, 70, 56)))
    g.box(lower, (0, 59, -84), (40, 84, 9), bevel=2.5)  # flared well lip
    tg = g.slab(lower, [(-50, -44), (-46, -70), (-38, -77), (22, -77), (26, -69), (26, -44)], 12, bevel=2)
    g.cut(tg, g.cutter("slab", [(-42, -30), (-40, -67), (18, -67), (20, -60), (20, -30)], 16))
    g.tube(lower, (17, 22, -40), (20, 22, -40), 5.5, segments=14, bevel=0.6)  # magazine release
    for y, z in [(88, -20), (-110, -24)]:
        g.tube(lower, (-18.5, y, z), (18.5, y, z), 3.4, segments=12)

    # --- barrel, gas block, flash hider ----------------------------------
    g.lathe(barrel, [(0, 0), (0, 12), (30, 12), (32, 9.5), (200, 9.5), (200, 0)], (0, 240, 0))
    g.slab(barrel, [(330, -14), (330, 18), (352, 18), (352, -14)], 30, bevel=3)  # gas block and regulator
    g.tube(barrel, (16, 341, 6), (24, 341, 6), 6, segments=14, bevel=0.6)
    hider = g.lathe(barrel, [(0, 0), (0, 10), (6, 11.5), (42, 11.5), (44, 10), (44, 0)], (0, 438, 0), segments=28)
    g.cut(hider, g.cutter("tube", (0, 430, 0), (0, 490, 0), 5.5, segments=16))
    for angle in range(0, 360, 60):
        a = math.radians(angle + 30)
        g.cut(hider, g.cutter("box", (math.cos(a) * 11, 465, math.sin(a) * 11), (6, 24, 6)))

    # Folding sights on the top rail, standing up.
    g.slab(sights, [(-112, 30), (-78, 30), (-82, 40), (-108, 40)], 28, bevel=1.5)
    rs = g.slab(sights, [(-102, 40), (-88, 40), (-88, 62), (-95, 67), (-102, 62)], 22, bevel=2)
    g.cut(rs, g.cutter("tube", (0, -106, 55), (0, -84, 55), 3.5, segments=12))
    g.slab(sights, [(296, 30), (326, 30), (322, 40), (300, 40)], 28, bevel=1.5)
    fs = g.slab(sights, [(304, 40), (318, 40), (318, 68), (304, 68)], 22, bevel=2)
    g.cut(fs, g.cutter("box", (0, 311, 62), (14, 30, 12)))
    g.tube(sights, (0, 311, 48), (0, 311, 64), 1.4, segments=8)

    # --- side-folding stock -----------------------------------------------
    g.slab(hinge, [(-125, 20), (-125, -40), (-140, -40), (-140, 20)], 40, bevel=3)
    st = g.slab(stock, [(-140, 22), (-140, -38), (-170, -42), (-215, -32), (-260, -44), (-330, -80),
                        (-352, -84), (-358, -78), (-358, 30), (-345, 40), (-170, 40), (-150, 26)],
                44, bevel=5, segments=3)
    g.taper(st, 1, [(-358, 1.0), (-140, 0.86)])
    g.cut(st, g.cutter("slab", [(-185, -8), (-250, -16), (-305, -52), (-305, -6), (-185, 14)], 60))  # skeleton hole
    g.slab(stock, [(-180, 40), (-330, 40), (-325, 48), (-185, 48)], 34, bevel=4)  # cheek riser
    g.slab(pad, [(-358, 32), (-358, -80), (-370, -82), (-370, 34)], 46, bevel=4, segments=3)

    # --- grip and controls ----------------------------------------------
    gr = g.slab(grip, [(-48, -36), (-94, -34), (-102, -60), (-132, -148), (-128, -158), (-102, -160),
                       (-92, -150), (-80, -112), (-70, -104), (-66, -82), (-56, -62)], 30, bevel=7, segments=3)
    g.taper(gr, 2, [(-160, 1.05), (-40, 0.9)])
    g.slab(trigger, [(-10, -46), (-2, -46), (-6, -60), (-14, -68), (-19, -66), (-12, -56)], 6, bevel=1.2)
    g.slab(selector, [(-46, -26), (-32, -22), (-22, -24), (-24, -30), (-36, -32)], 3, x=19.5, bevel=0.8)
    g.tube(selector, (18, -38, -28), (21, -38, -28), 5, segments=14, bevel=0.5)

    g.box(bolt, (0, 15, -1), (28, 70, 14), bevel=1.5)
    g.tube(charging, (-20, 100, 8), (-40, 100, 8), 4.5, segments=12)
    g.lathe(charging, [(0, 0), (0, 7), (14, 7), (16, 0)], (-38, 100, 8), direction=(-1, 0, 0), segments=16)

    # --- magazine: 30-round polymer STANAG -----------------------------
    centre = arc((59, -40), 820, 206, 20)
    g.sweep(magazine, centre, lambda t: 31 - 1.5 * t, 24, bevel=2)
    for k in range(6):  # grip texture bands low on the body
        i = 9 + k * 1.6
        a, b = centre[int(i)], centre[int(i) + 1]
        g.sweep(magazine, [a, b], lambda t: 31.8 - 1.5 * i / 20, 22, bevel=0.6)
    g.sweep(magazine, centre[-2:], lambda t: 34, 28, bevel=3)

    return GRIP, MUZZLE
