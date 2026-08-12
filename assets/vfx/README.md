# VFX placeholders

One-shot `GPUParticles3D` bursts for combat feedback. Swap art without
changing call sites:

```gdscript
VfxCatalog.OVERRIDES[&"blood_burst"] = preload("res://assets/vfx/blood_burst_real.tscn")
```

| Cue | Scene | Role |
|---|---|---|
| `muzzle_smoke` | `muzzle_smoke.tscn` | Light smoke at muzzle |
| `world_dust` | `world_dust.tscn` | Dust on environment hits |
| `wood_chip` | `wood_chip.tscn` | Wood chips / grit on world hits |
| `blood_burst` | `blood_burst.tscn` | Flesh impact (head uses denser scale) |
| `near_miss_whoosh` | `near_miss_whoosh.tscn` | Subtle grit near the head |
