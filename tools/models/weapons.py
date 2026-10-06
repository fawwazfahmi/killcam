"""Original weapon designs for TDM Core.

Slab-sided stamped steel with chamfered edges and near-black furniture. The
amber accent marks what the hand touches or the eye checks.

Each weapon is a list of (palette key, piece). Coordinates are weapon space in
studs: grip at the origin, +Y up, barrel along -Z, +X to the holder's right.
Profiles for `extrude` are side views given as (forward, up).
"""

from meshkit import box, cylinder, extrude


def at(forward, up, x=0.0):
    return (x, up, -forward)


def bars(forwards, up, width, height, depth=0.07, key="Accent"):
    """The three-bar mark: slim blocks standing just proud of both sides."""
    return [(key, box(at(f, up), (width, height, depth))) for f in forwards]


def trigger_group(guard_key, bar_forward, bar_up, bar_length, post_height, trigger_forward):
    front = bar_forward + bar_length / 2
    return [
        (guard_key, box(at(bar_forward, bar_up), (0.09, 0.04, bar_length))),
        (guard_key, box(at(front, bar_up + post_height / 2), (0.09, post_height, 0.04))),
        ("Accent", box(at(trigger_forward, bar_up + 0.09), (0.05, 0.14, 0.05))),
    ]


def rifle():
    """KR-9 Carbine: a bridge rail over the receiver and a raked magazine."""
    parts = [
        ("Steel", extrude([(-0.75, 0.36), (1.35, 0.36), (1.35, 0.84), (-0.75, 0.84)], 0.34, 0.04)),
        ("Dark", extrude([(1.35, 0.36), (2.3, 0.42), (2.5, 0.56), (2.5, 0.80), (1.35, 0.82)], 0.38, 0.05)),
        ("Bare", cylinder(at(2.45, 0.6), at(3.0, 0.6), 0.07)),
        ("Steel", cylinder(at(2.84, 0.6), at(3.1, 0.6), 0.1, segments=8)),
        # Bridge rail: stands on two feet, open underneath.
        ("Dark", extrude(
            [(-0.3, 0.8), (-0.15, 0.8), (-0.05, 0.98), (1.6, 0.98), (1.7, 0.8),
             (1.85, 0.8), (1.72, 1.08), (-0.17, 1.08)],
            0.16, 0.02,
        )),
        ("Dark", box(at(1.6, 1.13), (0.04, 0.1, 0.05))),
        ("Glow", box(at(1.6, 1.2), (0.05, 0.05, 0.05))),
        ("Glow", box(at(-0.1, 1.11, 0.05), (0.04, 0.06, 0.05))),
        ("Glow", box(at(-0.1, 1.11, -0.05), (0.04, 0.06, 0.05))),
        ("Dark", extrude([(-0.12, 0.38), (0.22, 0.38), (0.04, -0.48), (-0.32, -0.48)], 0.28, 0.05)),
        ("Dark", extrude([(0.75, 0.4), (1.15, 0.4), (1.35, -0.45), (0.95, -0.5)], 0.24, 0.04)),
        ("Accent", extrude([(0.93, -0.5), (1.37, -0.45), (1.38, -0.53), (0.92, -0.58)], 0.27, 0.02)),
        ("Dark", extrude(
            [(-0.7, 0.44), (-0.7, 0.78), (-1.72, 0.84), (-1.76, 0.08), (-1.52, 0.08), (-1.38, 0.46)],
            0.26, 0.05,
        )),
        ("Steel", box(at(-1.78, 0.46), (0.3, 0.82, 0.07))),
        # Right-hand side only: charging handle and ejection port.
        ("Steel", box(at(0.9, 0.74, 0.2), (0.1, 0.06, 0.16))),
        ("Dark", box(at(0.55, 0.68, 0.168), (0.012, 0.14, 0.4))),
    ]
    parts += trigger_group("Steel", 0.42, 0.2, 0.42, 0.18, 0.34)
    parts += bars((1.62, 1.86, 2.1), 0.62, 0.4, 0.18)
    return parts, at(3.1, 0.6)


def sniper():
    """Vantage Bolt: open-frame stock, long tapered barrel, amber lens."""
    parts = [
        ("Steel", extrude([(-0.6, 0.36), (1.4, 0.36), (1.4, 0.78), (-0.6, 0.78)], 0.32, 0.04)),
        ("Dark", extrude([(1.4, 0.34), (2.6, 0.42), (2.6, 0.66), (1.4, 0.7)], 0.3, 0.05)),
        ("Bare", cylinder(at(1.4, 0.6), at(4.12, 0.6), 0.085, 0.06)),
        ("Steel", box(at(4.25, 0.6), (0.26, 0.16, 0.3))),
        ("Dark", box(at(4.25, 0.6), (0.27, 0.06, 0.1))),
        # Scope
        ("Dark", cylinder(at(-0.4, 1.1), at(-0.1, 1.1), 0.14)),
        ("Dark", cylinder(at(-0.1, 1.1), at(0.05, 1.1), 0.14, 0.11)),
        ("Dark", cylinder(at(0.05, 1.1), at(1.5, 1.1), 0.11)),
        ("Dark", cylinder(at(1.5, 1.1), at(1.9, 1.1), 0.11, 0.17)),
        ("Dark", cylinder(at(1.9, 1.1), at(2.0, 1.1), 0.17)),
        ("Glow", cylinder(at(1.99, 1.1), at(2.01, 1.1), 0.14)),
        ("Steel", box(at(0.3, 0.9), (0.12, 0.24, 0.14))),
        ("Steel", box(at(1.1, 0.9), (0.12, 0.24, 0.14))),
        ("Steel", cylinder(at(0.75, 1.18), at(0.75, 1.32), 0.07, segments=8)),
        ("Steel", cylinder(at(0.75, 1.1, 0.09), at(0.75, 1.1, 0.22), 0.06, segments=8)),
        # Bolt, right-hand side.
        ("Steel", cylinder(at(0.1, 0.66, 0.14), at(0.04, 0.5, 0.4), 0.035, segments=8)),
        ("Accent", box(at(0.03, 0.47, 0.42), (0.11, 0.11, 0.11))),
        ("Dark", extrude([(-0.12, 0.38), (0.22, 0.38), (0.02, -0.5), (-0.34, -0.5)], 0.28, 0.05)),
        ("Dark", extrude([(0.7, 0.38), (1.1, 0.38), (1.1, 0.05), (0.7, 0.02)], 0.22, 0.04)),
        ("Accent", extrude([(0.68, 0.02), (1.12, 0.05), (1.12, -0.02), (0.68, -0.05)], 0.25, 0.02)),
        # Open-frame stock: top bar, diagonal strut, butt plate, cheek rest.
        ("Steel", extrude([(-0.6, 0.62), (-0.6, 0.78), (-1.7, 0.78), (-1.7, 0.62)], 0.2, 0.03)),
        ("Steel", extrude([(-0.6, 0.5), (-0.6, 0.36), (-1.7, -0.06), (-1.7, 0.08)], 0.2, 0.03)),
        ("Dark", extrude([(-1.66, -0.1), (-1.84, -0.1), (-1.84, 0.88), (-1.66, 0.88)], 0.3, 0.04)),
        ("Dark", extrude([(-0.8, 0.78), (-1.5, 0.78), (-1.45, 0.9), (-0.85, 0.9)], 0.3, 0.04)),
        # Folded bipod legs under the fore-end.
        ("Steel", cylinder(at(1.7, 0.3, 0.1), at(2.55, 0.3, 0.1), 0.035, segments=8)),
        ("Steel", cylinder(at(1.7, 0.3, -0.1), at(2.55, 0.3, -0.1), 0.035, segments=8)),
        ("Steel", box(at(2.5, 0.36), (0.3, 0.1, 0.1))),
    ]
    parts += trigger_group("Steel", 0.42, 0.2, 0.42, 0.18, 0.34)
    parts += bars((1.75, 2.0, 2.25), 0.54, 0.32, 0.1)
    return parts, at(4.4, 0.6)


def pistol():
    """P-22 Sidearm: tall squared slide with the mark as rear serrations."""
    parts = [
        ("Dark", extrude(
            [(-0.36, 0.34), (0.95, 0.34), (0.95, 0.2), (0.24, 0.2), (0.1, -0.42), (-0.32, -0.42), (-0.2, 0.18)],
            0.26, 0.04,
        )),
        ("Steel", extrude([(-0.36, 0.34), (1.0, 0.34), (1.0, 0.66), (0.9, 0.72), (-0.36, 0.72)], 0.3, 0.04)),
        ("Bare", cylinder(at(0.98, 0.52), at(1.04, 0.52), 0.07, segments=10)),
        ("Accent", extrude([(0.12, -0.42), (-0.34, -0.42), (-0.35, -0.5), (0.13, -0.5)], 0.28, 0.02)),
        ("Glow", box(at(-0.3, 0.75, 0.07), (0.05, 0.06, 0.05))),
        ("Glow", box(at(-0.3, 0.75, -0.07), (0.05, 0.06, 0.05))),
        ("Glow", box(at(0.8, 0.75), (0.05, 0.06, 0.05))),
        # Ejection port, right-hand side.
        ("Dark", box(at(0.35, 0.62, 0.148), (0.012, 0.12, 0.34))),
    ]
    parts += trigger_group("Dark", 0.44, -0.02, 0.42, 0.24, 0.36)
    parts += bars((-0.22, -0.1, 0.02), 0.53, 0.31, 0.26, depth=0.05)
    return parts, at(1.04, 0.52)


def knife():
    """Field Knife: straight spine, angled tip, three grip bands."""
    parts = [
        ("Dark", extrude([(-0.32, -0.12), (0.3, -0.12), (0.3, 0.12), (-0.32, 0.14), (-0.4, 0.02)], 0.18, 0.04)),
        ("Steel", box(at(0.34, 0.0), (0.22, 0.4, 0.07))),
        ("Bare", extrude([(0.37, -0.12), (1.12, -0.12), (1.42, 0.12), (0.37, 0.13)], 0.05, 0.02)),
        ("Dark", box(at(0.75, 0.06), (0.055, 0.03, 0.5))),
        ("Steel", cylinder(at(-0.48, 0.02, -0.04), at(-0.48, 0.02, 0.04), 0.1, segments=10)),
    ]
    parts += bars((-0.15, 0.0, 0.15), 0.01, 0.2, 0.27, depth=0.04)
    return parts, at(1.42, 0.12)


def grenade():
    """Frag: a banded canister rather than a ribbed ball."""
    def y(lower, upper, r0, r1=None, key="Steel", segments=12):
        return (key, cylinder((0, lower, 0), (0, upper, 0), r0, r1, segments))

    parts = [
        y(-0.38, -0.32, 0.2, 0.26),
        y(-0.32, 0.28, 0.26),
        y(0.28, 0.34, 0.26, 0.2),
        y(0.34, 0.42, 0.16, key="Dark"),
        y(0.42, 0.52, 0.08, key="Bare", segments=8),
        y(-0.205, -0.155, 0.275, key="Accent"),
        y(-0.045, 0.005, 0.275, key="Accent"),
        y(0.115, 0.165, 0.275, key="Accent"),
        # Safety lever and pin.
        ("Dark", box(at(0.13, 0.5), (0.12, 0.03, 0.3))),
        ("Dark", box(at(0.29, 0.2), (0.12, 0.62, 0.03))),
        ("Bare", cylinder(at(-0.16, 0.48, -0.015), at(-0.16, 0.48, 0.015), 0.07, segments=10)),
    ]
    return parts, at(0.5, 0.0)


# Names match the `model` field in src/shared/Config/WeaponConfig.luau.
WEAPONS = {
    "Rifle": rifle,
    "Sniper": sniper,
    "Pistol": pistol,
    "Knife": knife,
    "Grenade": grenade,
}
