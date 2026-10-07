"""Studio renders of a finished Gun: a right-side view and a three-quarter view."""

import math

import bpy
from mathutils import Vector
from PIL import Image, ImageDraw

BACKGROUND = (22, 24, 30)


def _bounds(objects):
    low = Vector((math.inf,) * 3)
    high = Vector((-math.inf,) * 3)
    for obj in objects:
        for v in obj.data.vertices:
            co = obj.matrix_world @ v.co
            low = Vector(map(min, low, co))
            high = Vector(map(max, high, co))
    return low, high


def _area(name, location, target, size, energy):
    light = bpy.data.lights.new(name, "AREA")
    light.size = size
    light.energy = energy
    obj = bpy.data.objects.new(name, light)
    obj.location = location
    direction = Vector(target) - Vector(location)
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(obj)


def _setup(scene, centre, extent, samples):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"

    world = bpy.data.worlds.new("Studio")
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = (0.42, 0.44, 0.48, 1)
    background.inputs["Strength"].default_value = 0.18
    scene.world = world

    r = extent * 1.6
    _area("Key", centre + Vector((r, -0.3 * r, 1.1 * r)), centre, extent * 1.2, 160 * extent ** 2)
    _area("Fill", centre + Vector((r, 0.9 * r, 0.1 * r)), centre, extent * 1.5, 45 * extent ** 2)
    _area("Rim", centre + Vector((-r, 0.4 * r, 0.9 * r)), centre, extent, 140 * extent ** 2)
    _area("Under", centre + Vector((0.6 * r, 0, -r)), centre, extent * 1.4, 22 * extent ** 2)


def _shot(scene, path, location, target, ortho_scale=None, lens=None, size=(1600, 760)):
    camera = bpy.data.cameras.new("Camera")
    obj = bpy.data.objects.new("Camera", camera)
    scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    if ortho_scale:
        camera.type = "ORTHO"
        camera.ortho_scale = ortho_scale
    else:
        camera.lens = lens
    scene.camera = obj
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(obj)


ANGLE_LENS = 62  # mm, on Blender's 36 mm sensor
MARGIN = 1.08


def _reach(low, high, centre, toward, lens, aspect):
    """How far back along `toward` a camera looking at `centre` has to stand
    for the whole box to be in the picture. A weapon that is tall as well as
    long (a hooked knife, say) needs more room than its length suggests."""
    forward = -toward
    right = forward.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(forward)
    across = 18 / lens  # tangent of half the view, side to side
    down = across / aspect
    farthest = 0.0
    for x in (low.x, high.x):
        for y in (low.y, high.y):
            for z in (low.z, high.z):
                corner = Vector((x, y, z)) - centre
                needed = corner.dot(toward) + max(abs(corner.dot(right)) / across, abs(corner.dot(up)) / down)
                farthest = max(farthest, needed)
    return farthest * MARGIN


def _wood_grain(material):
    """Preview only: grain along the length of the wood. Runs after export, so
    the GLB keeps a plain colour."""
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = nodes["Principled BSDF"]
    base = shader.inputs["Base Color"].default_value
    coords = nodes.new("ShaderNodeTexCoord")
    stretch = nodes.new("ShaderNodeMapping")
    stretch.inputs["Scale"].default_value = (14, 1.2, 14)
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = "RINGS"
    wave.inputs["Scale"].default_value = 1.6
    wave.inputs["Distortion"].default_value = 7
    wave.inputs["Detail"].default_value = 3
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (base[0] * 0.55, base[1] * 0.5, base[2] * 0.5, 1)
    ramp.color_ramp.elements[1].color = (base[0] * 1.35, base[1] * 1.3, base[2] * 1.2, 1)
    links.new(coords.outputs["Object"], stretch.inputs["Vector"])
    links.new(stretch.outputs["Vector"], wave.inputs["Vector"])
    links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], shader.inputs["Base Color"])


def render(gun, path, samples=96):
    scene = bpy.context.scene
    for material in bpy.data.materials:
        if material.name == "Wood":
            _wood_grain(material)
    low, high = _bounds(gun.objects)
    centre = (low + high) / 2
    size = high - low
    # Frame the width of the image: short, tall weapons need room top to bottom.
    extent = max(size.y, size.z * 1600 / 760 * 1.15, size.x)
    _setup(scene, centre, extent, samples)

    side = path.with_name(path.stem + "_side.png")
    angle = path.with_name(path.stem + "_angle.png")
    _shot(scene, side, centre + Vector((extent * 3, 0, 0)), centre, ortho_scale=extent * 1.08)
    toward = Vector((1.45, 1.05, 0.68))
    distance = max(extent * toward.length, _reach(low, high, centre, toward.normalized(), ANGLE_LENS, 1600 / 760))
    _shot(scene, angle, centre + toward.normalized() * distance, centre, lens=ANGLE_LENS)

    label = f"{gun.name}  -  {sum(gun.triangles().values())} triangles, {len(gun.objects)} parts"
    sheet = Image.new("RGB", (1600, 760 * 2), BACKGROUND)
    for index, shot in enumerate((side, angle)):
        image = Image.open(shot).convert("RGBA")
        sheet.paste(image, (0, 760 * index), image)
        shot.unlink()
    ImageDraw.Draw(sheet).text((16, 14), label, fill=(210, 214, 224))
    sheet.save(path)
