class_name Coin
extends Area2D
## A dropped gold coin. Scatters outward from where the enemy died, skids to a
## stop, and is collected by the player walking over it. Feeds GameState.gold.

@export var value := 5
@export var scatter_speed_min := 50.0
@export var scatter_speed_max := 130.0
@export var friction := 260.0
@export var lifetime := 25.0   ## Despawn eventually so long fights don't litter.

var _vel := Vector2.ZERO
## Float position, drawn rounded so the tiny sprite never shimmers sub-pixel.
var _pos := Vector2.ZERO
var _age := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_pos = global_position
	_vel = Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU)) \
		* RNG.randf_range(scatter_speed_min, scatter_speed_max)
	var anim: AnimatedSprite2D = $Anim
	anim.play(&"spin")
	anim.frame = RNG.randi_range(0, anim.sprite_frames.get_frame_count(&"spin") - 1)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	_vel = _vel.move_toward(Vector2.ZERO, friction * delta)
	_pos += _vel * delta
	global_position = _pos.round()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		GameState.add_gold(value)
		queue_free()
