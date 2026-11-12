# Texture sources

Every image in `strips/` and `cells/` is listed here with where it came from and its licence. CC0 (Poly Haven, ambientCG) is preferred. Do not add a file whose licence is not recorded.

Build the sheet with `python dev/build_trim_sheet.py`; the layout and rules are in `docs/TEXTURING.md`.

## Naming

- `strips/<strip>.png`: `siding`, `masonry`, `shingles`, `boards`, `beam`, `metal`, `glass`, `moulding`, `blank`. Seamless left to right; any size.
- `cells/<cell>.png`: one of `door`, `door_swing`, `window`, `window_barred`, `sign_saloon`, `sign_porch`, `sign_blank`, `poster`, `barrel`, `crate`, `trough`, `tank`, `tabletop`, `counter_front`. Any size and shape; squashed to 128x128.
- `cells/bld_<building>_<cell>.png`: overrides `<cell>` for one building (`bld_bank_door.png`; `<building>` is the root name without `bld_`). Each override takes one of the 2 spare cell slots, in filename order. A third one fails the build.
- A cell with no file is painted a plain tint and the objects that would use it keep their strip.

## Files

| File | Source (URL / photographer) | Licence | Date added |
|---|---|---|---|
| (none yet) | | | |
