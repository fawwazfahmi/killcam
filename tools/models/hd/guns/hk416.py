"""HK416 carbine (14.5 inch barrel), modelled from published dimensions.

Flat-top upper with a full-length rail, four-rail handguard, A2-pattern flash
hider, collapsible stock on the buffer tube, 30-round STANAG magazine, folding
sights. Millimetres, bore on the Y axis, +Y toward the muzzle, +Z up, +X right.
"""

import math

NAME = "HK416"
STUDS_PER_METRE = 5.5
GRIP = (0, -96, -100)
MUZZLE = (0, 540, 0)


def rail(g, part, y0, y1, centre, normal, width=21):
    """A Picatinny strip: base plus a tooth every 10 mm. `normal` is the
    direction the rail faces: "up", "down", "right" or "left"."""
    teeth = []
    for k in range(int((y1 - y0 - 4) // 10)):
        teeth.append(y0 + 7 + k * 10)
    x, z = centre
    if normal in ("up", "down"):
        s = 1 if normal == "up" else -1
        g.box(part, (x, (y0 + y1) / 2, z + s * 2), (width, y1 - y0, 4), bevel=0.6)
        for y in teeth:
            g.box(part, (x, y, z + s * 6), (width, 5, 4), bevel=0.5, segments=1)
    else:
        s = 1 if normal == "right" else -1
        g.box(part, (x + s * 2, (y0 + y1) / 2, z), (4, y1 - y0, width), bevel=0.6)
        for y in teeth:
            g.box(part, (x + s * 6, y, z), (4, 5, width), bevel=0.5, segments=1)


def build(g):
    upper = g.part("UpperReceiver", "Steel")
    lower = g.part("LowerReceiver", "Steel")
    rails = g.part("Rail", "Steel")
    handguard = g.part("Handguard", "Steel")
    barrel = g.part("Barrel", "Steel")
    sights = g.part("Sights", "Steel")
    tube = g.part("BufferTube", "Steel")
    stock = g.part("Stock", "Polymer")
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
    rail(g, rails, -95, 400, (0, 22), "up")

    # --- lower receiver ----------------------------------------------------
    low = g.slab(lower, [(-95, -12), (112, -12), (110, -40), (108, -84), (26, -84), (24, -56), (-30, -52),
                         (-60, -46), (-90, -40), (-95, -30)], 28, bevel=2)
    g.cut(low, g.cutter("box", (0, 66, -60), (24, 70, 60)))  # magazine well
    g.box(lower, (0, 67, -84), (33, 88, 8), bevel=2)  # flared well lip
    for y, z in [(100, -20), (-82, -22)]:  # takedown pins
        g.tube(lower, (-15.5, y, z), (15.5, y, z), 3.4, segments=12)
    g.tube(lower, (14, 24, -40), (17, 24, -40), 5, segments=14, bevel=0.5)  # magazine release
    g.slab(lower, [(-92, -14), (-92, -36), (-108, -30), (-108, -16)], 22, bevel=1.5)  # receiver extension
    g.tube(tube, (0, -94, -6), (0, -102, -6), 19, segments=24, bevel=0.8)  # castle nut

    # --- barrel, handguard and sights -----------------------------------
    g.lathe(barrel, [(0, 0), (0, 12), (40, 12), (42, 9.5), (368, 9.5), (368, 0)], (0, 125, 0))
    hider = g.lathe(barrel, [(0, 0), (0, 10), (6, 11), (47, 11), (49, 9.5), (49, 0)], (0, 491, 0), segments=28)
    g.cut(hider, g.cutter("tube", (0, 480, 0), (0, 545, 0), 5.5, segments=16))
    for angle in (90, 30, 150, 210, 330):  # A2 slots, none at the bottom
        a = math.radians(angle)
        g.cut(hider, g.cutter("box", (math.cos(a) * 11, 520, math.sin(a) * 11), (6, 22, 6)))

    hg = g.box(handguard, (0, 264, -3), (50, 272, 50), bevel=4, segments=3)
    for y in range(160, 380, 34):  # cooling slots on both sides
        g.cut(hg, g.cutter("box", (0, y, -10), (60, 16, 12)))
    rail(g, rails, 132, 396, (0, -28), "down", width=21)
    rail(g, rails, 132, 396, (25, -3), "right", width=21)
    rail(g, rails, 132, 396, (-25, -3), "left", width=21)
    g.slab(handguard, [(126, -30), (126, 22), (134, 22), (134, -30)], 56, bevel=2)  # barrel nut ring

    # Folding diopter rear sight and front post, both standing up.
    g.slab(sights, [(-70, 30), (-30, 30), (-34, 40), (-66, 40)], 26, bevel=1.5)
    rs = g.slab(sights, [(-58, 40), (-46, 40), (-46, 62), (-52, 66), (-58, 62)], 22, bevel=2)
    g.cut(rs, g.cutter("tube", (0, -62, 55), (0, -40, 55), 3.5, segments=12))
    g.slab(sights, [(372, 30), (402, 30), (398, 40), (376, 40)], 26, bevel=1.5)
    fs = g.slab(sights, [(380, 40), (394, 40), (394, 66), (380, 66)], 22, bevel=2)
    g.cut(fs, g.cutter("box", (0, 387, 60), (14, 30, 12)))
    g.tube(sights, (0, 387, 48), (0, 387, 62), 1.4, segments=8)

    # --- stock -------------------------------------------------------------
    g.tube(tube, (0, -102, -6), (0, -285, -6), 15, segments=24)
    for y in range(-275, -190, 12):  # adjustment holes along the bottom
        g.box(tube, (0, y, -20.5), (8, 4, 2), bevel=0.4, segments=1)
    s = g.slab(stock, [(-195, 22), (-195, -24), (-212, -34), (-300, -72), (-332, -76), (-338, -70),
                       (-338, 26), (-330, 32), (-212, 32)], 42, bevel=5, segments=3)
    g.taper(s, 1, [(-338, 1.0), (-195, 0.82)])
    g.cut(s, g.cutter("slab", [(-240, -26), (-300, -54), (-300, -40), (-246, -18)], 60))  # sling cut-out
    g.slab(stock, [(-338, 26), (-338, -70), (-350, -72), (-350, 28)], 44, bevel=3)  # butt pad
    g.box(stock, (0, -230, -32), (14, 30, 8), bevel=2)  # adjustment lever

    # --- grip and controls ------------------------------------------------
    gr = g.slab(grip, [(-48, -36), (-94, -34), (-102, -60), (-132, -148), (-128, -158), (-102, -160),
                       (-92, -150), (-80, -112), (-70, -104), (-66, -82), (-56, -62)], 28, bevel=7, segments=3)
    g.taper(gr, 2, [(-160, 1.05), (-40, 0.9)])

    tg = g.slab(guard, [(-50, -44), (-46, -70), (-38, -76), (20, -76), (24, -68), (24, -44)], 10, bevel=1.5)
    g.cut(tg, g.cutter("slab", [(-42, -30), (-40, -66), (16, -66), (18, -60), (18, -30)], 14))
    g.slab(trigger, [(-10, -46), (-2, -46), (-6, -60), (-14, -68), (-19, -66), (-12, -56)], 6, bevel=1.2)
    g.slab(selector, [(-46, -26), (-32, -22), (-22, -24), (-24, -30), (-36, -32)], 3, x=15.5, bevel=0.8)
    g.tube(selector, (14, -38, -28), (17, -38, -28), 5, segments=14, bevel=0.5)

    g.box(bolt, (0, 40, 0), (20, 76, 14), bevel=1.5)
    g.slab(charging, [(-110, 14), (-92, 14), (-92, 22), (-110, 22)], 22, bevel=1)
    g.slab(charging, [(-114, 12), (-104, 12), (-104, 24), (-114, 24)], 54, bevel=2.5, segments=3)  # T-handle

    # --- magazine: 30-round STANAG, slight curve low down -----------------
    radius, top, length, steps = 820, (67, -40), 206, 20
    span = length / radius
    centre = [
        (top[0] + radius * (1 - math.cos(span * i / steps)), top[1] - radius * math.sin(span * i / steps))
        for i in range(steps + 1)
    ]
    g.sweep(magazine, centre, lambda t: 31 - 1.5 * t, 23, bevel=2)
    for d in (-17, 0, 17):  # pressed ribs down each side
        rib = [(y + d * math.cos(span * i / steps), z - d * math.sin(span * i / steps) * 0 + 0)
               for i, (y, z) in enumerate(centre[5:-2], 5)]
        g.sweep(magazine, rib, lambda t: 1.6, 24.6, bevel=0.6)
    g.sweep(magazine, centre[-2:], lambda t: 33, 27, bevel=2.5)  # floor plate

    return GRIP, MUZZLE
