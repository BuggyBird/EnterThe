class_name MonsterData
extends Resource
## Pure data defining a monster type. Same philosophy as WeaponData: a new
## monster is a new .tres file — stats, AI temperament and attack all live
## here, and one generic Monster scene reads it. No code per monster.

@export var display_name: String = "Monster"

@export_group("Body")
@export var max_health: float = 20.0
@export var move_speed: float = 100.0
@export var tint: Color = Color.WHITE      ## Demo-sprite recolor per type.
@export var body_scale: float = 1.0

@export_group("Behaviour")
## The distance it tries to fight at: walks closer when farther, backs off
## when the player pushes in, drifts sideways while in the sweet spot.
@export var preferred_range: float = 160.0
@export var range_slack: float = 30.0      ## Dead zone around preferred_range.
## Gungeon-style cadence: a short WALK burst in one direction, then standing
## STILL for a beat (that's when it may telegraph and shoot), then walk again.
@export var walk_time_min: float = 0.4
@export var walk_time_max: float = 0.8
@export var pause_time_min: float = 0.5
@export var pause_time_max: float = 1.0

@export_group("Attack")
@export var projectile_scene: PackedScene
@export var projectile_data: ProjectileData
@export var fire_rate: float = 0.8         ## Attacks per second (cooldown = 1/rate).
@export var windup_time: float = 0.4       ## Telegraph flash before the shot flies.
@export var pellets: int = 1               ## Projectiles per attack (>1 = fan).
@export var spread_degrees: float = 0.0    ## Total fan width for the pellets.
@export var aim_error_degrees: float = 4.0 ## Random inaccuracy per shot.
