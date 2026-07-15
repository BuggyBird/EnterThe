extends State
## Player is walking: accelerate toward the input direction.

@onready var player: Player = owner


func enter() -> void:
	player.sprite.play(&"walk")


func physics_update(delta: float) -> void:
	var direction := player.get_move_input()
	if direction == Vector2.ZERO:
		transitioned.emit(&"idle")
		return
	player.apply_movement(direction, player.move_speed, player.acceleration, delta)


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("dodge") and player.can_roll:
		transitioned.emit(&"dodgeroll")
