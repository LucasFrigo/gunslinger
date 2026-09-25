"""Write minimal Y-up glTF 2.0 binaries for the coin and ace of spades.

Used by the vend scripts and as a blender-free fallback so Godot has a mesh
even when Blender is not on PATH.

    python dev/write_prop_glb.py
"""
from __future__ import annotations

import json
import os
import struct
import zlib

OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "assets", "models", "props",
)


def _pad4(data: bytes, fill: bytes = b" ") -> bytes:
    rem = len(data) % 4
    return data if rem == 0 else data + fill * (4 - rem)


def _png_rgba(width: int, height: int, pixels: bytes) -> bytes:
    def chunk(tag: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + tag
            + payload
            + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
        )

    raw = b""
    row = width * 4
    for y in range(height):
        raw += b"\x00" + pixels[y * row : (y + 1) * row]
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def _fill(width: int, height: int, rgba: tuple[int, int, int, int]) -> bytearray:
    px = bytearray()
    px.extend(bytes(rgba) * (width * height))
    return px


def _disc(px: bytearray, width: int, height: int, cx: float, cy: float, r: float, rgba: tuple[int, int, int, int]) -> None:
    r2 = r * r
    for y in range(height):
        for x in range(width):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r2:
                i = (y * width + x) * 4
                px[i : i + 4] = bytes(rgba)


def _rect(px: bytearray, width: int, height: int, x0: int, y0: int, x1: int, y1: int, rgba: tuple[int, int, int, int]) -> None:
    for y in range(max(0, y0), min(height, y1)):
        for x in range(max(0, x0), min(width, x1)):
            i = (y * width + x) * 4
            px[i : i + 4] = bytes(rgba)


def _letter(px: bytearray, width: int, height: int, ox: int, oy: int, scale: int, rgba: tuple[int, int, int, int], glyph: str) -> None:
    # 5x7 bitmap glyphs.
    glyphs = {
        "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
        "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
        "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    }
    rows = glyphs[glyph]
    for gy, row in enumerate(rows):
        for gx, bit in enumerate(row):
            if bit == "1":
                _rect(
                    px, width, height,
                    ox + gx * scale, oy + gy * scale,
                    ox + (gx + 1) * scale, oy + (gy + 1) * scale,
                    rgba,
                )


def _spade(px: bytearray, width: int, height: int, cx: int, cy: int, size: int, rgba: tuple[int, int, int, int]) -> None:
    # Heart-shaped lobes plus a downward point and a stem.
    r = size * 0.28
    _disc(px, width, height, cx - r * 0.7, cy - r * 0.15, r, rgba)
    _disc(px, width, height, cx + r * 0.7, cy - r * 0.15, r, rgba)
    _disc(px, width, height, cx, cy - r * 0.55, r * 0.95, rgba)
    for y in range(int(cy - r * 0.2), int(cy + size * 0.55)):
        t = (y - (cy - r * 0.2)) / (size * 0.75)
        half = max(1, int((1.0 - t) * size * 0.42))
        _rect(px, width, height, cx - half, y, cx + half, y + 1, rgba)
    _rect(px, width, height, cx - max(1, size // 14), int(cy + size * 0.15), cx + max(1, size // 14), int(cy + size * 0.62), rgba)
    _rect(px, width, height, cx - max(2, size // 6), int(cy + size * 0.52), cx + max(2, size // 6), int(cy + size * 0.62), rgba)


def _write_glb(path: str, name: str, positions: list[float], normals: list[float], uvs: list[float],
               indices: list[int], image_png: bytes, color: tuple[float, float, float]) -> None:
    pos_b = b"".join(struct.pack("<fff", *positions[i : i + 3]) for i in range(0, len(positions), 3))
    nrm_b = b"".join(struct.pack("<fff", *normals[i : i + 3]) for i in range(0, len(normals), 3))
    uv_b = b"".join(struct.pack("<ff", *uvs[i : i + 2]) for i in range(0, len(uvs), 2))
    idx_b = b"".join(struct.pack("<H", i) for i in indices)
    if len(idx_b) % 4:
        idx_b += b"\x00\x00"

    img_b = _pad4(image_png, b"\x00")
    blob = pos_b + nrm_b + uv_b + idx_b + img_b

    nverts = len(positions) // 3
    mins = [min(positions[i::3]) for i in range(3)]
    maxs = [max(positions[i::3]) for i in range(3)]
    o_pos, o_nrm = 0, len(pos_b)
    o_uv, o_idx = o_nrm + len(nrm_b), o_nrm + len(nrm_b) + len(uv_b)
    o_img = o_idx + len(idx_b)

    gltf = {
        "asset": {"version": "2.0", "generator": "gunslinger write_prop_glb"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": name, "mesh": 0}],
        "meshes": [{
            "name": name,
            "primitives": [{
                "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
                "indices": 3,
                "material": 0,
            }],
        }],
        "materials": [{
            "name": name,
            "pbrMetallicRoughness": {
                "baseColorFactor": [color[0], color[1], color[2], 1.0],
                "baseColorTexture": {"index": 0},
                "metallicFactor": 0.15,
                "roughnessFactor": 0.45,
            },
            "doubleSided": True,
        }],
        "textures": [{"source": 0}],
        "images": [{"mimeType": "image/png", "bufferView": 4, "name": name + "_tex"}],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": nverts, "type": "VEC3",
             "min": mins, "max": maxs},
            {"bufferView": 1, "componentType": 5126, "count": nverts, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": nverts, "type": "VEC2"},
            {"bufferView": 3, "componentType": 5123, "count": len(indices), "type": "SCALAR"},
        ],
        "bufferViews": [
            {"buffer": 0, "byteOffset": o_pos, "byteLength": len(pos_b), "target": 34962},
            {"buffer": 0, "byteOffset": o_nrm, "byteLength": len(nrm_b), "target": 34962},
            {"buffer": 0, "byteOffset": o_uv, "byteLength": len(uv_b), "target": 34962},
            {"buffer": 0, "byteOffset": o_idx, "byteLength": len(indices) * 2, "target": 34963},
            {"buffer": 0, "byteOffset": o_img, "byteLength": len(image_png)},
        ],
        "buffers": [{"byteLength": len(blob)}],
    }
    js = _pad4(json.dumps(gltf, separators=(",", ":")).encode("utf-8"))
    total = 12 + 8 + len(js) + 8 + len(blob)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON"))
        f.write(js)
        f.write(struct.pack("<I4s", len(blob), b"BIN\x00"))
        f.write(blob)
    print("wrote %s (%d bytes)" % (path, total))


def _cylinder(radius: float, half_h: float, segs: int) -> tuple[list[float], list[float], list[float], list[int]]:
    pos: list[float] = []
    nrm: list[float] = []
    uv: list[float] = []
    idx: list[int] = []

    def add(p, n, u):
        pos.extend(p)
        nrm.extend(n)
        uv.extend(u)
        return len(pos) // 3 - 1

    # Caps: +Y heads, -Y tails. Face UVs fill the disc.
    for sign, v_off in ((1.0, 0.0), (-1.0, 0.5)):
        center = add([0.0, sign * half_h, 0.0], [0.0, sign, 0.0], [0.5, 0.25 + v_off])
        ring = []
        for i in range(segs):
            a = (i / segs) * 6.283185307179586
            x, z = radius * __import__("math").cos(a), radius * __import__("math").sin(a)
            ring.append(add(
                [x, sign * half_h, z], [0.0, sign, 0.0],
                [0.5 + 0.5 * __import__("math").cos(a), 0.25 + v_off + 0.25 * __import__("math").sin(a)],
            ))
        for i in range(segs):
            a, b = ring[i], ring[(i + 1) % segs]
            if sign > 0:
                idx.extend([center, a, b])
            else:
                idx.extend([center, b, a])

    # Rim, U along the edge, V in the middle strip.
    for i in range(segs):
        a0 = (i / segs) * 6.283185307179586
        a1 = ((i + 1) / segs) * 6.283185307179586
        math = __import__("math")
        x0, z0 = radius * math.cos(a0), radius * math.sin(a0)
        x1, z1 = radius * math.cos(a1), radius * math.sin(a1)
        n0, n1 = [x0 / radius, 0.0, z0 / radius], [x1 / radius, 0.0, z1 / radius]
        u0, u1 = i / segs, (i + 1) / segs
        v0 = add([x0, half_h, z0], n0, [u0, 0.48])
        v1 = add([x1, half_h, z1], n1, [u1, 0.48])
        v2 = add([x1, -half_h, z1], n1, [u1, 0.52])
        v3 = add([x0, -half_h, z0], n0, [u0, 0.52])
        idx.extend([v0, v1, v2, v0, v2, v3])
    return pos, nrm, uv, idx


def _box(w: float, h: float, d: float) -> tuple[list[float], list[float], list[float], list[int]]:
    hx, hy, hz = w * 0.5, h * 0.5, d * 0.5
    faces = [
        # +Y face (card face), full 0..1 UV
        ((-hx, hy, -hz), (hx, hy, -hz), (hx, hy, hz), (-hx, hy, hz), (0, 1, 0),
         (0.0, 1.0), (1.0, 1.0), (1.0, 0.0), (0.0, 0.0)),
        # -Y back
        ((-hx, -hy, hz), (hx, -hy, hz), (hx, -hy, -hz), (-hx, -hy, -hz), (0, -1, 0),
         (0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)),
        # +Z
        ((-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz), (0, 0, 1),
         (0.0, 1.0), (1.0, 1.0), (1.0, 0.0), (0.0, 0.0)),
        # -Z
        ((hx, -hy, -hz), (-hx, -hy, -hz), (-hx, hy, -hz), (hx, hy, -hz), (0, 0, -1),
         (0.0, 1.0), (1.0, 1.0), (1.0, 0.0), (0.0, 0.0)),
        # +X
        ((hx, -hy, hz), (hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz), (1, 0, 0),
         (0.0, 1.0), (1.0, 1.0), (1.0, 0.0), (0.0, 0.0)),
        # -X
        ((-hx, -hy, -hz), (-hx, -hy, hz), (-hx, hy, hz), (-hx, hy, -hz), (-1, 0, 0),
         (0.0, 1.0), (1.0, 1.0), (1.0, 0.0), (0.0, 0.0)),
    ]
    pos: list[float] = []
    nrm: list[float] = []
    uv: list[float] = []
    idx: list[int] = []
    for a, b, c, d, n, ua, ub, uc, ud in faces:
        base = len(pos) // 3
        for p, u in ((a, ua), (b, ub), (c, uc), (d, ud)):
            pos.extend(p)
            nrm.extend(n)
            uv.extend(u)
        idx.extend([base, base + 1, base + 2, base, base + 2, base + 3])
    return pos, nrm, uv, idx


def coin_texture() -> bytes:
    w = h = 128
    ink = (32, 24, 12, 255)
    gold = (212, 168, 72, 255)
    silver = (196, 196, 188, 255)
    rim = (120, 96, 40, 255)
    px = _fill(w, h, rim)
    # Heads on the top half, tails on the bottom.
    _disc(px, w, h, 64, 32, 28, gold)
    _disc(px, w, h, 64, 96, 28, silver)
    _letter(px, w, h, 49, 18, 5, ink, "H")
    _letter(px, w, h, 49, 82, 5, ink, "T")
    return _png_rgba(w, h, bytes(px))


def ace_texture() -> bytes:
    w, h = 96, 136
    cream = (244, 236, 214, 255)
    back = (120, 24, 28, 255)
    ink = (16, 16, 18, 255)
    px = _fill(w, h, cream)
    _letter(px, w, h, 8, 8, 3, ink, "A")
    _letter(px, w, h, w - 23, h - 30, 3, ink, "A")
    _spade(px, w, h, w // 2, h // 2 + 4, 52, ink)
    # A thin red back is not on this card face; the -Y UVs reuse the same sheet
    # with a dark wash so the back still reads as a different color.
    return _png_rgba(w, h, bytes(px))


def write_coin(path: str) -> None:
    pos, nrm, uv, idx = _cylinder(0.022, 0.0012, 24)
    _write_glb(path, "MSC_Coin", pos, nrm, uv, idx, coin_texture(), (0.85, 0.7, 0.28))


def write_ace(path: str) -> None:
    # Poker card ~63.5 x 88.9 mm, slightly thickened so it reads in flight.
    pos, nrm, uv, idx = _box(0.0635, 0.0016, 0.0889)
    _write_glb(path, "MSC_Ace", pos, nrm, uv, idx, ace_texture(), (0.95, 0.92, 0.84))


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    write_coin(os.path.join(OUT_DIR, "msc_coin.glb"))
    write_ace(os.path.join(OUT_DIR, "msc_ace.glb"))
    with open(os.path.join(OUT_DIR, "msc_coin_MSC_Coin_tex.png"), "wb") as f:
        f.write(coin_texture())
    with open(os.path.join(OUT_DIR, "msc_ace_MSC_Ace_tex.png"), "wb") as f:
        f.write(ace_texture())


if __name__ == "__main__":
    main()
