"""M16A2 rifle (20 inch barrel), modelled from published dimensions.

Fixed carry handle with the rear sight in it, round ribbed handguards behind a
triangular front sight tower, A2 flash hider, fixed stock, 30-round STANAG
magazine. Overall 1,000 mm. Millimetres, bore on the Y axis, +Y toward the
muzzle, +Z up, +X right.
"""

import math

from kit import arc

NAME = "M16"
STUDS_PER_METRE = 5.5
GRIP = (0, -96, -100)
MUZZLE = (0, 640, 0)


def build(g):
    upper = g.part("UpperReceiver", "Steel")
    handle = g.part("CarryHandle", "Steel")
    lower = g.part("LowerReceiver", "Steel")
    barrel = g.part("Barrel", "Steel")
    handguard = g.part("Handguard", "Polymer")
    front = g.part("FrontSight", "Steel")
    stock = g.part("Stock", "Polymer")
    plate = g.part("ButtPlate", "Steel")
    grip = g.part("Grip", "Polymer")
    guard = g.part("TriggerGuard", "Steel")
    trigger = g.part("Trigger", "Steel", group="Trigger")
    selector = g.part("Selector", "Steel", group="Selector")
    magazine = g.part("Magazine", "Steel", group="Magazine")
    charging = g.part("ChargingHandle", "Steel", group="ChargingHandle")
    bolt = g.part("Bolt", "Bare", group="Bolt")

    # --- upper receiver ----------------------------------------------------
    up = g.slab(upper, [(-95, -12), (125, -12), (125, 22), (-95, 22)], 30, bevel=2)
    g.cut(up, g.cutter("box", (13, 40, 0), (14, 72, 18)))  # ejection port
    g.slab(upper, [(-20, -2), (-8, -2), (-4, 12), (-20, 14)], 6, x=16, bevel=1.2)  # brass deflector
    g.lathe(upper, [(0, 0), (0, 6.5), (20, 6.5), (22, 7.5), (30, 7.5), (31, 0)],
            (14, -48, 6), direction=(0.55, -0.8, 0.1), segments=16)  # forward assist
    g.box(upper, (14.6, 40, 11), (1.5, 74, 3), bevel=0.4)  # port cover hinge

    # --- carry handle, with the rear sight in its back end ------------------
    h = g.slab(handle, [(-96, 20), (-96, 60), (-72, 67), (-40, 67), (-30, 58), (84, 52), (104, 40), (120, 20)],
               24, bevel=2.5)
    g.cut(h, g.cutter("slab", [(-26, 27), (-20, 47), (76, 43), (92, 29)], 30))  # the opening you carry it by
    g.cut(h, g.cutter("box", (0, -66, 58), (12, 44, 14)))  # the well the sight sits in
    g.cut(h, g.cutter("tube", (0, -100, 55), (0, -24, 55), 2.6, segments=12))  # line of sight
    g.box(handle, (0, -64, 57), (9, 5, 13), bevel=1)  # the aperture leaf
    g.cut(g.shapes[-1][0], g.cutter("tube", (0, -70, 58), (0, -58, 58), 2.4, segments=12))
    g.tube(handle, (12, -64, 56), (21, -64, 56), 7, segments=18, bevel=0.8)  # windage knob
    g.tube(handle, (-14, -58, 28), (14, -58, 28), 9, segments=20, bevel=0.8)  # elevation wheel

    # --- lower receiver ----------------------------------------------------
    low = g.slab(lower, [(-95, -12), (112, -12), (110, -40), (108, -84), (26, -84), (24, -56), (-30, -52),
                         (-60, -46), (-90, -40), (-95, -30)], 28, bevel=2)
    g.cut(low, g.cutter("box", (0, 66, -60), (24, 70, 60)))  # magazine well
    for y, z in [(100, -20), (-82, -22)]:  # takedown pins
        g.tube(lower, (-15.5, y, z), (15.5, y, z), 3.4, segments=12)
    g.tube(lower, (14, 24, -40), (17, 24, -40), 5, segments=14, bevel=0.5)  # magazine release
    g.slab(lower, [(-92, -14), (-92, -36), (-108, -30), (-108, -16)], 22, bevel=1.5)  # receiver extension

    # --- barrel, handguards and front sight ------------------------------------
    g.lathe(barrel, [(0, 0), (0, 12), (40, 12), (42, 9), (318, 9), (320, 10.5), (468, 10.5), (468, 0)], (0, 125, 0))
    hider = g.lathe(barrel, [(0, 0), (0, 10), (6, 11), (47, 11), (49, 9.5), (49, 0)], (0, 591, 0), segments=28)
    g.cut(hider, g.cutter("tube", (0, 580, 0), (0, 645, 0), 5.5, segments=16))
    for angle in (90, 30, 150, 210, 330):  # A2 slots, none at the bottom
        a = math.radians(angle)
        g.cut(hider, g.cutter("box", (math.cos(a) * 11, 620, math.sin(a) * 11), (6, 22, 6)))

    # Round handguards, ribbed along their length, between the slip ring and the cap.
    profile = [(0, 0), (0, 30), (14, 30), (16, 27.5)]
    for k in range(15):
        y = 18 + k * 19.2
        r = 27.5 - 3.2 * (k / 14)
        profile += [(y, r), (y + 2, r + 1.6), (y + 15, r + 1.6), (y + 17, r)]
    profile += [(306, 24.3), (308, 26.5), (314, 26.5), (314, 0)]
    g.lathe(handguard, profile, (0, 126, 0), segments=32)
    g.lathe(barrel, [(0, 0), (0, 30.5), (6, 30.5), (14, 26), (14, 0)], (0, 124, 0), segments=32)  # slip ring

    tower = g.slab(front, [(440, -16), (486, -16), (478, 6), (470, 48), (452, 48), (446, 6)], 20, bevel=2)
    g.cut(tower, g.cutter("slab", [(452, 2), (472, 2), (468, 34), (456, 34)], 26))
    g.cut(tower, g.cutter("box", (0, 461, 44), (10, 30, 12)))  # the ears either side of the post
    g.tube(front, (0, 461, 34), (0, 461, 47), 1.4, segments=8)  # front sight post
    g.tube(front, (0, 440, 0), (0, 486, 0), 13, segments=24)  # the band round the barrel
    g.slab(front, [(452, -16), (480, -16), (478, -26), (456, -26)], 9, bevel=1.5)  # bayonet lug
    ring = g.tube(front, (-3, 446, -28), (3, 446, -28), 9, segments=20)  # sling swivel
    g.cut(ring, g.cutter("tube", (-5, 446, -28), (5, 446, -28), 6.4, segments=16))

    # --- fixed stock ---------------------------------------------------------
    s = g.slab(stock, [(-98, 18), (-98, -34), (-180, -50), (-346, -80), (-352, -74), (-352, 14), (-344, 22),
                       (-108, 22)], 44, bevel=6, segments=3)
    g.taper(s, 1, [(-352, 1.0), (-98, 0.7)])
    g.slab(plate, [(-352, 16), (-352, -76), (-360, -78), (-360, 18)], 42, bevel=2.5)
    g.box(plate, (0, -358, -22), (20, 5, 26), bevel=1.5)  # trapdoor for the cleaning kit
    rear = g.tube(stock, (-3, -300, -80), (3, -300, -80), 9, segments=20)  # rear sling swivel
    g.cut(rear, g.cutter("tube", (-5, -300, -80), (5, -300, -80), 6.4, segments=16))

    # --- grip and controls ------------------------------------------------
    gr = g.slab(grip, [(-48, -36), (-94, -34), (-102, -60), (-132, -148), (-128, -158), (-102, -160),
                       (-92, -150), (-84, -118), (-76, -112), (-74, -100), (-66, -82), (-56, -62)], 28, bevel=7,
                segments=3)
    g.taper(gr, 2, [(-160, 1.05), (-40, 0.9)])

    tg = g.slab(guard, [(-50, -44), (-46, -70), (-38, -76), (20, -76), (24, -68), (24, -44)], 10, bevel=1.5)
    g.cut(tg, g.cutter("slab", [(-42, -30), (-40, -66), (16, -66), (18, -60), (18, -30)], 14))
    g.slab(trigger, [(-10, -46), (-2, -46), (-6, -60), (-14, -68), (-19, -66), (-12, -56)], 6, bevel=1.2)
    g.slab(selector, [(-46, -26), (-32, -22), (-22, -24), (-24, -30), (-36, -32)], 3, x=-15.5, bevel=0.8)
    g.tube(selector, (-17, -38, -28), (-14, -38, -28), 5, segments=14, bevel=0.5)

    g.box(bolt, (0, 40, 0), (20, 76, 14), bevel=1.5)
    g.slab(charging, [(-110, 14), (-92, 14), (-92, 21), (-110, 21)], 20, bevel=1)
    g.slab(charging, [(-114, 12), (-104, 12), (-104, 22), (-114, 22)], 50, bevel=2.5, segments=3)  # T-handle

    # --- magazine: 30-round STANAG, slight curve low down -----------------
    centre = arc((67, -40), 820, 206, 20)
    g.sweep(magazine, centre, lambda t: 31 - 1.5 * t, 23, bevel=2)
    for d in (-17, 0, 17):  # pressed ribs down each side
        rib = [(y + d, z) for y, z in centre[5:-2]]
        g.sweep(magazine, rib, lambda t: 1.6, 24.6, bevel=0.6)
    g.sweep(magazine, centre[-2:], lambda t: 33, 27, bevel=2.5)  # floor plate

    return GRIP, MUZZLE
