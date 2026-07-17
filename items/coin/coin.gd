class_name Coin
extends Area2D
## A dropped gold coin. Scatters outward from where the enemy died, skids to a
## stop, and is collected by the player walking over it. Feeds GameState.gold.
## A small magnet homes the coin onto the player once they come close; its
## reach scales with Upgrades.coin_magnet_mult so augments/items can grow it.

@export var value := 5
@export var scatter_speed_min := 50.0
@export var scatter_speed_max := 130.0
@export var friction := 260.0
@export var lifetime := 25.0   ## Despawn eventually so long fights don't litter.
@export var pull_radius := 48.0    ## Base magnet reach (px); scaled by Upgrades.coin_magnet_mult.
@export var pull_speed := 340.0    ## Top homing speed (px/s) — faster than the player walks.
@export var pull_accel := 1400.0   ## How quickly the pull ramps up (px/s^2).

var _vel := Vector2.ZERO
## Float position, drawn rounded so the tiny sprite never shimmers sub-pixel.
## Latched on the first physics frame, NOT in _ready: the spawner sets our
## global_position AFTER add_child (so after _ready), and reading it too early
## would snap the coin back to the origin instead of the drop point.
var _pos := Vector2.ZERO
var _pos_ready := false
var _age := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_vel = Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU)) \
		* RNG.randf_range(scatter_speed_min, scatter_speed_max)
	var anim: AnimatedSprite2D = $Anim
	anim.play(&"spin")
	anim.frame = RNG.randi_range(0, anim.sprite_frames.get_frame_count(&"spin") - 1)


func _physics_process(delta: float) -> void:
	if not _pos_ready:
		_pos = global_position   # the spawner's position is set by now
		_pos_ready = true
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player != null \
			and _pos.distance_to(player.global_position) <= pull_radius * Upgrades.coin_magnet_mult:
		# In magnet range: home onto the player, overriding the scatter skid.
		var dir := _pos.direction_to(player.global_position)
		_vel = _vel.move_toward(dir * pull_speed, pull_accel * delta)
	else:
		_vel = _vel.move_toward(Vector2.ZERO, friction * delta)
	_pos += _vel * delta
	global_position = _pos.round()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		GameState.add_gold(value)
		queue_free()
