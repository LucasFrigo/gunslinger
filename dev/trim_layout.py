"""The trim sheet's layout tables, in plain Python (no Blender, no Pillow).

Shared by `dev/scenery_uv.py` (UVs, runs inside Blender) and `dev/build_trim_sheet.py`
(writes the PNG). Change a strip height or a cell position here and re-run the unwrap.
Rules and the picture of the sheet: `docs/TEXTURING.md`.
"""
from __future__ import annotations

import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET_PATH = os.path.join(ROOT, "assets", "textures", "trim_sheet.png")
SRC_DIR = os.path.join(ROOT, "assets", "texture_src")
MANIFEST_PATH = os.path.join(SRC_DIR, "cells_manifest.json")

SHEET_W = 512
SHEET_H = 1024
PX_PER_M = 64.0

# Strip name, height in px, top to bottom. They fill the top 512 rows.
STRIP_ROWS = [
    ("Siding", 128), ("Masonry", 128), ("Shingles", 64), ("Boards", 64), ("Beam", 32),
    ("Metal", 32), ("Glass", 32), ("Moulding", 16), ("Blank", 16),
]
STRIPS: dict[str, tuple[int, int]] = {}
_row = 0
for _name, _h in STRIP_ROWS:
    STRIPS[_name] = (_row, _row + _h)
    _row += _h
assert _row == SHEET_H // 2

# Sixteen 128 px cells, 4 x 4, in the bottom 512 rows, row by row. The two spares are taken by
# per-building overrides (`bld_<building>_<cell>.png`), in filename order.
CELL_PX = 128
CELL_PAD = 4  # outer px of a cell that repeat its own border, so mips do not bleed
CELL_COLS = 4
CELL_TOP = SHEET_H // 2
CELLS = [
    "door", "door_swing", "window", "window_barred",
    "sign_saloon", "sign_porch", "sign_blank", "poster",
    "barrel", "crate", "trough", "tank",
    "tabletop", "counter_front", "spare_1", "spare_2",
]
SPARE_SLOTS = [CELLS.index("spare_1"), CELLS.index("spare_2")]
CELL_NAMES = [c for i, c in enumerate(CELLS) if i not in SPARE_SLOTS]
assert len(CELLS) == CELL_COLS * 4

# The placeholder sheet the game wears until real art exists: one flat color per strip, pulled
# toward the town's flat palette. Blank is a light warm grey because it is the albedo of wheel
# caps and unwrapped round-part caps, and pure white would glare.
NEUTRAL_TINTS = {
    "Siding": (0.62, 0.48, 0.32), "Masonry": (0.57, 0.52, 0.47), "Shingles": (0.40, 0.31, 0.24),
    "Boards": (0.54, 0.40, 0.26), "Beam": (0.36, 0.26, 0.17), "Metal": (0.34, 0.36, 0.39),
    "Glass": (0.50, 0.62, 0.68), "Moulding": (0.78, 0.73, 0.62), "Blank": (0.87, 0.85, 0.81),
}
# The labelled debug sheet.
DEBUG_TINTS = {
    "Siding": (0.80, 0.62, 0.40), "Masonry": (0.62, 0.58, 0.54), "Shingles": (0.45, 0.30, 0.24),
    "Boards": (0.66, 0.50, 0.32), "Beam": (0.40, 0.28, 0.18), "Metal": (0.42, 0.46, 0.52),
    "Glass": (0.60, 0.78, 0.88), "Moulding": (0.88, 0.82, 0.68), "Blank": (1.0, 1.0, 1.0),
}
# A cell with no image is painted with the tint of the strip its objects would otherwise use.
CELL_STRIP = {
    "door": "Siding", "door_swing": "Siding", "window": "Glass", "window_barred": "Glass",
    "sign_saloon": "Siding", "sign_porch": "Boards", "sign_blank": "Siding",
    "poster": "Moulding", "barrel": "Boards", "crate": "Boards", "trough": "Metal",
    "tank": "Boards", "tabletop": "Boards", "counter_front": "Boards",
    "spare_1": "Blank", "spare_2": "Blank",
}


def cell_slot(name: str) -> int:
    return CELLS.index(name)


def cell_rect(slot: int) -> tuple[int, int, int, int]:
    """(x0, y0, x1, y1) in sheet pixels, y from the top, x1 and y1 exclusive."""
    x0 = (slot % CELL_COLS) * CELL_PX
    y0 = CELL_TOP + (slot // CELL_COLS) * CELL_PX
    return x0, y0, x0 + CELL_PX, y0 + CELL_PX


# Object name (Blender duplicate suffix removed) to cell. Anything else keeps its strip.
_NAME_RULES = [
    (re.compile(r"^Door$"), "door"),
    (re.compile(r"^Door[LR]$"), "door_swing"),
    (re.compile(r"^Win_"), "window"),
    (re.compile(r"^Sign$"), "sign_saloon"),
    (re.compile(r"^PorchSign$"), "sign_porch"),
    (re.compile(r"^Barrel"), "barrel"),
    (re.compile(r"^Crate[AB]$"), "crate"),
    (re.compile(r"^Trough$"), "trough"),
    (re.compile(r"^Tank$"), "tank"),
    (re.compile(r"^TableTop_"), "tabletop"),
]
_DUPLICATE = re.compile(r"\.\d{3}$")


def cell_for_name(object_name: str) -> str | None:
    name = _DUPLICATE.sub("", object_name)
    for pattern, cell in _NAME_RULES:
        if pattern.search(name):
            return cell
    return None


def building_key(root_name: str) -> str:
    """`bld_bank` is building `bank`; any other root (`saloon_interior`) is its own name."""
    return root_name[4:] if root_name.startswith("bld_") else root_name


def split_override(stem: str) -> tuple[str, str] | None:
    """`bld_general_store_door_swing` -> (`general_store`, `door_swing`), or None."""
    if not stem.startswith("bld_"):
        return None
    rest = stem[4:]
    for cell in sorted(CELL_NAMES, key=len, reverse=True):
        suffix = "_" + cell
        if rest.endswith(suffix) and len(rest) > len(suffix):
            return rest[:-len(suffix)], cell
    return None


class Manifest:
    """Which cells have an image, and which building owns an override slot."""

    def __init__(self, data: dict | None = None):
        data = data or {}
        self.cells: dict[str, dict] = data.get("cells", {})
        self.overrides: list[dict] = data.get("overrides", [])

    def slot_for(self, cell: str, building: str) -> int | None:
        """The slot to use for `cell` on `building`, or None when there is no image."""
        for entry in self.overrides:
            if entry["building"] == building and entry["cell"] == cell:
                return int(entry["slot"])
        info = self.cells.get(cell)
        if info and info.get("present"):
            return int(info["slot"])
        return None


def load_manifest(path: str = MANIFEST_PATH) -> Manifest:
    """An empty manifest (every cell absent) when the builder has not been run."""
    try:
        with open(path, encoding="utf-8") as f:
            return Manifest(json.load(f))
    except FileNotFoundError:
        return Manifest()
