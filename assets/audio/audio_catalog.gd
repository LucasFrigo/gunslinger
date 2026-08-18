class_name AudioCatalog
extends RefCounted
## Single swap path for combat / UI SFX. Today every cue comes from
## PlaceholderAudio; drop a real stream into `OVERRIDES` (or edit get_stream()) to
## replace one cue without touching call sites.
##
## Expected filenames when assets arrive (see assets/audio/README.md):
##   gunshot.ogg, click.ogg, dry_fire.ogg, bell.ogg, whizz.ogg,
##   impact_flesh.ogg, impact_world.ogg, ricochet.ogg, hurt.ogg,
##   near_miss_whoosh.ogg, shell_eject.ogg, chamber.ogg, duel_end.wav

const DUEL_END := preload("res://assets/audio/duel_end.wav")

## Optional: StringName cue → AudioStream. Checked before placeholders.
static var OVERRIDES: Dictionary = {}


static func get_stream(cue: StringName) -> AudioStream:
	if OVERRIDES.has(cue):
		return OVERRIDES[cue] as AudioStream
	match String(cue):
		"gunshot":
			return PlaceholderAudio.gunshot()
		"click":
			return PlaceholderAudio.click()
		"dry_fire":
			return PlaceholderAudio.dry_fire()
		"bell":
			return PlaceholderAudio.bell()
		"whizz":
			return PlaceholderAudio.whizz()
		"impact_flesh":
			return PlaceholderAudio.impact_flesh()
		"impact_world":
			return PlaceholderAudio.impact_world()
		"ricochet":
			return PlaceholderAudio.ricochet()
		"hurt":
			return PlaceholderAudio.hurt()
		"near_miss_whoosh":
			return PlaceholderAudio.near_miss_whoosh()
		"shell_eject":
			return PlaceholderAudio.shell_eject()
		"chamber":
			return PlaceholderAudio.chamber()
		"duel_end":
			return DUEL_END
		_:
			push_warning("AudioCatalog: unknown cue '%s'" % cue)
			return PlaceholderAudio.click()
