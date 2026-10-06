"""Shared finishes for every generated model.

Art direction ("Night Shift"): equipment and freight that look made in the
yard's own workshops. Cold stamped steel, near-black polymer, and one
sodium-amber accent that echoes the map's lamps. Everything carries the
three-bar mark somewhere on its side.

`color` and `material` are what the Studio fit step applies. `metallic`,
`roughness` and `emissive` only affect how the GLB looks in other viewers.
"""

PALETTE = {
    "Steel": {"color": (74, 82, 96), "material": "Metal", "metallic": 0.9, "roughness": 0.5},
    "Bare": {"color": (128, 134, 142), "material": "Metal", "metallic": 1.0, "roughness": 0.35},
    "Dark": {"color": (30, 32, 38), "material": "SmoothPlastic", "roughness": 0.85},
    "Accent": {"color": (255, 170, 60), "material": "SmoothPlastic", "roughness": 0.6},
    "Glow": {"color": (255, 190, 120), "material": "Neon", "emissive": True},
    "Timber": {"color": (112, 88, 60), "material": "WoodPlanks", "roughness": 0.9},
    "Oxide": {"color": (120, 60, 46), "material": "CorrodedMetal", "metallic": 0.6, "roughness": 0.8},
    "Concrete": {"color": (118, 120, 124), "material": "Concrete", "roughness": 0.95},
    "Wrap": {"color": (66, 74, 90), "material": "Fabric", "roughness": 0.9},
}
