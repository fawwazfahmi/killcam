"""Glock 21, modelled from published dimensions.

Square-sided slide with rear grip grooves and an open ejection port, polymer
frame with a raked grip and a squared, hooked trigger guard, a single
accessory slot under the dust cover, no external hammer. Overall 205 mm,
barrel 117 mm, slide 28.5 mm wide. Millimetres, bore on the Y axis, +Y toward
the muzzle, +Z up, +X right.
"""

NAME = "Glock21"
STUDS_PER_METRE = 5.5
GRIP = (0, -70, -78)
MUZZLE = (0, 119, 0)


def build(g):
    slide = g.part("Slide", "Steel", group="Slide")
    sights = g.part("Sights", "Steel", group="Slide")
    barrel = g.part("Barrel", "Bare")
    frame = g.part("Frame", "Polymer")
    panels = g.part("GripPanels", "Polymer")
    controls = g.part("Controls", "Steel")
    trigger = g.part("Trigger", "Polymer", group="Trigger")
    magazine = g.part("Magazine", "Polymer", group="Magazine")

    # --- slide ---------------------------------------------------------------
    s = g.slab(slide, [(-78, -10), (116, -10), (116, 7), (111, 12), (-78, 12)], 28.5, bevel=1.6)
    g.cut(s, g.cutter("box", (9, 38, 9), (16, 36, 12)))  # ejection port, top right
    for k in range(7):  # grip grooves either side at the rear
        for sign in (1, -1):
            g.cut(s, g.cutter("box", (sign * 14.6, -70 + k * 5.5, 1), (1.8, 2.6, 17)))
    g.cut(s, g.cutter("tube", (0, 100, 0), (0, 120, 0), 8.2, segments=20))  # barrel opening
    g.cut(s, g.cutter("tube", (0, 100, -6.5), (0, 120, -6.5), 3.6, segments=14))  # guide rod opening

    g.box(sights, (0, 106, 13.5), (3.6, 7, 3.5), bevel=0.6)
    rear = g.slab(sights, [(-74, 12), (-62, 12), (-62, 17.5), (-74, 17.5)], 20, bevel=0.8)
    g.cut(rear, g.cutter("box", (0, -68, 17), (4.2, 16, 4)))

    # --- barrel and guide rod ------------------------------------------------
    b = g.tube(barrel, (0, 14, 0), (0, 119, 0), 7.2, segments=24)
    g.cut(b, g.cutter("tube", (0, 90, 0), (0, 122, 0), 5.7, segments=18))
    g.box(barrel, (2, 38, 4), (17, 34, 13), bevel=1)  # the chamber, seen through the port
    g.tube(barrel, (0, 60, -6.5), (0, 117, -6.5), 3, segments=14)

    # --- frame: dust cover and grip in one moulding ----------------------------
    f = g.slab(frame, [(-87, -10), (113, -10), (113, -21), (109, -25), (50, -25), (46, -22), (-27, -22), (-31, -44),
                       (-44, -88), (-58, -127), (-110, -123), (-102, -98), (-91, -62), (-84, -38), (-89, -24)],
               30, bevel=3, segments=3)
    g.taper(f, 2, [(-127, 1.06), (-50, 1.06), (-24, 1.0)])  # the grip is a little wider than the dust cover
    g.cut(f, g.cutter("box", (0, 84, -25.5), (40, 4.5, 3)))  # accessory slot
    # Roughened panels standing just proud of each side of the grip.
    g.slab(panels, [(-80, -52), (-41, -52), (-57, -118), (-102, -115), (-93, -84)], 33.4, bevel=0.7)

    guard = g.slab(frame, [(-32, -21), (49, -21), (52.5, -26), (52.5, -57), (47, -63.5), (-40, -63.5)], 16, bevel=2.2)
    g.cut(guard, g.cutter("slab", [(-24, -27.5), (44, -27.5), (44, -53), (40, -57), (-31, -57)], 24))

    # --- controls ------------------------------------------------------------
    g.slab(controls, [(-22, -12), (6, -12), (6, -15.5), (-22, -17)], 2.2, x=-16, bevel=0.6)  # slide stop
    g.box(controls, (0, 30, -17.5), (33, 7, 4), bevel=0.8)  # takedown tabs
    g.box(controls, (-16.4, -34, -37), (3, 9, 9), bevel=1.2)  # magazine release
    g.slab(trigger, [(4, -27), (12, -27), (10.5, -40), (4, -52), (0.5, -50), (5, -40)], 7, bevel=1.2)

    # --- magazine --------------------------------------------------------------
    g.slab(magazine, [(-90, -30), (-60, -30), (-66, -124), (-106, -122)], 22, bevel=1.5)
    g.slab(magazine, [(-113, -121.5), (-58, -126), (-56.5, -133), (-112.5, -129.5)], 33, bevel=2.2)

    return GRIP, MUZZLE
