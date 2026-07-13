class_name Weapon
extends Node2D
## Runtime firer. Holds a WeaponData and executes it: cooldown, pellets, spread,
## ammo, and reloading. It is generic — swapping weapons means calling `equip`
## with a different WeaponData and its saved ammo state. The WeaponHolder owns
## the inventory and per-weapon ammo; this node just fires whatever it's given.

signal fired()
signal reload_started()
signal reload_finished()
signal ammo_changed(clip: int, reserve: int)

var data: WeaponData
var clip: int = 0
var reserve: int = 0  ## -1 means infinite.

var _cooldown: float = 0.0
var _reloading: bool = false
var _reload_left: float = 0.0


## Load a weapon and its current ammo state (supplied by the WeaponHolder).
func equip(weapon_data: WeaponData, current_clip: int, current_reserve: int) -> void:
	data = weapon_data
	clip = current_clip
	reserve = current_reserve
	_reloading = false
	_cooldown = 0.0
	_emit_ammo()


func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if _reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()


func can_fire() -> bool:
	return data != null and not _reloading and _cooldown <= 0.0 and clip > 0


## Fire toward `aim_direction` from world-space `origin`. Auto-reloads on empty.
func try_fire(aim_direction: Vector2, origin: Vector2) -> void:
	if data == null or _reloading or _cooldown > 0.0:
		return
	if clip <= 0:
		start_reload()
		return
	_cooldown = 1.0 / (data.fire_rate * Upgrades.fire_rate_mult)
	clip -= 1
	_spawn_projectiles(aim_direction, origin)
	fired.emit()
	EventBus.weapon_fired.emit()
	_emit_ammo()
	if clip <= 0:
		start_reload()


func start_reload() -> void:
	if _reloading or data == null:
		return
	if clip >= data.mag_size or reserve == 0:
		return  # already full, or no reserve ammo to load
	_reloading = true
	_reload_left = data.reload_time
	reload_started.emit()


func _finish_reload() -> void:
	_reloading = false
	var needed := data.mag_size - clip
	if reserve < 0:
		clip = data.mag_size  # infinite reserve
	else:
		var take: int = min(needed, reserve)
		clip += take
		reserve -= take
	_emit_ammo()
	reload_finished.emit()


func _spawn_projectiles(aim_direction: Vector2, origin: Vector2) -> void:
	for i in data.pellets:
		var offset := deg_to_rad(RNG.randf_range(-data.spread_degrees * 0.5, data.spread_degrees * 0.5))
		var dir := aim_direction.rotated(offset)
		var projectile := data.projectile_scene.instantiate()
		projectile.setup(data.projectile_data, dir, origin)
		_get_projectile_parent().add_child(projectile)


func _get_projectile_parent() -> Node:
	var scene := get_tree().current_scene
	return scene if scene else get_tree().root


func _emit_ammo() -> void:
	ammo_changed.emit(clip, reserve)
	EventBus.weapon_ammo_changed.emit(clip, reserve)
