"""Software renderer for a quick look at generated models without opening Studio."""

import math

import numpy as np
from PIL import Image, ImageDraw

BACKGROUND = (24, 27, 36)
SUPERSAMPLE = 3


def _camera(yaw, pitch):
    """Rows are the camera's right, up and forward axes in weapon space."""
    yaw, pitch = math.radians(yaw), math.radians(pitch)
    forward = np.array([-math.cos(pitch) * math.cos(yaw), -math.sin(pitch), -math.cos(pitch) * math.sin(yaw)])
    right = np.cross(forward, [0.0, 1.0, 0.0])
    right /= np.linalg.norm(right)
    return np.array([right, np.cross(right, forward), forward])


def render(meshes, palette, size, yaw=0.0, pitch=0.0):
    """Orthographic view. Yaw 0 looks at the right-hand side with the muzzle to the right."""
    width, height = size[0] * SUPERSAMPLE, size[1] * SUPERSAMPLE
    camera = _camera(yaw, pitch)
    light = np.array([0.55, 0.7, -0.45])
    light /= np.linalg.norm(light)

    projected = [(key, tris @ camera.T, normals @ camera.T) for key, (tris, normals) in meshes]
    points = np.concatenate([p[1].reshape(-1, 3) for p in projected])
    low, high = points[:, :2].min(axis=0), points[:, :2].max(axis=0)
    scale = min(width / (high[0] - low[0]), height / (high[1] - low[1])) * 0.86
    offset = np.array([width, height]) / 2 - (low + high) / 2 * scale * (1, -1)

    color = np.empty((height, width, 3), dtype=np.float32)
    color[:] = BACKGROUND
    depth = np.full((height, width), np.inf, dtype=np.float32)

    for key, tris, normals in projected:
        entry = palette[key]
        base = np.array(entry["color"], dtype=np.float32)
        for tri, tri_normals in zip(tris, normals):
            # Camera space is left-handed (right, up, forward), so a triangle
            # facing the camera has a positive Z in this cross product.
            face = np.cross(tri[1] - tri[0], tri[2] - tri[0])
            if face[2] <= 0:
                continue
            xy = tri[:, :2] * scale * (1, -1) + offset
            x0, y0 = np.floor(xy.min(axis=0)).astype(int)
            x1, y1 = np.ceil(xy.max(axis=0)).astype(int)
            x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, width - 1), min(y1, height - 1)
            if x0 > x1 or y0 > y1:
                continue
            px, py = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            (ax, ay), (bx, by), (cx, cy) = xy
            area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
            if abs(area) < 1e-9:
                continue
            w0 = ((bx - px) * (cy - py) - (by - py) * (cx - px)) / area
            w1 = ((cx - px) * (ay - py) - (cy - py) * (ax - px)) / area
            w2 = 1 - w0 - w1
            z = w0 * tri[0, 2] + w1 * tri[1, 2] + w2 * tri[2, 2]
            window = depth[y0:y1 + 1, x0:x1 + 1]
            mask = (w0 >= 0) & (w1 >= 0) & (w2 >= 0) & (z < window)
            if not mask.any():
                continue
            if entry.get("emissive"):
                shade = 1.0
            else:
                normal = tri_normals.mean(axis=0)
                normal /= np.linalg.norm(normal)
                shade = 0.38 + 0.72 * max(float(normal @ (camera @ light)), 0.0)
            window[mask] = z[mask]
            color[y0:y1 + 1, x0:x1 + 1][mask] = np.clip(base * shade, 0, 255)

    image = Image.fromarray(color.astype(np.uint8))
    return image.resize(size, Image.LANCZOS)


def contact_sheet(path, rows, palette, views, cell=(620, 300)):
    """`rows` is a list of (label, meshes); `views` is a (yaw, pitch) per column."""
    sheet = Image.new("RGB", (cell[0] * len(views), cell[1] * len(rows)), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    for index, (label, meshes) in enumerate(rows):
        top = index * cell[1]
        for column, (yaw, pitch) in enumerate(views):
            sheet.paste(render(meshes, palette, cell, yaw, pitch), (column * cell[0], top))
        draw.text((12, top + 10), label, fill=(210, 214, 224))
    sheet.save(path)
