"""AS Val, modelled from published dimensions.

Integrally suppressed: the suppressor sleeve starts right in front of the
handguard and carries the front sight. Kalashnikov-pattern receiver and
controls, skeleton side-folding stock, 20-round 9x39 magazine. Overall 875 mm
with the stock open. Millimetres, bore on the Y axis, +Y toward the muzzle, +Z
up, +X right.
"""

from kit import arc

NAME = "ASVal"
STUDS_PER_METRE = 5.5
GRIP = (0, -88, -96)
MUZZLE = (0, 482, 0)


def build(g):
    receiver = g.part("Receiver", "Steel")
    cover = g.part("DustCover", "Steel")
    suppressor = g.part("Suppressor", "Steel")
    handguard = g.part("Handguard", "Polymer")
    sights = g.part("Sights", "Steel")
    stock = g.part("Stock", "Steel")
    pad = g.part("ButtPad", "Polymer")
    grip = g.part("Grip", "Polymer")
    guard = g.part("TriggerGuard", "Steel")
    trigger = g.part("Trigger", "Steel", group="Trigger")
    selector = g.part("Selector", "Steel", group="Selector")
    magazine = g.part("Magazine", "Polymer", group="Magazine")
    bolt = g.part("Bolt", "Bare", group="Bolt")

    # --- receiver --------------------------------------------------------
    body = g.slab(receiver, [(-112, 8), (132, 8), (132, -42), (-62, -42), (-92, -38), (-112, -28)], 30, bevel=1.2)
    g.cut(body, g.cutter("box", (14, 50, 0), (14, 70, 14)))
    for y, z in [(118, -10), (122, -30), (-100, -8), (-96, -24), (-26, -28), (-4, -32)]:
        g.tube(receiver, (-15.6, y, z), (15.6, y, z), 2.3, segments=10)
    g.slab(cover, [(-118, 8), (-118, 20), (-114, 26), (126, 26), (132, 18), (132, 8)], 31, bevel=5, segments=4)
    g.tube(cover, (0, -124, 16), (0, -114, 16), 4.2, segments=14, bevel=0.8)

    # Rear sight on the front of the receiver.
    g.slab(sights, [(132, 6), (132, 26), (140, 32), (176, 32), (180, 6)], 24, bevel=2)
    g.slab(sights, [(140, 32), (140, 37), (178, 40), (178, 35)], 16, bevel=0.8)

    # --- handguard and suppressor --------------------------------------
    g.slab(handguard, [(176, 8), (176, -40), (186, -44), (212, -44), (220, -36), (220, 8)], 44, bevel=10, segments=4)
    rings = [(0, 0), (0, 22.5)]
    for k in range(7):  # shallow grooves along the sleeve
        t = 30 + k * 34
        rings += [(t, 22.5), (t + 1, 21.2), (t + 5, 21.2), (t + 6, 22.5)]
    rings += [(258, 22.5), (264, 19), (266, 0)]
    can = g.lathe(suppressor, rings, (0, 216, 0), segments=32)
    g.cut(can, g.cutter("tube", (0, 470, 0), (0, 490, 0), 6, segments=16))
    g.slab(sights, [(424, 20), (424, 44), (432, 50), (448, 50), (452, 20)], 14, bevel=2)
    for sign in (1, -1):
        g.slab(sights, [(430, 44), (430, 62), (438, 66), (448, 62), (448, 44)], 3, x=sign * 8, bevel=0.8)
    g.tube(sights, (0, 439, 48), (0, 439, 62), 1.5, segments=8)

    # --- skeleton stock folded open ------------------------------------
    g.slab(stock, [(-112, 6), (-112, -30), (-128, -30), (-128, 6)], 26, bevel=2)
    g.tube(stock, (0, -126, -2), (0, -384, -16), 6.5, segments=14)
    g.tube(stock, (0, -126, -26), (0, -384, -124), 6.5, segments=14)
    g.slab(stock, [(-380, -2), (-380, -132), (-392, -132), (-392, -2)], 16, bevel=3)
    g.slab(pad, [(-390, 4), (-390, -138), (-400, -138), (-400, 4)], 34, bevel=4, segments=3)

    # --- grip and controls ---------------------------------------------
    gr = g.slab(grip, [(-50, -36), (-96, -36), (-104, -60), (-128, -146), (-124, -154), (-96, -156),
                       (-88, -148), (-64, -78), (-54, -56)], 30, bevel=8, segments=3)
    g.taper(gr, 2, [(-156, 1.06), (-36, 0.9)])
    tg = g.slab(guard, [(-56, -38), (-52, -56), (-42, -74), (-34, -78), (14, -78), (20, -72), (20, -38)], 10, bevel=1.5)
    g.cut(tg, g.cutter("slab", [(-46, -28), (-44, -54), (-36, -69), (10, -69), (14, -64), (14, -28)], 14))
    g.slab(trigger, [(-10, -40), (-2, -40), (-6, -56), (-16, -68), (-22, -67), (-14, -54)], 6, bevel=1.2)
    g.slab(selector, [(-100, -16), (-96, -4), (4, -4), (14, -8), (18, -22), (10, -24), (4, -14), (-92, -18)],
           2.4, x=16.2, bevel=0.8)
    g.tube(selector, (14.5, -96, -10), (18, -96, -10), 5.2, segments=16, bevel=0.6)
    g.box(bolt, (0, 50, 0), (22, 76, 14), bevel=1)
    g.tube(bolt, (10, 92, 2), (30, 92, 4), 4.2, segments=12)
    g.lathe(bolt, [(0, 0), (0, 7), (5, 7.6), (9, 6.4), (10.5, 0)], (28, 92, 3.8), direction=(1, 0, 0.1), segments=18)

    # --- magazine: 20-round 9x39, slight curve -----------------------
    centre = arc((50, -22), 700, 172, 18)
    g.sweep(magazine, centre, lambda t: 31 - 2 * t, 27, bevel=2.5)
    g.sweep(magazine, centre[3:-3], lambda t: 5, 29, bevel=1)
    g.sweep(magazine, centre[-2:], lambda t: 33, 30, bevel=2.5)
    g.box(magazine, (0, 84, -34), (10, 8, 10), bevel=1)

    return GRIP, MUZZLE
