class_name Projectile
extends Area2D
## A moving damage dealer, configured entirely from a ProjectileData resource.
## Deals damage directly to HurtboxComponents (cheaper than an extra child node
## for the thousands of bullets a bullet-hell run spawns) and despawns on walls
## or when its lifetime/pierce budget runs out.
##
## Spawn flow: instantiate -> setup(data, direction, position) -> add_child.
## Collision is configured in the scene: layer = shooter's hitbox layer,
## mask = target hurtbox layer(s) + World, so it only hits the intended team.
##
## Player upgrades (Upgrades autoload) scale damage/size/speed, extend pierce,
## and grant wall bounces. NOTE for M4: these are PLAYER buffs — when enemies
## start firing this scene, gate the Upgrades reads behind a team flag.

const HIT_EFFECT := preload("res://effects/hit_effect.tscn")

var data: ProjectileData
var direction: Vector2 = Vector2.RIGHT

var _spawn_position: Vector2
var _prev_position: Vector2
var _time_alive: float = 0.0
var _pierced: int = 0
var _bounces_left: int = 0
var _bouncing: bool = false
var _radius: float = 4.0
var _speed: float = 620.0


## Configure the projectile BEFORE adding it to the tree.
func setup(projectile_data: ProjectileData, dir: Vector2, spawn_position: Vector2) -> void:
	data = projectile_data
	direction = dir.normalized()
	_spawn_position = spawn_position


func _ready() -> void:
	if data == null:
		push_warning("Projectile spawned without data; freeing.")
		queue_free()
		return
	global_position = _spawn_position
	_prev_position = _spawn_position
	rotation = direction.angle()
	_radius = data.radius * Upgrades.bullet_size_mult
	_speed = data.speed * Upgrades.bullet_speed_mult
	_bounces_left = Upgrades.bounces
	# Own our collision shape so per-projectile radius never mutates a shared one.
	var shape := CircleShape2D.new()
	shape.radius = _radius
	$CollisionShape2D.shape = shape
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_prev_position = global_position
	global_position += direction * _speed * delta
	_time_alive += delta
	if _time_alive >= data.lifetime:
		_despawn()


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		var dmg := data.damage * Upgrades.damage_mult
		area.take_hit(DamageInfo.new(dmg, self, direction * data.knockback))
		_spawn_hit_effect()
		_pierced += 1
		if _pierced > data.pierce + Upgrades.pierce_bonus:
			_despawn()


## Burst of placeholder particles at the impact point, tinted like the bullet.
func _spawn_hit_effect() -> void:
	var parent := get_tree().current_scene
	if parent == null:
		return
	var fx: HitEffect = HIT_EFFECT.instantiate()
	fx.setup(data.color)
	parent.add_child(fx)
	fx.global_position = global_position


func _on_body_entered(_body: Node2D) -> void:
	# Anything on our mask that is a physics body (i.e. a wall) stops the shot —
	# unless it still has bounces, then it ricochets instead.
	if _bounces_left > 0 and not _bouncing:
		_bounces_left -= 1
		_bouncing = true
		# Deferred: this callback runs during the physics flush, where space
		# queries (the normal-finding raycast) are locked.
		_bounce.call_deferred()
	else:
		_despawn()


## Reflect off the wall we just hit: raycast from the last safe position along
## our travel to find the surface normal, mirror the direction, and step back out.
func _bounce() -> void:
	if not is_inside_tree():
		return
	var space := get_world_2d().direct_space_state
	var travel := direction * (_speed * get_physics_process_delta_time() + _radius * 2.0 + 4.0)
	var query := PhysicsRayQueryParameters2D.create(_prev_position - direction * _radius,
		_prev_position + travel)
	query.collision_mask = 1  # World
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		_despawn()
		return
	direction = direction.bounce(hit["normal"]).normalized()
	global_position = Vector2(hit["position"]) + Vector2(hit["normal"]) * (_radius + 1.0)
	rotation = direction.angle()
	_bouncing = false


func _despawn() -> void:
	# TODO (juice milestone): spawn an impact spark/particle here.
	queue_free()


## Placeholder visual: a filled circle tinted by the data. Real art later.
func _draw() -> void:
	if data:
		draw_circle(Vector2.ZERO, _radius, data.color)
