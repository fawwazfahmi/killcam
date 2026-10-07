"""P2020: a compact double-action service pistol, in the manner of the polymer
9 mm sidearms of the 2000s. An original design; dimensions are typical of the
type rather than taken from one gun.

Stainless slide with a stepped, lightened front and grooves fore and aft,
exposed hammer, decocking lever, polymer frame with a rounded trigger guard,
an accessory rail and a magazine with a finger rest. Overall 187 mm, barrel
98 mm. Millimetres, bore on the Y axis, +Y toward the muzzle, +Z up, +X right.
"""

NAME = "P2020"
STUDS_PER_METRE = 5.5
GRIP = (0, -64, -76)
MUZZLE = (0, 110, 0)


def build(g):
    slide = g.part("Slide", "Bare", group="Slide")
    sights = g.part("Sights", "Steel", group="Slide")
    barrel = g.part("Barrel", "Steel")
    frame = g.part("Frame", "Polymer")
    panels = g.part("GripPanels", "Polymer")
    controls = g.part("Controls", "Steel")
    hammer = g.part("Hammer", "Steel", group="Hammer")
    trigger = g.part("Trigger", "Steel", group="Trigger")
    magazine = g.part("Magazine", "Steel", group="Magazine")

    # --- slide: rounded on top, stepped in at the front ----------------------
    s = g.slab(slide, [(-74, -9), (106, -9), (106, 5), (99, 13), (-70, 13), (-74, 8)], 29, bevel=3, segments=3)
    g.cut(s, g.cutter("box", (9, 30, 10), (16, 32, 12)))  # ejection port
    for sign in (1, -1):
        g.cut(s, g.cutter("box", (sign * 15, 62, 3), (2.4, 64, 13)))  # lightening step
        for k in range(6):
            g.cut(s, g.cutter("box", (sign * 14.8, -68 + k * 5, 2), (1.8, 2.4, 16)))  # rear grooves
        for k in range(4):
            g.cut(s, g.cutter("box", (sign * 13.9, 84 + k * 5, 3), (1.6, 2.4, 11)))  # front grooves
    g.cut(s, g.cutter("tube", (0, 92, 0), (0, 110, 0), 7.6, segments=20))

    g.slab(sights, [(88, 13), (98, 13), (96, 17), (90, 17)], 3.6, bevel=0.5)
    rear = g.slab(sights, [(-70, 13), (-58, 13), (-60, 18), (-70, 18)], 19, bevel=0.8)
    g.cut(rear, g.cutter("box", (0, -66, 17.5), (4.2, 16, 4)))

    # --- barrel -------------------------------------------------------------
    b = g.tube(barrel, (0, 12, 0), (0, 110, 0), 6.8, segments=24)
    g.cut(b, g.cutter("tube", (0, 84, 0), (0, 113, 0), 4.6, segments=18))
    g.box(barrel, (2, 30, 4.5), (17, 30, 13), bevel=1)  # chamber, seen through the port

    # --- frame ---------------------------------------------------------------
    f = g.slab(frame, [(-83, -9), (104, -9), (104, -19), (100, -24), (44, -24), (40, -20), (-25, -20), (-29, -44),
                       (-39, -84), (-50, -121), (-101, -117), (-95, -92), (-87, -58), (-83, -36), (-90, -26),
                       (-90, -16)], 30, bevel=3, segments=3)
    g.taper(f, 2, [(-121, 1.08), (-48, 1.08), (-22, 1.0)])
    for y in (60, 72, 84):  # accessory rail slots
        g.cut(f, g.cutter("box", (0, y, -24.5), (40, 4, 3)))
    g.slab(panels, [(-76, -48), (-38, -48), (-51, -112), (-95, -109), (-88, -80)], 33.6, bevel=0.7)

    guard = g.slab(frame, [(-30, -19), (40, -19), (47, -30), (45, -47), (35, -60), (-36, -60)], 15, bevel=2.4)
    g.cut(guard, g.cutter("slab", [(-23, -25.5), (36, -25.5), (40.5, -32), (39, -45), (31, -54), (-29, -54)], 24))

    # --- hammer and controls ---------------------------------------------------
    h = g.slab(hammer, [(-84, -6), (-76, -6), (-75, 9), (-80, 15), (-88, 13), (-86, 4)], 8, bevel=1.4)
    g.cut(h, g.cutter("tube", (-6, -82, 9), (6, -82, 9), 2.2, segments=12))
    g.slab(controls, [(-56, -11), (-34, -11), (-36, -16), (-52, -18), (-58, -15)], 2.6, x=-16.2, bevel=0.7)  # decocker
    g.slab(controls, [(-28, -11), (-4, -11), (-4, -14.5), (-28, -16)], 2.2, x=-16, bevel=0.6)  # slide stop
    g.box(controls, (0, 24, -15), (33, 6, 4), bevel=0.8)  # takedown lever
    g.tube(controls, (-17.5, -30, -34), (-14, -30, -34), 4.2, segments=14)  # magazine release
    g.slab(trigger, [(6, -24), (13, -24), (13, -36), (8, -47), (2, -50), (1, -46), (6, -38)], 7, bevel=1.4)

    # --- magazine, with a finger rest --------------------------------------------
    g.slab(magazine, [(-86, -28), (-58, -28), (-60, -118), (-98, -116)], 21, bevel=1.5)
    g.slab(magazine, [(-104, -115.5), (-50, -119.5), (-40, -124), (-42, -130), (-103, -126)], 33, bevel=2.4)

    return GRIP, MUZZLE
