"""Builds the trim sheet `assets/textures/trim_sheet.png` from `assets/texture_src/`.

Plain Python with Pillow; no Blender. Strips (`strips/<name>.png`) are squashed to 512 px wide
and their row height, cells (`cells/<name>.png`) to 128x128, both with a box filter. A file that
is missing is painted a plain tint, so the sheet always builds. Each cell's outer 4 px repeat its
own border, and so do the top and bottom 4 rows of each strip, so mipmaps do not bleed a
neighbour. The whole sheet is then cut to one shared palette of 32 colours (no dither).

It also writes `assets/texture_src/cells_manifest.json`: which cells have an image, and which
building owns each override slot. `dev/scenery_uv.py` reads it, so an object whose cell has no
image keeps its strip layout. Layout tables: `dev/trim_layout.py`. Rules: `docs/TEXTURING.md`.

    python dev/build_trim_sheet.py            build and write both files
    python dev/build_trim_sheet.py --check    exit 1 if the files on disk differ from a rebuild
"""
from __future__ import annotations

import argparse
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trim_layout as T  # noqa: E402

PALETTE_COLORS = 32
METRE_LINE = 0.93  # the placeholder strips' faint line every metre (64 px)


class BuildError(Exception):
    pass


def _byte(v: float) -> int:
    return max(0, min(255, round(v * 255)))


def _tint(strip: str, k: float = 1.0) -> tuple[int, int, int]:
    r, g, b = T.NEUTRAL_TINTS[strip]
    return _byte(r * k), _byte(g * k), _byte(b * k)


def _load(path: str) -> Image.Image:
    """The file as RGB; transparent pixels sit on white."""
    img = Image.open(path)
    img.load()
    if img.mode in ("RGBA", "LA") or "transparency" in img.info:
        rgba = img.convert("RGBA")
        base = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
        return Image.alpha_composite(base, rgba).convert("RGB")
    return img.convert("RGB")


def _strip_image(name: str, height: int, path: str | None) -> Image.Image:
    if path:
        img = _load(path).resize((T.SHEET_W, height), Image.BOX)
    else:
        img = Image.new("RGB", (T.SHEET_W, height), _tint(name))
        if name != "Blank":
            line = _tint(name, METRE_LINE)
            for x in range(0, T.SHEET_W, int(T.PX_PER_M)):
                for y in range(height):
                    img.putpixel((x, y), line)
    pad = min(T.CELL_PAD, height // 4)
    top = img.crop((0, pad, T.SHEET_W, pad + 1)).resize((T.SHEET_W, pad), Image.NEAREST)
    bottom = img.crop((0, height - pad - 1, T.SHEET_W, height - pad)).resize((T.SHEET_W, pad), Image.NEAREST)
    img.paste(top, (0, 0))
    img.paste(bottom, (0, height - pad))
    return img


def _cell_image(name: str, path: str | None) -> Image.Image:
    if not path:
        return Image.new("RGB", (T.CELL_PX, T.CELL_PX), _tint(T.CELL_STRIP[name]))
    pad = T.CELL_PAD
    inner_px = T.CELL_PX - 2 * pad
    inner = _load(path).resize((inner_px, inner_px), Image.BOX)
    cell = Image.new("RGB", (T.CELL_PX, T.CELL_PX))
    cell.paste(inner, (pad, pad))
    last = inner_px - 1
    cell.paste(inner.crop((0, 0, inner_px, 1)).resize((inner_px, pad), Image.NEAREST), (pad, 0))
    cell.paste(inner.crop((0, last, inner_px, last + 1)).resize((inner_px, pad), Image.NEAREST),
               (pad, T.CELL_PX - pad))
    cell.paste(inner.crop((0, 0, 1, inner_px)).resize((pad, inner_px), Image.NEAREST), (0, pad))
    cell.paste(inner.crop((last, 0, last + 1, inner_px)).resize((pad, inner_px), Image.NEAREST),
               (T.CELL_PX - pad, pad))
    for cx, cy, sx, sy in ((0, 0, 0, 0), (T.CELL_PX - pad, 0, last, 0),
                           (0, T.CELL_PX - pad, 0, last), (T.CELL_PX - pad, T.CELL_PX - pad, last, last)):
        cell.paste(Image.new("RGB", (pad, pad), inner.getpixel((sx, sy))), (cx, cy))
    return cell


def _files(directory: str) -> dict[str, str]:
    """Lower-case stem -> path, for the .png files in a folder."""
    out: dict[str, str] = {}
    if os.path.isdir(directory):
        for entry in sorted(os.listdir(directory)):
            stem, ext = os.path.splitext(entry)
            if ext.lower() == ".png":
                out[stem.lower()] = os.path.join(directory, entry)
    return out


def build(src: str) -> tuple[Image.Image, dict, str]:
    """Returns (sheet, manifest data, one-line summary). Raises BuildError."""
    strip_files = _files(os.path.join(src, "strips"))
    cell_files = _files(os.path.join(src, "cells"))
    problems = []

    known_strips = {n.lower() for n, _ in T.STRIP_ROWS}
    for stem in strip_files:
        if stem not in known_strips:
            problems.append("strips/%s.png is not a strip (%s)" % (stem, ", ".join(sorted(known_strips))))

    overrides = []  # (filename stem, building, cell)
    for stem in cell_files:
        if stem.startswith("bld_"):
            parsed = T.split_override(stem)
            if parsed is None:
                problems.append("cells/%s.png: not bld_<building>_<cell> with a known cell" % stem)
            else:
                overrides.append((stem, parsed[0], parsed[1]))
        elif stem not in T.CELL_NAMES:
            problems.append("cells/%s.png is not a cell (%s)" % (stem, ", ".join(T.CELL_NAMES)))
    if len(overrides) > len(T.SPARE_SLOTS):
        problems.append("%d overrides but only %d spare cell slots; remove one of: %s" % (
            len(overrides), len(T.SPARE_SLOTS), ", ".join("cells/%s.png" % o[0] for o in overrides)))
    if problems:
        raise BuildError("\n".join(problems))

    sheet = Image.new("RGB", (T.SHEET_W, T.SHEET_H), _tint("Blank"))
    tints_used = 0
    for name, (r0, r1) in T.STRIPS.items():
        path = strip_files.get(name.lower())
        tints_used += 0 if path else 1
        sheet.paste(_strip_image(name, r1 - r0, path), (0, r0))

    cells = {}
    for name in T.CELL_NAMES:
        slot = T.cell_slot(name)
        path = cell_files.get(name)
        tints_used += 0 if path else 1
        x0, y0, _, _ = T.cell_rect(slot)
        sheet.paste(_cell_image(name, path), (x0, y0))
        cells[name] = {"slot": slot, "present": path is not None}
    override_entries = []
    for (stem, building, cell), slot in zip(overrides, T.SPARE_SLOTS):
        x0, y0, _, _ = T.cell_rect(slot)
        sheet.paste(_cell_image(cell, cell_files[stem]), (x0, y0))
        override_entries.append({"building": building, "cell": cell, "slot": slot, "file": stem + ".png"})
    for slot in T.SPARE_SLOTS[len(overrides):]:
        x0, y0, _, _ = T.cell_rect(slot)
        sheet.paste(_cell_image(T.CELLS[slot], None), (x0, y0))

    colours = len(sheet.getcolors(maxcolors=T.SHEET_W * T.SHEET_H))
    note = "exact"
    if colours > PALETTE_COLORS:
        sheet = sheet.quantize(colors=PALETTE_COLORS, method=Image.Quantize.MEDIANCUT,
                               dither=Image.Dither.NONE).convert("RGB")
        note = "cut from %d" % colours
    palette = len(sheet.getcolors(maxcolors=T.SHEET_W * T.SHEET_H))

    manifest = {"atlas": {"w": T.SHEET_W, "h": T.SHEET_H}, "cells": cells, "overrides": override_entries}
    summary = "strips %d/%d, cells %d/%d, overrides %d, tints used %d, palette %d colours (%s)" % (
        len(strip_files), len(T.STRIP_ROWS), sum(1 for c in cells.values() if c["present"]),
        len(T.CELL_NAMES), len(overrides), tints_used, palette, note)
    return sheet, manifest, summary


def _manifest_text(data: dict) -> str:
    return json.dumps(data, indent=1) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true", help="exit 1 if the sheet on disk differs from a rebuild")
    ap.add_argument("--src", default=T.SRC_DIR, help="folder holding strips/ and cells/")
    ap.add_argument("--sheet", default=T.SHEET_PATH, help="output PNG")
    ap.add_argument("--manifest", default=T.MANIFEST_PATH, help="output manifest JSON")
    args = ap.parse_args()
    try:
        sheet, manifest, summary = build(args.src)
    except BuildError as e:
        print("BUILD FAILED:\n%s" % e)
        return 2
    text = _manifest_text(manifest)
    if args.check:
        same = os.path.exists(args.sheet) and os.path.exists(args.manifest)
        if same:
            on_disk = Image.open(args.sheet).convert("RGB")
            same = on_disk.size == sheet.size and on_disk.tobytes() == sheet.tobytes()
            with open(args.manifest, encoding="utf-8") as f:
                same = same and f.read() == text
        print("trim sheet %s: %s" % ("up to date" if same else "DIFFERS from a rebuild", summary))
        return 0 if same else 1
    os.makedirs(os.path.dirname(args.sheet), exist_ok=True)
    os.makedirs(os.path.dirname(args.manifest), exist_ok=True)
    sheet.save(args.sheet, optimize=True)
    with open(args.manifest, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("trim sheet written: %s" % summary)
    return 0


if __name__ == "__main__":
    sys.exit(main())
