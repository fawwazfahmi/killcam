"""Remington MSR, modelled from published dimensions.

Modular bolt-action: tan chassis with a long slotted free-float handguard and
full-length top rail, side-folding skeleton stock with adjustable cheek
riser, muzzle brake, 10-round box magazine. Overall about 1170 mm with the
stock open, 22 inch barrel. Millimetres, bore on the Y axis, +Y toward the
muzzle, +Z up, +X right.
"""

import math

from kit import rail, scope

NAME = "MSR"
STUDS_PER_METRE = 5.5
GRIP = (0, -96, -100)
MUZZLE = (0, 720, 0)


def build(g):
    chassis = g.part("Chassis", "Tan")
    rails = g.part("Rail", "Steel")
    barrel = g.part("Barrel", "Steel")
    stock = g.part("Stock", "Tan")
    pad = g.part("ButtPad", "Polymer")
    hinge = g.part("StockHinge", "Steel")
    grip = g.part("Grip", "Polymer")
    optic = g.part("Scope", "Polymer")
    trigger = g.part("Trigger", "Steel", group="Trigger")
    magazine = g.part("Magazine", "Steel", group="Magazine")
    bolt = g.part("Bolt", "Steel", group="Bolt")

    # --- chassis and handguard -------------------------------------------
    c = g.slab(chassis, [(-125, 22), (150, 22), (150, -44), (100, -46), (100, -88), (24, -88), (24, -50),
                         (-40, -46), (-125, -40)], 42, bevel=3)
    g.cut(c, g.cutter("box", (18, -20, 8), (12, 90, 16)))
    g.cut(c, g.cutter("box", (0, 62, -66), (32, 72, 70)))  # magazine well
    tg = g.slab(chassis, [(-50, -42), (-46, -70), (-38, -78), (20, -78), (24, -70), (24, -42)], 12, bevel=2)
    g.cut(tg, g.cutter("slab", [(-42, -30), (-40, -68), (16, -68), (18, -60), (18, -30)], 16))
    hg = g.slab(chassis, [(150, 22), (520, 22), (520, -40), (150, -40)], 48, bevel=4, segments=2)
    for y in range(180, 500, 38):  # mounting slots down both sides and underneath
        g.cut(hg, g.cutter("box", (0, y, -8), (60, 24, 12)))
        g.cut(hg, g.cutter("box", (0, y + 10, -40), (20, 18, 12)))
    rail(g, rails, -125, 520, (0, 22))

    # --- barrel and brake ------------------------------------------------
    g.lathe(barrel, [(0, 0), (0, 14), (430, 11), (430, 0)], (0, 260, 0), segments=28)
    brake = g.lathe(barrel, [(0, 0), (0, 15), (40, 15), (42, 13), (42, 0)], (0, 678, 0), segments=28)
    g.cut(brake, g.cutter("tube", (0, 670, 0), (0, 730, 0), 6, segments=16))
    for y in (690, 706):
        g.cut(brake, g.cutter("box", (0, y, 0), (40, 8, 14)))

    # --- side-folding skeleton stock ------------------------------------
    g.slab(hinge, [(-125, 20), (-125, -38), (-140, -38), (-140, 20)], 40, bevel=3)
    s = g.slab(stock, [(-140, 22), (-140, -38), (-176, -42), (-236, -38), (-420, -104), (-442, -108),
                       (-448, -100), (-448, 30), (-434, 38), (-160, 38)], 40, bevel=5, segments=3)
    g.taper(s, 1, [(-448, 1.0), (-140, 0.86)])
    g.cut(s, g.cutter("slab", [(-186, -4), (-400, -10), (-410, -78), (-250, -30), (-186, -26)], 60))
    g.slab(stock, [(-210, 38), (-400, 38), (-400, 52), (-214, 54)], 34, bevel=5, segments=3)  # cheek riser
    for y in (-250, -370):
        g.tube(hinge, (0, y, 30), (0, y, 44), 3.5, segments=10)
    g.slab(pad, [(-448, 32), (-448, -102), (-462, -104), (-462, 34)], 44, bevel=4, segments=3)

    # --- grip, trigger, bolt, magazine -----------------------------------
    gr = g.slab(grip, [(-48, -36), (-94, -34), (-102, -60), (-132, -148), (-128, -158), (-102, -160),
                       (-92, -150), (-80, -112), (-70, -104), (-66, -82), (-56, -62)], 30, bevel=7, segments=3)
    g.taper(gr, 2, [(-160, 1.05), (-40, 0.9)])
    g.slab(trigger, [(-12, -44), (-4, -44), (-8, -58), (-16, -66), (-21, -64), (-14, -54)], 6, bevel=1.2)
    g.slab(magazine, [(28, -40), (96, -40), (98, -112), (30, -112)], 30, bevel=3)
    g.slab(magazine, [(26, -110), (100, -110), (100, -118), (26, -118)], 33, bevel=2)
    g.lathe(bolt, [(0, 0), (0, 14), (24, 14), (30, 10), (30, 0)], (0, -155, 2), segments=24)
    g.tube(bolt, (18, -100, 4), (48, -102, -6), 4.5, segments=12)
    g.lathe(bolt, [(0, 0), (0, 10), (4, 13), (18, 13), (22, 0)], (46, -102, -6), direction=(1, 0, -0.2), segments=20)

    # --- scope -----------------------------------------------------------
    scope(g, optic, -150, 300, 66, tube=16, objective=27, eyepiece=22, mounts=(-60, 150), base=30)

    return GRIP, MUZZLE
