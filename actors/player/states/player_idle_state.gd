extends State
## Player is standing still: decelerate to a stop and watch for input.

@onready var player: Player = owner


func physics_update(delta: float) -> void:
	player.apply_friction(player.friction, delta)
	if player.get_move_input() != Vector2.ZERO:
		transitioned.emit(&"move")


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("dodge") and player.can_roll:
		transitioned.emit(&"dodgeroll")
