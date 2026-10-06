"""Small mesh toolkit for building low-poly models in code and writing them as GLB.

A piece is a pair (tris, normals): float arrays of shape (n, 3, 3) holding the
three corner positions and corner normals of each triangle. Pieces are built
with outward-facing counter-clockwise winding, which is what glTF expects.

Weapon space: grip at the origin, +Y up, barrel along -Z, +X to the holder's
right. Units are studs.
"""

import json
import math
import struct

import numpy as np


# --- pieces -----------------------------------------------------------------

def _flat(tris):
    tris = np.asarray(tris, dtype=np.float64).reshape(-1, 3, 3)
    normal = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    length = np.linalg.norm(normal, axis=1, keepdims=True)
    normal = normal / np.where(length == 0, 1, length)
    return tris, np.repeat(normal[:, None, :], 3, axis=1)


def _outward(tris, normals=None):
    """Flip the winding if the closed surface is inside out."""
    tris = np.asarray(tris, dtype=np.float64).reshape(-1, 3, 3)
    volume = np.einsum("ij,ij->", tris[:, 0], np.cross(tris[:, 1], tris[:, 2]))
    if volume < 0:
        tris = tris[:, ::-1]
        if normals is not None:
            normals = normals[:, ::-1]
    if normals is None:
        return _flat(tris)
    return tris, normals


def merge(pieces):
    return (
        np.concatenate([p[0] for p in pieces]),
        np.concatenate([p[1] for p in pieces]),
    )


def box(center, size):
    """Axis-aligned box. `center` and `size` are (x, y, z)."""
    c = np.asarray(center, dtype=np.float64)
    h = np.asarray(size, dtype=np.float64) / 2
    corner = lambda sx, sy, sz: c + h * (sx, sy, sz)
    tris = []
    for axis in range(3):
        u, v = (axis + 1) % 3, (axis + 2) % 3
        for sign in (1, -1):
            quad = []
            for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                s = [0, 0, 0]
                s[axis], s[u], s[v] = sign, su, sv
                quad.append(corner(*s))
            if sign < 0:
                quad.reverse()
            tris += [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]
    return _outward(tris)


def octahedron(center, radius):
    c = np.asarray(center, dtype=np.float64)
    axes = np.eye(3) * radius
    tris = []
    for sx in (1, -1):
        for sy in (1, -1):
            for sz in (1, -1):
                tris.append([c + sx * axes[0], c + sy * axes[1], c + sz * axes[2]])
    # Each face was wound without regard to its octant, so fix them one by one.
    fixed = []
    for a, b, d in tris:
        if np.dot(np.cross(b - a, d - a), (a + b + d) / 3 - c) < 0:
            b, d = d, b
        fixed.append([a, b, d])
    return _flat(fixed)


def cylinder(p0, p1, r0, r1=None, segments=12):
    """Capped cylinder or cone frustum from p0 to p1, smooth-shaded sides."""
    p0 = np.asarray(p0, dtype=np.float64)
    p1 = np.asarray(p1, dtype=np.float64)
    r1 = r0 if r1 is None else r1
    axis = (p1 - p0) / np.linalg.norm(p1 - p0)
    helper = np.array([0.0, 1.0, 0.0]) if abs(axis[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
    e1 = np.cross(helper, axis)
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(axis, e1)

    radial = [
        math.cos(2 * math.pi * k / segments) * e1 + math.sin(2 * math.pi * k / segments) * e2
        for k in range(segments)
    ]
    ring0 = [p0 + r0 * d for d in radial]
    ring1 = [p1 + r1 * d for d in radial]

    tris, normals = [], []
    for k in range(segments):
        n = (k + 1) % segments
        a, b, c, d = ring0[k], ring0[n], ring1[n], ring1[k]
        na, nb = radial[k], radial[n]
        tris += [[a, b, c], [a, c, d]]
        normals += [[na, nb, nb], [na, nb, na]]
        tris += [[p1, ring1[k], ring1[n]], [p0, ring0[n], ring0[k]]]
        normals += [[axis] * 3, [-axis] * 3]
    return _outward(tris, np.asarray(normals, dtype=np.float64))


def _signed_area(points):
    return sum(
        points[i][0] * points[(i + 1) % len(points)][1] - points[(i + 1) % len(points)][0] * points[i][1]
        for i in range(len(points))
    ) / 2


def _earclip(points):
    """Triangulate a simple counter-clockwise polygon. Returns index triples."""
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    remaining = list(range(len(points)))
    out = []
    while len(remaining) > 3:
        for k in range(len(remaining)):
            i0, i1, i2 = remaining[k - 1], remaining[k], remaining[(k + 1) % len(remaining)]
            a, b, c = points[i0], points[i1], points[i2]
            if cross(a, b, c) <= 1e-12:
                continue
            if any(
                cross(a, b, points[j]) > 1e-9 and cross(b, c, points[j]) > 1e-9 and cross(c, a, points[j]) > 1e-9
                for j in remaining
                if j not in (i0, i1, i2)
            ):
                continue
            out.append((i0, i1, i2))
            del remaining[k]
            break
        else:
            raise ValueError("profile is not a simple polygon")
    out.append(tuple(remaining))
    return out


def _inset(points, distance):
    """Move every edge of a counter-clockwise polygon inward by `distance`."""
    out = []
    count = len(points)
    for i in range(count):
        prev, here, nxt = points[i - 1], points[i], points[(i + 1) % count]
        normals = []
        for a, b in ((prev, here), (here, nxt)):
            dx, dy = b[0] - a[0], b[1] - a[1]
            length = math.hypot(dx, dy)
            normals.append((-dy / length, dx / length))
        (ax, ay), (bx, by) = normals
        scale = distance / max(1 + ax * bx + ay * by, 0.25)
        out.append((here[0] + (ax + bx) * scale, here[1] + (ay + by) * scale))
    return out


def extrude(profile, width, bevel=0.03, x=0.0):
    """A side-view outline given thickness across X, with chamfered edges.

    `profile` is a list of (forward, up) points: forward is the distance toward
    the muzzle from the grip, so it maps to -Z.
    """
    points = [(-f, y) for f, y in profile]
    if _signed_area(points) < 0:
        points.reverse()
    bevel = min(bevel, width * 0.4)
    faces = _earclip(points)
    inner = _inset(points, bevel) if bevel > 0 else points
    half = width / 2

    def lift(ring, a):
        return [np.array([x + a, v, u]) for u, v in ring]

    if bevel > 0:
        rings = [lift(inner, half), lift(points, half - bevel), lift(points, bevel - half), lift(inner, -half)]
    else:
        rings = [lift(points, half), lift(points, -half)]

    tris = []
    for i, j, k in faces:
        tris.append([rings[0][i], rings[0][j], rings[0][k]])
        tris.append([rings[-1][i], rings[-1][k], rings[-1][j]])
    count = len(points)
    for upper, lower in zip(rings, rings[1:]):
        for i in range(count):
            j = (i + 1) % count
            a, b, c, d = upper[i], upper[j], lower[j], lower[i]
            tris += [[a, d, c], [a, c, b]]
    return _outward(tris)


# --- GLB --------------------------------------------------------------------

def _linear(channel):
    c = channel / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def write_glb(path, meshes, palette):
    """Write one node per mesh.

    `meshes` is a list of (node name, palette key, piece). `palette` maps a key
    to a dict with `color` (sRGB 0-255) and optional `metallic`, `roughness`
    and `emissive`.
    """
    blob = bytearray()
    views, accessors, gl_meshes, nodes, materials = [], [], [], [], []
    material_index = {}

    def add_view(data, target):
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data), "target": target})
        blob.extend(data)
        return len(views) - 1

    for name, key, (tris, normals) in meshes:
        if key not in material_index:
            entry = palette[key]
            rgb = [_linear(c) for c in entry["color"]]
            material = {
                "name": key,
                "pbrMetallicRoughness": {
                    "baseColorFactor": rgb + [1.0],
                    "metallicFactor": entry.get("metallic", 0.0),
                    "roughnessFactor": entry.get("roughness", 0.8),
                },
            }
            if entry.get("emissive"):
                material["emissiveFactor"] = rgb
            material_index[key] = len(materials)
            materials.append(material)

        vertices = np.concatenate([tris.reshape(-1, 3), normals.reshape(-1, 3)], axis=1).astype(np.float32)
        unique, index = np.unique(vertices, axis=0, return_inverse=True)
        index = index.reshape(-1)
        positions = np.ascontiguousarray(unique[:, :3])
        normal_data = np.ascontiguousarray(unique[:, 3:])
        wide = len(unique) > 65535
        index_data = index.astype(np.uint32 if wide else np.uint16)

        accessors.append({
            "bufferView": add_view(positions.tobytes(), 34962),
            "componentType": 5126, "count": len(unique), "type": "VEC3",
            "min": positions.min(axis=0).tolist(), "max": positions.max(axis=0).tolist(),
        })
        accessors.append({
            "bufferView": add_view(normal_data.tobytes(), 34962),
            "componentType": 5126, "count": len(unique), "type": "VEC3",
        })
        accessors.append({
            "bufferView": add_view(index_data.tobytes(), 34963),
            "componentType": 5125 if wide else 5123, "count": len(index_data), "type": "SCALAR",
        })
        base = len(accessors) - 3
        gl_meshes.append({
            "name": name,
            "primitives": [{
                "attributes": {"POSITION": base, "NORMAL": base + 1},
                "indices": base + 2,
                "material": material_index[key],
            }],
        })
        nodes.append({"name": name, "mesh": len(gl_meshes) - 1})

    while len(blob) % 4:
        blob.append(0)
    document = {
        "asset": {"version": "2.0", "generator": "tdm-core tools/weapons"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": gl_meshes,
        "materials": materials,
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }
    text = json.dumps(document, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    total = 12 + 8 + len(text) + 8 + len(blob)
    with open(path, "wb") as handle:
        handle.write(struct.pack("<4sII", b"glTF", 2, total))
        handle.write(struct.pack("<I4s", len(text), b"JSON"))
        handle.write(text)
        handle.write(struct.pack("<I4s", len(blob), b"BIN\0"))
        handle.write(blob)
