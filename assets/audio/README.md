# Audio assets

Real sounds go here. Until then, `placeholder_audio.gd` generates procedural
stand-ins (gunshot, whizz, bell, hammer click, dry fire).

To replace a sound, add the file here and swap the `PlaceholderAudio.*()`
call sites (search the project for `PlaceholderAudio.`) with a
`preload("res://assets/audio/<file>")`.
