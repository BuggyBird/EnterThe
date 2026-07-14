class_name Monster
extends CharacterBody2D
## A generic ranged monster, configured entirely from a MonsterData resource.
## AI: hold the type's preferred fighting distance (advance / retreat / strafe),
## and when the attack cooldown is up AND it has line of sight, telegraph with
## a flash, then loose a fan of enemy projectiles at the player.
##
## One scene serves every monster type — spawn it, assign `data`, add_child.

@export var data: MonsterData

@onready var sprite: Sprite2D = $Sprite
@onready var health: HealthComponent = $Health
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var health_bar: HealthBar2D = $HealthBar

var _base_color := Color.WHITE
var _cooldown := 0.0
var _windup := 0.0          ## >0 while telegraphing the next shot.
var _walk_timer := 0.0      ## >0 = mid walk-burst.
var _pause_timer := 0.0     ## >0 = standing still between bursts.
var _walk_dir := Vector2.ZERO
var _dying := false


func _ready() -> void:
	# Wire component refs in code (exported node paths don't resolve reliably
	# in hand-authored scenes) and pour the data resource into them.
	hurtbox.health_component = health
	health_bar.track(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	if data:
		health.max_health = data.max_health
		health.current_health = data.max_health
		sprite.modulate = data.tint
		scale *= data.body_scale
	_base_color = sprite.modulate
	# Stagger first attacks/steps so a room of monsters doesn't act in sync.
	_cooldown = RNG.randf_range(0.4, 1.2)
	_pause_timer = RNG.randf_range(0.1, 0.6)


func _physics_process(delta: float) -> void:
	if _dying or data == null:
		return
	var player := _find_player()
	if player == null:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	sprite.flip_h = to_player.x < 0.0

	if _windup > 0.0:
		# Committed to the shot: stand still and finish the telegraph.
		velocity = Vector2.ZERO
		_windup -= delta
		if _windup <= 0.0:
			_fire(to_player.normalized())
		return

	_move(to_player, dist, delta)
	_cooldown -= delta
	# Gungeon rhythm: shots only come while standing still, so movement and
	# firing read as separate, dodgeable beats instead of a constant blur.
	if _cooldown <= 0.0 and _pause_timer > 0.0 and _has_line_of_sight(player):
		_windup = data.windup_time
		_telegraph()


## Walk-burst / stand-still cadence. A burst heads roughly where the range
## logic wants to be (closer / away / sideways) with a random slew, then the
## monster plants itself for a beat — that pause is its shooting window.
func _move(to_player: Vector2, dist: float, delta: float) -> void:
	if _pause_timer > 0.0:
		_pause_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
		move_and_slide()
		if _pause_timer <= 0.0:
			_start_walk(to_player, dist)
		return
	_walk_timer -= delta
	velocity = velocity.move_toward(_walk_dir * data.move_speed, 900.0 * delta)
	move_and_slide()
	if _walk_timer <= 0.0:
		_pause_timer = RNG.randf_range(data.pause_time_min, data.pause_time_max)


func _start_walk(to_player: Vector2, dist: float) -> void:
	var base := to_player.normalized()
	if dist < data.preferred_range - data.range_slack:
		base = -base
	elif dist <= data.preferred_range + data.range_slack:
		base = base.orthogonal() * (1.0 if RNG.chance(0.5) else -1.0)
	_walk_dir = base.rotated(deg_to_rad(RNG.randf_range(-35.0, 35.0)))
	_walk_timer = RNG.randf_range(data.walk_time_min, data.walk_time_max)


## Loose the volley: an even fan of `pellets` across spread_degrees, the whole
## fan nudged by a little aim error so shots stay dodgeable.
func _fire(aim: Vector2) -> void:
	_cooldown = 1.0 / data.fire_rate
	aim = aim.rotated(deg_to_rad(RNG.randf_range(-data.aim_error_degrees, data.aim_error_degrees)))
	for i in data.pellets:
		var dir := aim
		if data.pellets > 1:
			var half := data.spread_degrees * 0.5
			dir = aim.rotated(deg_to_rad(lerpf(-half, half, float(i) / float(data.pellets - 1))))
		var projectile: Projectile = data.projectile_scene.instantiate()
		projectile.setup(data.projectile_data, dir, global_position)
		projectile.friendly = false
		get_tree().current_scene.add_child(projectile)


## Don't shoot (or start telegraphing) through walls.
func _has_line_of_sight(player: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(
		global_position, player.global_position, 1)  # World only
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _find_player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


## Telegraph: a bright pulse that fades over the windup, so the player reads
## "this one is about to shoot" and can start dodging.
func _telegraph() -> void:
	sprite.modulate = Color(2.5, 2.0, 1.6)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", _base_color, data.windup_time)


func _on_damaged(info: DamageInfo) -> void:
	sprite.modulate = Color(3.0, 3.0, 3.0)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", _base_color, 0.15)
	if info.knockback != Vector2.ZERO:
		velocity += info.knockback.normalized() * 90.0


func _on_died() -> void:
	_dying = true
	hurtbox.set_deferred("monitorable", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
