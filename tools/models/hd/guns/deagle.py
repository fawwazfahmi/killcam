"""Desert Eagle, modelled from published dimensions.

Fixed barrel with its wedge-shaped top and scope rail, a short slide at the
rear whose arms run forward under the barrel, a deep frame with a big squared
trigger guard, exposed spur hammer, slide-mounted safety and broad grip
panels. Overall 273 mm, barrel 152 mm. Millimetres, bore on the Y axis, +Y
toward the muzzle, +Z up, +X right.
"""

from kit import rail

NAME = "Deagle"
STUDS_PER_METRE = 5.5
GRIP = (0, -72, -84)
MUZZLE = (0, 168, 0)


def build(g):
    barrel = g.part("Barrel", "Steel")
    rails = g.part("Rail", "Steel")
    slide = g.part("Slide", "Steel", group="Slide")
    sights = g.part("Sights", "Steel", group="Slide")
    frame = g.part("Frame", "Steel")
    grips = g.part("Grip", "Polymer")
    controls = g.part("Controls", "Steel")
    hammer = g.part("Hammer", "Steel", group="Hammer")
    trigger = g.part("Trigger", "Bare", group="Trigger")
    magazine = g.part("Magazine", "Bare", group="Magazine")

    # --- barrel: flat-sided below, narrowing to a rib on top -----------------
    b = g.slab(barrel, [(14, -8), (168, -8), (168, 10), (163, 17), (14, 17)], 31, bevel=1.4)
    g.taper(b, 2, [(-8, 1.0), (2, 1.0), (17, 0.46)])
    g.cut(b, g.cutter("tube", (0, 140, 0), (0, 172, 0), 6.6, segments=20))
    rail(g, rails, 30, 150, (0, 17), width=13)
    g.slab(sights, [(152, 17), (166, 17), (164, 23), (156, 23)], 4, bevel=0.6)  # front sight on the barrel

    # --- slide: the block behind the barrel, and its arms beneath it -------------
    s = g.slab(slide, [(-106, -12), (14, -12), (14, 17), (-100, 17), (-106, 11)], 32, bevel=1.6)
    g.taper(s, 2, [(-12, 1.0), (4, 1.0), (17, 0.62)])
    g.cut(s, g.cutter("box", (10, -14, 12), (16, 34, 14)))  # ejection port
    for k in range(6):  # raked grooves either side at the rear
        for sign in (1, -1):
            g.cut(s, g.cutter("slab", [(-98 + k * 6, -9), (-95.4 + k * 6, -9), (-91.4 + k * 6, 6), (-94 + k * 6, 6)], 2.4,
                              x=sign * 15.6))
    g.slab(slide, [(14, -14), (152, -14), (152, -6), (14, -6)], 34, bevel=1.2)
    for sign in (1, -1):  # safety lever, one each side
        g.slab(controls, [(-92, 4), (-70, 6), (-68, 10), (-90, 11)], 3, x=sign * 15.2, bevel=0.8)
    rear = g.slab(sights, [(-102, 17), (-88, 17), (-90, 22.5), (-102, 22.5)], 16, bevel=0.8)
    g.cut(rear, g.cutter("box", (0, -97, 22), (4, 18, 4)))

    # --- frame ---------------------------------------------------------------
    f = g.slab(frame, [(-112, -12), (154, -12), (154, -22), (146, -30), (58, -30), (52, -27), (-28, -27), (-33, -60),
                       (-44, -128), (-116, -126), (-108, -92), (-102, -52), (-104, -32), (-114, -22)], 30, bevel=2.2)
    guard = g.slab(frame, [(-33, -26), (52, -26), (59, -34), (59, -60), (51, -69), (-40, -69)], 15, bevel=2.4)
    g.cut(guard, g.cutter("slab", [(-25, -32.5), (49, -32.5), (52.5, -37), (52.5, -57), (47, -62.5), (-32, -62.5)], 24))
    # Grip panels, one moulding wrapped round the frame.
    g.slab(grips, [(-98, -40), (-36, -40), (-47, -122), (-112, -120), (-106, -92), (-100, -58)], 37, bevel=4, segments=3)
    g.tube(controls, (-19, -74, -80), (19, -74, -80), 3, segments=12)  # grip screw

    # --- hammer, controls, trigger ----------------------------------------------
    g.slab(hammer, [(-114, -8), (-106, -8), (-104, 8), (-110, 13), (-120, 11), (-118, 5), (-112, 3)], 8, bevel=1.4)
    g.slab(controls, [(-22, -13), (10, -13), (10, -17), (-22, -19)], 2.4, x=-16.2, bevel=0.6)  # slide stop
    g.tube(controls, (-17.5, -34, -42), (-14, -34, -42), 4.4, segments=14)  # magazine release
    g.slab(trigger, [(6, -30), (14, -30), (13, -44), (7, -56), (2, -55), (7, -44)], 8, bevel=1.4)

    # --- magazine ---------------------------------------------------------------
    g.slab(magazine, [(-100, -34), (-48, -34), (-52, -128), (-112, -126)], 20, bevel=1.4)
    g.slab(magazine, [(-118, -126), (-44, -128), (-43, -135), (-118, -133)], 31, bevel=2)

    return GRIP, MUZZLE
