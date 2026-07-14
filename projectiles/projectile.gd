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

## Emitted once, on this projectile's FIRST damaging hit. Weapons listen to it
## for hit-driven mechanics (the bonerang's throw combo).
signal hit_landed()

const HIT_EFFECT := preload("res://effects/hit_effect.tscn")

var data: ProjectileData
var direction: Vector2 = Vector2.RIGHT
## Which side a curving projectile steers toward: +1 right, -1 left, 0 straight.
## Set by the Weapon after setup() (alternates per pellet for boomerangs).
var curve_sign: float = 0.0
## Team flag, set BEFORE add_child. true = player shot (default, PlayerHitbox
## layer, buffed by Upgrades). false = enemy shot: re-layered to EnemyHitbox
## vs World+PlayerHurtbox and fired at raw data stats — player upgrades must
## never buff the bullets flying AT the player.
var friendly: bool = true

var _spawn_position: Vector2
var _prev_position: Vector2
var _time_alive: float = 0.0
var _pierced: int = 0
var _hit_reported: bool = false
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
		# queue_free is deferred — physics would still tick us once this frame
		# and crash on the missing data, so switch processing off first.
		set_physics_process(false)
		queue_free()
		return
	global_position = _spawn_position
	_prev_position = _spawn_position
	rotation = direction.angle()
	if friendly:
		_radius = data.radius * Upgrades.bullet_size_mult
		_speed = data.speed * Upgrades.bullet_speed_mult
		_bounces_left = Upgrades.bounces
	else:
		_radius = data.radius
		_speed = data.speed
		_bounces_left = 0
		collision_layer = 16   # EnemyHitbox
		collision_mask = 33    # World + PlayerHurtbox
	# Own our collision shape so per-projectile radius never mutates a shared one.
	var shape := CircleShape2D.new()
	shape.radius = _radius
	$CollisionShape2D.shape = shape
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if data == null:
		return
	if data.curve_degrees != 0.0 and curve_sign != 0.0:
		direction = direction.rotated(deg_to_rad(data.curve_degrees) * curve_sign * delta)
	_prev_position = global_position
	global_position += direction * _speed * delta
	if data.spin_speed != 0.0:
		rotation += data.spin_speed * (curve_sign if curve_sign != 0.0 else 1.0) * delta
	elif data.curve_degrees != 0.0:
		rotation = direction.angle()
	_time_alive += delta
	if _time_alive >= data.lifetime:
		_despawn()


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		var dmg := data.damage * _distance_damage_mult()
		var pierce_budget := data.pierce
		if friendly:
			dmg *= Upgrades.damage_mult
			pierce_budget += Upgrades.pierce_bonus
		area.take_hit(DamageInfo.new(dmg, self, direction * data.knockback))
		if not _hit_reported:
			_hit_reported = true
			hit_landed.emit()
		_spawn_hit_effect()
		_pierced += 1
		if _pierced > pierce_budget:
			_despawn()


## Longbow-style range reward: damage scales with the distance travelled from
## the muzzle to the impact point, capped so it can't grow without bound.
func _distance_damage_mult() -> float:
	if data.distance_damage_per_100 <= 0.0:
		return 1.0
	var travelled := _spawn_position.distance_to(global_position)
	return minf(1.0 + data.distance_damage_per_100 * travelled / 100.0,
		data.distance_damage_max_mult)


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


## Visual: the data's sprite if it has one (drawn in its authored colors),
## otherwise a placeholder circle tinted by the data.
func _draw() -> void:
	if data == null:
		return
	if data.texture:
		var size := data.texture.get_size() * data.texture_scale
		draw_texture_rect(data.texture, Rect2(-size * 0.5, size), false)
	else:
		draw_circle(Vector2.ZERO, _radius, data.color)
