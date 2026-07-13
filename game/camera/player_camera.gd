extends Camera2D
## Twin-stick camera. Child of the Player; follows automatically and biases the
## view slightly toward where the player is aiming ("lookahead") so more of the
## space in the aim direction is visible. Smoothed for a soft, non-jerky feel.

@export var lookahead_distance := 46.0  ## How far to lean toward the aim (px).
@export var smoothing := 9.0            ## Higher = snappier follow.

@onready var player: Player = owner


func _physics_process(delta: float) -> void:
	# `position` is local to the player, so a zero target keeps us centered.
	var target := player.aim_direction * lookahead_distance
	# Frame-rate-independent exponential smoothing.
	position = position.lerp(target, 1.0 - exp(-smoothing * delta))
