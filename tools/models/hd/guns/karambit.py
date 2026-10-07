"""A karambit: the claw-shaped knife of Southeast Asia. An original design in
the usual modern form: handle and blade follow one curve, the blade hooking
forward and down to a point, with a finger ring at the heel of the handle.
Overall about 190 mm along the curve.

Laid out so the handle sits where a gun's grip would: the curve runs forward
along +Y and bends down. Millimetres, +Z up, +X right. `MUZZLE` is the tip.
"""

import math

NAME = "Karambit"
STUDS_PER_METRE = 5.5

RADIUS = 62  # of the curve handle and blade both follow
CENTRE = (10, -56)  # its centre, as (forward, up)


def on_curve(angle):
    """A point on the curve; the angle is 0 where the blade meets the handle
    and grows toward the tip."""
    return CENTRE[0] + RADIUS * math.sin(angle), CENTRE[1] + RADIUS * math.cos(angle)


GRIP = (0, *on_curve(-0.62))
MUZZLE = (0, *on_curve(1.72))


def build(g):
    blade = g.part("Blade", "Bare")
    handle = g.part("Handle", "Polymer")
    fittings = g.part("Fittings", "Steel")

    # --- blade: wide at the handle, hooking down to a point ---------------------
    edge = [on_curve(1.72 * i / 40) for i in range(41)]
    b = g.sweep(blade, edge, lambda t: 13 * (1 - t) ** 0.75 + 0.35, 4.2, bevel=0.6)
    g.cut(b, g.cutter("tube", (-5, *on_curve(0.2)), (5, *on_curve(0.2)), 3.2, segments=14))  # thumb hole

    # --- handle: the same curve, the other way ---------------------------------
    grip = [on_curve(-1.2 * i / 24) for i in range(25)]
    h = g.sweep(handle, grip, lambda t: 11 + 1.6 * math.sin(math.pi * t), 15, bevel=4.5, segments=3)
    for angle in (-0.3, -0.6, -0.9):  # finger grooves along the inside of the curve
        y, z = on_curve(angle)
        inward = ((CENTRE[0] - y) / RADIUS, (CENTRE[1] - z) / RADIUS)
        g.cut(h, g.cutter("tube", (-12, y + inward[0] * 13.5, z + inward[1] * 13.5),
                          (12, y + inward[0] * 13.5, z + inward[1] * 13.5), 5.2, segments=16))

    # --- finger ring at the heel, and the screws that hold the scales ---------------
    heel = on_curve(-1.2)
    back = (-math.cos(-1.2), math.sin(-1.2))  # the way the handle is heading as it ends
    centre = (heel[0] + back[0] * 15, heel[1] + back[1] * 15)
    ring = g.tube(fittings, (-4.5, *centre), (4.5, *centre), 17, segments=36, bevel=1)
    g.cut(ring, g.cutter("tube", (-7, *centre), (7, *centre), 11.5, segments=28))
    for angle in (-0.12, -1.0):
        y, z = on_curve(angle)
        g.tube(fittings, (-8.2, y, z), (8.2, y, z), 2.6, segments=12, bevel=0.4)

    return GRIP, MUZZLE
