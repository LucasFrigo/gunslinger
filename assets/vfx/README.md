# VFX placeholders

One-shot `GPUParticles3D` bursts for combat feedback. Swap art without
changing call sites:

```gdscript
VfxCatalog.OVERRIDES[&"blood_burst"] = preload("res://assets/vfx/blood_burst_real.tscn")
```

| Cue | Scene | Role |
|---|---|---|
| `muzzle_smoke` | `muzzle_smoke.tscn` | Light smoke at muzzle (`puff.gdshader`) |
| `barrel_smoke` | `barrel_smoke.tscn` | Lingering wisp parented to the weapon's `Muzzle`, ~2.4 s (`puff.gdshader`; spawned by `ImpactFeedback.shot_fired`, pooled like `muzzle_smoke`; F3 `barrel_smoke_lifetime`) |
| `engine_smoke` | `engine_smoke.tscn` | Looping stack plume, instanced by `train_rooftop.tscn` (not spawned through `VfxCatalog.spawn`; listed so the boot warmup compiles it); `scenarios/train_rooftop/engine_smoke.gd`, F3 `engine_smoke_density` (`puff.gdshader`) |
| `world_dust` | `world_dust.tscn` | Dust on environment hits (`puff.gdshader`) |
| `wood_chip` | `wood_chip.tscn` | Wood chips / grit on world hits |
| `blood_burst` | `blood_burst.tscn` | Flesh impact (head uses denser scale) |
| `near_miss_whoosh` | `near_miss_whoosh.tscn` | Subtle grit near the head |
