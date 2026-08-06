class_name AIArchetype
extends Resource
## Data-only definition of an AI duelist. New enemies are new .tres files;
## no code changes needed.

enum MoveStyle { STAND, STRAFE }

@export var display_name := "Duelist"
## Seconds after the bell before the AI starts drawing.
@export_range(0.05, 2.0, 0.01) var reaction_time := 0.45
@export_range(0.0, 1.0, 0.01) var reaction_variance := 0.15
## Seconds for the draw animation (holster -> aimed).
@export_range(0.1, 2.0, 0.01) var draw_time := 0.5
## Half-angle of the aim error cone, in degrees. 0 = aimbot.
@export_range(0.0, 20.0, 0.1) var accuracy_angle_deg := 4.0
## Seconds between follow-up shots if the first one misses.
@export_range(0.3, 3.0, 0.05) var followup_interval := 1.1
@export_range(20.0, 120.0, 1.0) var bullet_speed := 50.0
@export_range(0.5, 10.0, 0.5) var health := 1.0
@export var move_style: MoveStyle = MoveStyle.STAND
@export_range(0.0, 3.0, 0.1) var strafe_speed := 1.0
## Placeholder body tint until real character assets arrive.
@export var body_color := Color(0.45, 0.3, 0.2)
