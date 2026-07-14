class_name CompanionDog
extends AnimatedSprite2D
## The player's flying companion pup. Lives INSIDE player.tscn (so he spawns,
## despawns and changes scene with the player) but positions himself in world
## space via `top_level`, lazily drifting after his owner instead of being
## glued to them. He flies, so no collision or navigation — walls are beneath
## his dignity.

## Hover point relative to the player. The x side auto-mirrors to stay on the
## OPPOSITE side of the aim, so he never floats into the line of fire.
@export var follow_offset := Vector2(-36, -30)
## How eagerly he chases the hover point (higher = snappier, lower = lazier).
@export var stiffness := 8.0
## Extra slow bobbing on top of the sprite's own idle animation.
@export var bob_amount := 3.0
@export var bob_speed := 2.2
## Snap to the player if separated by more than this (room warps, regens).
@export var teleport_distance := 500.0

var _time := 0.0
## Smoothed position kept in floats; the node is drawn at its rounded value so
## the pixel art never sits between pixels of the low-res game viewport.
var _pos := Vector2.ZERO

@onready var _player: Player = get_parent() as Player


func _ready() -> void:
	top_level = true
	play(&"idle")
	if _player:
		_pos = _target()
		global_position = _pos.round()


## Physics tick, not _process: the player moves on the physics clock, so
## following on the same clock removes the relative jitter that made the
## companion smear/shimmer while sprinting.
func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_time += delta
	var target := _target()
	if _pos.distance_to(target) > teleport_distance:
		_pos = target
	else:
		# Frame-rate independent smoothing: he eases toward the hover point,
		# overshooting nothing, trailing naturally when the player sprints.
		_pos = _pos.lerp(target, 1.0 - exp(-stiffness * delta))
	# Snap the drawn position to whole pixels: at the 640x360 pixel viewport,
	# sub-pixel positions make the sprite shimmer whenever it moves.
	global_position = _pos.round()
	# Face where he's drifting; when settled, watch where the player aims.
	var dx := target.x - _pos.x
	if absf(dx) > 2.0:
		flip_h = dx < 0.0
	else:
		flip_h = _player.aim_direction.x < 0.0


## Current hover point: beside-and-above the player, mirrored away from the
## aim, with a slow sine bob so he floats rather than hangs.
func _target() -> Vector2:
	var side := 1.0 if _player.aim_direction.x < 0.0 else -1.0
	var offset := Vector2(absf(follow_offset.x) * side, follow_offset.y)
	return _player.global_position + offset \
		+ Vector2(0.0, sin(_time * bob_speed) * bob_amount)
