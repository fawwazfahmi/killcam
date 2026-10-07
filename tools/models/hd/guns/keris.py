"""A keris: the wavy-bladed dagger of the Malay world. An original design in
the traditional form: a blade of nine waves narrowing to a point, with a
raised spine down its middle; the ganja, the wide asymmetrical base it grows
from; a ringed metal collar; and a carved hilt bent over like a pistol grip.
Overall 400 mm, blade 310 mm.

The blade lies on the Y axis pointing toward +Y. Millimetres, +Z up, +X
right. `MUZZLE` is the tip.
"""

import math

NAME = "Keris"
STUDS_PER_METRE = 5.5
GRIP = (0, -50, -15)
MUZZLE = (0, 330, 0)

WAVES = 4.5  # nine bends: the blade crosses its own line nine times
STEPS = 72


def build(g):
    blade = g.part("Blade", "Steel")
    ganja = g.part("Ganja", "Steel")
    collar = g.part("Collar", "Bare")
    hilt = g.part("Hilt", "Wood")

    # --- blade: a wave that dies away toward the point -------------------------
    centre = []
    for i in range(STEPS + 1):
        t = i / STEPS
        centre.append((20 + 310 * t, 9 * (1 - 0.55 * t) * math.sin(2 * math.pi * WAVES * t)))
    g.sweep(blade, centre, lambda t: 14.5 * (1 - t) ** 0.8 + 0.5, 4.6, bevel=1.1)
    g.sweep(blade, centre, lambda t: 2.2 * (1 - t) + 0.4, 7, bevel=0.6)  # the spine standing proud of each face

    # --- ganja: the base, longer on one side and hooked on the other ---------------
    g.slab(ganja, [(6, -34), (15, -38), (25, -18), (26, 15), (20, 24), (12, 30), (6, 22)], 7, bevel=1.2)
    g.slab(blade, [(18, -17), (40, -15), (40, 15), (18, 17)], 5.4, bevel=1)  # the blade's root, wider than the rest

    # --- collar and hilt ----------------------------------------------------------
    g.lathe(collar, [(0, 0), (0, 7.5), (2, 9.5), (4, 7.5), (6, 10.5), (9, 10.5), (11, 8), (11, 0)], (0, -5, 0), segments=28)
    radius = 80
    bend = [(-4 - radius * math.sin(a), -radius * (1 - math.cos(a))) for a in (1.25 * i / 24 for i in range(25))]
    h = g.sweep(hilt, bend, lambda t: 9.5 + 4.5 * math.sin(math.pi * t) + 5 * t * t, 21, bevel=7, segments=3)
    g.taper(h, 1, [(-90, 1.15), (-40, 0.9), (0, 0.8)])
    # Carved bands across the grip.
    for a in (0.42, 0.62, 0.82):
        y, z = -4 - radius * math.sin(a), -radius * (1 - math.cos(a))
        g.tube(hilt, (-11.5, y, z), (11.5, y, z), 4.2, segments=14, bevel=0.8)

    return GRIP, MUZZLE
