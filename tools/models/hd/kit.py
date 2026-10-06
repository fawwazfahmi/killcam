"""Hard-surface modelling kit for the high-detail weapons, run inside Blender.

Designs are written in real millimetres in Blender's frame: +Y toward the
muzzle, +Z up, +X to the holder's right, with the bore on the Y axis. `finish()`
converts to studs and moves the grip to the origin, which after glTF export is
the game's weapon space (grip at the origin, +Y up, barrel along -Z, +X right).

Every shape belongs to a named part. Parts are what the game sees as separate
MeshParts, so anything that moves in an animation (magazine, bolt, slide,
trigger) is its own part, and each part has one finish.
"""

import math

import bpy  # first: bmesh and mathutils load with it
import bmesh
from mathutils import Matrix, Vector

SHARP_ANGLE = math.radians(32)  # edges sharper than this stay hard after smoothing
MARKER_RADIUS = 0.02  # studs

# Preview materials. The game applies its own colours (see FINISHES in build.py).
MATERIALS = {
    "Steel": {"color": (0.045, 0.047, 0.052), "metallic": 0.8, "roughness": 0.36},
    "Bare": {"color": (0.36, 0.37, 0.38), "metallic": 1.0, "roughness": 0.28},
    "Wood": {"color": (0.17, 0.052, 0.016), "metallic": 0.0, "roughness": 0.38},
    "Tan": {"color": (0.19, 0.13, 0.072), "metallic": 0.0, "roughness": 0.6},
    "Polymer": {"color": (0.011, 0.011, 0.012), "metallic": 0.0, "roughness": 0.55},
}


class Gun:
    def __init__(self, name):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        _materials.clear()
        self.name = name
        self.shapes = []  # (object, part)
        self.cutters = []
        self.parts = {}  # part -> {"finish": str, "group": str}

    # --- parts -------------------------------------------------------------

    def part(self, name, finish, group="Body"):
        """Declare a part. `group` names what it moves with in animations."""
        self.parts[name] = {"finish": finish, "group": group}
        return name

    def _object(self, bm, part, bevel, segments):
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        label = part or "Cutter"
        mesh = bpy.data.meshes.new(label)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(label, mesh)
        bpy.context.scene.collection.objects.link(obj)
        if bevel > 0:
            modifier = obj.modifiers.new("Bevel", "BEVEL")
            modifier.width = bevel
            modifier.segments = segments
            modifier.limit_method = "ANGLE"
            modifier.angle_limit = math.radians(25)
            modifier.miter_outer = "MITER_ARC"
        if part is not None:
            self.shapes.append((obj, part))
        return obj

    # --- shapes ------------------------------------------------------------

    def slab(self, part, profile, width, x=0.0, bevel=0.0, segments=2):
        """A side outline, (forward, up) points in mm, given `width` across X."""
        bm = bmesh.new()
        points = [p for i, p in enumerate(profile) if p != profile[i - 1]]
        verts = [bm.verts.new((x - width / 2, y, z)) for y, z in points]
        face = bm.faces.new(verts)
        bm.normal_update()
        if face.normal.x > 0:
            face.normal_flip()
        extruded = bmesh.ops.extrude_face_region(bm, geom=[face])
        moved = [v for v in extruded["geom"] if isinstance(v, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, verts=moved, vec=(width, 0, 0))
        return self._object(bm, part, bevel, segments)

    def plan(self, part, outline, height, z=0.0, bevel=0.0, segments=2):
        """A top-view outline, (across, forward) points in mm, given `height` along Z."""
        bm = bmesh.new()
        points = [p for i, p in enumerate(outline) if p != outline[i - 1]]
        verts = [bm.verts.new((px, py, z - height / 2)) for px, py in points]
        face = bm.faces.new(verts)
        extruded = bmesh.ops.extrude_face_region(bm, geom=[face])
        moved = [v for v in extruded["geom"] if isinstance(v, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, verts=moved, vec=(0, 0, height))
        return self._object(bm, part, bevel, segments)

    def box(self, part, center, size, bevel=0.0, segments=2):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=size, verts=bm.verts)
        bmesh.ops.translate(bm, vec=center, verts=bm.verts)
        return self._object(bm, part, bevel, segments)

    def lathe(self, part, profile, start, direction=(0, 1, 0), segments=24, bevel=0.0, flat=None):
        """Revolve (distance along axis, radius) points around an axis.

        Radius 0 at either end closes it with a point; otherwise it is capped.
        `flat`, if given, is the number of sides for a polygonal section.
        """
        segments = flat or segments
        axis = Vector(direction).normalized()
        helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
        e1 = helper.cross(axis).normalized()
        e2 = axis.cross(e1)
        start = Vector(start)
        turn = math.pi / segments if flat else 0.0

        bm = bmesh.new()
        rings = []
        for t, r in profile:
            centre = start + axis * t
            if r <= 0:
                rings.append([bm.verts.new(centre)])
                continue
            ring = []
            for k in range(segments):
                a = 2 * math.pi * k / segments + turn
                ring.append(bm.verts.new(centre + r * (math.cos(a) * e1 + math.sin(a) * e2)))
            rings.append(ring)
        for lower, upper in zip(rings, rings[1:]):
            for k in range(segments):
                n = (k + 1) % segments
                if len(lower) == 1 and len(upper) == 1:
                    continue
                if len(lower) == 1:
                    bm.faces.new((lower[0], upper[k], upper[n]))
                elif len(upper) == 1:
                    bm.faces.new((lower[k], lower[n], upper[0]))
                else:
                    bm.faces.new((lower[k], lower[n], upper[n], upper[k]))
        for ring in (rings[0], rings[-1]):
            if len(ring) > 1:
                bm.faces.new(ring)
        return self._object(bm, part, bevel, 2)

    def tube(self, part, p0, p1, r0, r1=None, segments=20, bevel=0.0):
        p0, p1 = Vector(p0), Vector(p1)
        length = (p1 - p0).length
        r1 = r0 if r1 is None else r1
        return self.lathe(part, [(0, r0), (length, r1)], p0, p1 - p0, segments, bevel)

    def sweep(self, part, centre, half_depth, width, x=0.0, bevel=0.0, segments=2):
        """A slab whose outline follows a centreline of (forward, up) points,
        `half_depth(t)` either side of it, t running 0 to 1 along it."""
        left, right = [], []
        count = len(centre)
        for i, (y, z) in enumerate(centre):
            a = centre[max(i - 1, 0)]
            b = centre[min(i + 1, count - 1)]
            dy, dz = b[0] - a[0], b[1] - a[1]
            length = math.hypot(dy, dz)
            ny, nz = -dz / length, dy / length
            d = half_depth(i / (count - 1))
            left.append((y + ny * d, z + nz * d))
            right.append((y - ny * d, z - nz * d))
        return self.slab(part, left + right[::-1], width, x, bevel, segments)

    def taper(self, obj, axis, stops, across=0):
        """Scale `obj` across axis `across` (0 = X) by a factor interpolated
        from `stops`, (position along `axis`, factor) pairs."""
        stops = sorted(stops)
        for v in obj.data.vertices:
            p = v.co[axis]
            if p <= stops[0][0]:
                f = stops[0][1]
            elif p >= stops[-1][0]:
                f = stops[-1][1]
            else:
                for (p0, f0), (p1, f1) in zip(stops, stops[1:]):
                    if p0 <= p <= p1:
                        f = f0 + (f1 - f0) * (p - p0) / (p1 - p0)
                        break
            v.co[across] *= f
        return obj

    def mirror(self, build):
        """Run `build(sign)` for the right (+1) and left (-1) side."""
        return [build(1), build(-1)]

    # --- booleans ----------------------------------------------------------

    def cutter(self, kind, *args, **kwargs):
        """Make a shape with `kind` ("box", "slab", ...) for use with `cut`."""
        obj = getattr(self, kind)(None, *args, **kwargs)
        obj.display_type = "WIRE"
        obj.hide_render = True
        self.cutters.append(obj)
        return obj

    def cut(self, target, cutter, union=False):
        modifier = target.modifiers.new("Cut", "BOOLEAN")
        modifier.operation = "UNION" if union else "DIFFERENCE"
        modifier.solver = "EXACT"
        modifier.object = cutter
        # Cut before bevelling, so the opening gets the same soft edge.
        target.modifiers.move(len(target.modifiers) - 1, 0)

    # --- output ------------------------------------------------------------

    def finish(self, grip, muzzle, studs_per_metre):
        """Apply modifiers, merge shapes into parts, convert to studs with the
        grip at the origin, smooth, unwrap and add the fit markers."""
        scale = studs_per_metre / 1000
        to_studs = Matrix.Scale(scale, 4) @ Matrix.Translation(-Vector(grip))
        depsgraph = bpy.context.evaluated_depsgraph_get()

        merged = {}
        for obj, part in self.shapes:
            mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
            merged.setdefault(part, bmesh.new()).from_mesh(mesh)
            bpy.data.meshes.remove(mesh)
        for obj in [o for o, _ in self.shapes] + self.cutters:
            mesh = obj.data
            bpy.data.objects.remove(obj)
            bpy.data.meshes.remove(mesh)

        self.objects = []
        for part, bm in merged.items():
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
            bm.transform(to_studs)
            _smooth(bm)
            _unwrap(bm, scale)
            mesh = bpy.data.meshes.new(part)
            bm.to_mesh(mesh)
            bm.free()
            mesh.materials.append(_material(self.parts[part]["finish"]))
            obj = bpy.data.objects.new(part, mesh)
            bpy.context.scene.collection.objects.link(obj)
            self.objects.append(obj)

        muzzle_studs = to_studs @ Vector(muzzle)
        self.muzzle = muzzle_studs
        self.markers = []
        for name, point in {
            "MarkOrigin": (0, 0, 0),
            "MarkForward": (0, 1, 0),
            "MarkUp": (0, 0, 1),
            "MarkRight": (1, 0, 0),
            "MarkMuzzle": tuple(muzzle_studs),
        }.items():
            bm = bmesh.new()
            bmesh.ops.create_icosphere(bm, subdivisions=0, radius=MARKER_RADIUS)
            bmesh.ops.translate(bm, vec=point, verts=bm.verts)
            mesh = bpy.data.meshes.new(name)
            bm.to_mesh(mesh)
            bm.free()
            obj = bpy.data.objects.new(name, mesh)
            bpy.context.scene.collection.objects.link(obj)
            obj.hide_render = True
            self.markers.append(obj)

    def triangles(self):
        counts = {}
        for obj in self.objects:
            counts[obj.name] = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        return counts

    def export(self, path):
        bpy.ops.object.select_all(action="DESELECT")
        for obj in self.objects + self.markers:
            obj.select_set(True)
        bpy.ops.export_scene.gltf(
            filepath=str(path),
            export_format="GLB",
            use_selection=True,
            export_yup=True,
            export_apply=True,
            export_texcoords=True,
            export_normals=True,
            export_materials="EXPORT",
        )


def rail(g, part, y0, y1, centre, normal, width=21):
    """A Picatinny strip: base plus a tooth every 10 mm. `normal` is the
    direction the rail faces: "up", "down", "right" or "left"."""
    teeth = []
    for k in range(int((y1 - y0 - 4) // 10)):
        teeth.append(y0 + 7 + k * 10)
    x, z = centre
    if normal in ("up", "down"):
        s = 1 if normal == "up" else -1
        g.box(part, (x, (y0 + y1) / 2, z + s * 2), (width, y1 - y0, 4), bevel=0.6)
        for y in teeth:
            g.box(part, (x, y, z + s * 6), (width, 5, 4), bevel=0.5, segments=1)
    else:
        s = 1 if normal == "right" else -1
        g.box(part, (x + s * 2, (y0 + y1) / 2, z), (4, y1 - y0, width), bevel=0.6)
        for y in teeth:
            g.box(part, (x + s * 6, y, z), (4, 5, width), bevel=0.5, segments=1)


def arc(top, radius, length, steps):
    """Centreline for a magazine: starts at `top` heading straight down and
    curves forward along a circle of `radius`."""
    span = length / radius
    return [
        (top[0] + radius * (1 - math.cos(span * i / steps)), top[1] - radius * math.sin(span * i / steps))
        for i in range(steps + 1)
    ]


def _smooth(bm):
    for face in bm.faces:
        face.smooth = True
    for edge in bm.edges:
        if not edge.is_manifold or edge.calc_face_angle(math.pi) > SHARP_ANGLE:
            edge.smooth = False


def _unwrap(bm, scale):
    """Box projection at one texture repeat per 100 mm, so a tiling skin
    (camo, carbon, engraving) lands at the same size on every weapon."""
    layer = bm.loops.layers.uv.verify()
    repeat = 1 / (100 * scale)
    for face in bm.faces:
        n = face.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        u, v = [(1, 2), (0, 2), (0, 1)][axis]
        flip = -1 if n[axis] < 0 else 1
        for loop in face.loops:
            co = loop.vert.co
            loop[layer].uv = (co[u] * repeat * (flip if axis != 1 else -flip), co[v] * repeat)


_materials = {}


def _material(finish):
    if finish in _materials:
        return _materials[finish]
    spec = MATERIALS[finish]
    material = bpy.data.materials.new(finish)
    material.use_nodes = True
    shader = material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (*spec["color"], 1.0)
    shader.inputs["Metallic"].default_value = spec["metallic"]
    shader.inputs["Roughness"].default_value = spec["roughness"]
    _materials[finish] = material
    return material
