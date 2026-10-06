"""FAMAS F1, modelled from published dimensions.

Bullpup: the 25-round magazine sits behind the pistol grip. Long carry handle
over the body with the charging handle under it, full-length hand guard in
front of the grip, folding bipod legs along the sides. Overall 757 mm, barrel
488 mm. Millimetres, bore on the Y axis, +Y toward the muzzle, +Z up, +X right.
"""

NAME = "FAMAS"
STUDS_PER_METRE = 5.5
GRIP = (0, -42, -96)
MUZZLE = (0, 457, 0)


def build(g):
    body = g.part("Body", "Polymer")
    handle = g.part("CarryHandle", "Polymer")
    barrel = g.part("Barrel", "Steel")
    sights = g.part("Sights", "Steel")
    bipod = g.part("Bipod", "Steel")
    grip = g.part("Grip", "Polymer")
    guard = g.part("HandGuard", "Polymer")
    pad = g.part("ButtPad", "Polymer")
    trigger = g.part("Trigger", "Steel", group="Trigger")
    magazine = g.part("Magazine", "Steel", group="Magazine")
    charging = g.part("ChargingHandle", "Steel", group="ChargingHandle")
    bolt = g.part("Bolt", "Bare", group="Bolt")

    # --- body: butt to handguard in one moulding -------------------------
    b = g.slab(body, [(-300, 26), (-300, -88), (-292, -96), (-205, -82), (-196, -40), (270, -40), (292, -24),
                      (300, 0), (300, 26)], 52, bevel=6, segments=3)
    g.taper(b, 1, [(-300, 1.0), (-120, 1.0), (300, 0.8)])
    g.cut(b, g.cutter("box", (22, -118, 8), (16, 64, 16)))  # ejection port, right
    g.cut(b, g.cutter("box", (0, -150, -64), (26, 64, 50)))  # magazine well
    for y in range(40, 270, 26):  # handguard vents
        g.cut(b, g.cutter("box", (0, y, -18), (70, 12, 20)))
    g.slab(body, [(-292, 26), (-150, 26), (-160, 36), (-286, 36)], 40, bevel=5)  # cheek rest
    g.slab(pad, [(-300, 28), (-300, -88), (-310, -92), (-310, 30)], 50, bevel=4, segments=3)

    # --- carry handle with the sights at each end -----------------------
    h = g.slab(handle, [(-238, 24), (-238, 62), (-222, 82), (142, 82), (162, 62), (168, 24), (138, 24),
                        (128, 60), (-206, 60), (-212, 24)], 22, bevel=4, segments=3)
    g.cut(h, g.cutter("box", (0, -226, 70), (8, 10, 14)))  # rear aperture slot
    for sign in (1, -1):  # front sight ears
        g.slab(sights, [(146, 82), (146, 98), (154, 102), (162, 96), (162, 82)], 4, x=sign * 8, bevel=1)
    g.tube(sights, (0, 154, 80), (0, 154, 96), 1.5, segments=8)
    g.slab(sights, [(-234, 82), (-216, 82), (-218, 92), (-232, 92)], 18, bevel=1.5)

    g.slab(charging, [(60, 26), (80, 26), (84, 48), (64, 52)], 14, bevel=2)

    # --- barrel and grenade-launcher sleeve -----------------------------
    g.lathe(barrel, [(0, 0), (0, 10), (122, 9), (122, 0)], (0, 298, 0))
    g.lathe(barrel, [(0, 0), (0, 11), (2, 11.8), (6, 11.8), (8, 11), (14, 11), (16, 11.8), (20, 11.8),
                     (22, 11), (34, 11), (36, 9.5), (37, 0)], (0, 420, 0), segments=28)
    g.cut(g.shapes[-1][0], g.cutter("tube", (0, 410, 0), (0, 470, 0), 5, segments=16))

    # --- bipod legs folded along the sides --------------------------------
    for sign in (1, -1):
        g.tube(bipod, (sign * 25, 40, -16), (sign * 25, 286, -16), 3.8, segments=12)
        g.box(bipod, (sign * 25, 290, -18), (9, 10, 14), bevel=1.5)
    g.slab(bipod, [(280, -20), (294, -20), (294, -8), (280, -8)], 52, bevel=1.5)

    # --- grip, full-length hand guard, trigger -------------------------
    gr = g.slab(grip, [(-8, -36), (-50, -36), (-58, -60), (-74, -140), (-70, -152), (-42, -154), (-34, -146),
                       (-18, -80), (-10, -58)], 30, bevel=7, segments=3)
    g.taper(gr, 2, [(-154, 1.05), (-36, 0.92)])
    g.slab(guard, [(-6, -38), (8, -38), (22, -60), (16, -128), (-28, -158), (-44, -158), (-40, -146),
                   (2, -122), (8, -62)], 12, bevel=2.5)
    g.slab(trigger, [(-2, -42), (6, -42), (2, -56), (-6, -66), (-11, -64), (-4, -52)], 6, bevel=1.2)

    g.box(bolt, (0, -118, 8), (36, 62, 14), bevel=1.5)

    # --- magazine: 25-round, straight ---------------------------------
    g.slab(magazine, [(-182, -30), (-118, -30), (-118, -176), (-182, -176)], 25, bevel=2.5)
    for y in (-170, -150, -130):  # pressed ribs
        g.slab(magazine, [(y - 3, -100), (y + 3, -100), (y + 3, -168), (y - 3, -168)], 26.6, bevel=0.8)
    g.slab(magazine, [(-186, -172), (-114, -172), (-114, -184), (-186, -184)], 28, bevel=2.5)

    return GRIP, MUZZLE
