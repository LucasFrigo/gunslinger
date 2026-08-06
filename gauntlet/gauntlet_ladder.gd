class_name GauntletLadder
extends Resource
## An ordered tower of duel encounters.

@export var display_name := "The Gauntlet"
@export var lives := 3
@export var encounters: Array[DuelEncounter] = []
