extends State
## Player is dodge-rolling: a short, fixed-duration burst of speed.
##
## Rolls commit to a direction on entry (movement input, or aim direction if
## standing still). Later milestones will grant invulnerability frames here by
## disabling the player's hurtbox for the roll's duration.

@onready var player: Player = owner

var _roll_direction := Vector2.RIGHT
var _time_left := 0.0


func enter() -> void:
	var input_dir := player.get_move_input()
	_roll_direction = input_dir if input_dir != Vector2.ZERO else player.aim_direction
	_time_left = player.roll_duration
	player.start_roll_cooldown()
	player.set_invulnerable(true)  # i-frames: untouchable during the roll
	EventBus.player_dodged.emit()
	# Placeholder feedback until real animation/VFX exist: fade during the roll.
	player.modulate = Color(1.0, 1.0, 1.0, 0.55)


func physics_update(delta: float) -> void:
	_time_left -= delta
	player.velocity = _roll_direction * player.roll_speed
	player.move_and_slide()
	if _time_left <= 0.0:
		transitioned.emit(&"idle")


func exit() -> void:
	player.set_invulnerable(false)  # end i-frames
	player.modulate = Color.WHITE
