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
var _charging: bool = false
var _charge_time: float = 0.0
var _burst_left: int = 0        ## Salvo shots still to fire after a charge release.
var _burst_gap: float = 0.0
var _channeling: bool = false   ## Mid-draw (channel_time weapons); fires when it elapses.
var _channel_left: float = 0.0
var _track_aim: Vector2 = Vector2.RIGHT   ## Live aim/origin fed by the player so a
var _track_origin: Vector2 = Vector2.ZERO ## salvo follows the cursor mid-burst.
var _combo_hits: int = 0        ## Landed hits driving the curve-combo throw cycle.


## Load a weapon and its current ammo state (supplied by the WeaponHolder).
func equip(weapon_data: WeaponData, current_clip: int, current_reserve: int) -> void:
	data = weapon_data
	clip = current_clip
	reserve = current_reserve
	_reloading = false
	_cooldown = 0.0
	_charging = false
	_charge_time = 0.0
	_burst_left = 0
	_channeling = false
	_combo_hits = 0
	_emit_ammo()


func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if _burst_left > 0:
		_burst_gap -= delta
		if _burst_gap <= 0.0:
			_fire_burst_shot()
	if _channeling:
		_channel_left -= delta
		if _channel_left <= 0.0:
			_channeling = false
			_execute_fire(_track_aim, _track_origin)
	if _reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()


func can_fire() -> bool:
	return data != null and not _reloading and _cooldown <= 0.0 and clip > 0


## Fire toward `aim_direction` from world-space `origin`. Auto-reloads on empty.
## Channel weapons (channel_time > 0) start their draw here instead and loose
## automatically when it completes, at the live-tracked aim.
func try_fire(aim_direction: Vector2, origin: Vector2) -> void:
	if data == null or _reloading or _cooldown > 0.0 or _channeling:
		return
	if data.projectile_scene == null or data.projectile_data == null:
		push_warning("WeaponData '%s' is missing projectile_scene/projectile_data." % data.id)
		return
	if clip <= 0:
		start_reload()
		return
	if data.channel_time > 0.0:
		_channeling = true
		_channel_left = data.channel_time
		update_burst_track(aim_direction, origin)
		return
	_execute_fire(aim_direction, origin)


## The actual shot: pay ammo, spawn, signal. Shared by instant fire, the end
## of a channel, and (via _fire_burst_shot's own clip handling) NOT the salvo.
func _execute_fire(aim_direction: Vector2, origin: Vector2) -> void:
	_cooldown = 1.0 / (data.fire_rate * Upgrades.fire_rate_mult)
	clip -= 1
	_spawn_projectiles(aim_direction, origin)
	fired.emit()
	EventBus.weapon_fired.emit()
	_emit_ammo()
	if clip <= 0:
		start_reload()


## 0..1 draw progress of a channel weapon — drives the sprite pull-back.
func channel_ratio() -> float:
	if not _channeling or data == null or data.channel_time <= 0.0:
		return 0.0
	return clampf(1.0 - _channel_left / data.channel_time, 0.0, 1.0)


## True for weapons fired by holding to bank shots and releasing (crossbow).
func is_chargeable() -> bool:
	return data != null and data.charge_max_shots > 0


## Bank charge while the trigger is held. Call every frame the input is down.
func charge(delta: float) -> void:
	if data == null or _reloading or _burst_left > 0:
		return
	if clip <= 0:
		start_reload()
		return
	_charging = true
	_charge_time += delta


## Keep the salvo aimed: the player feeds the live aim/muzzle every frame so
## bolts fired mid-burst follow the cursor and the moving player.
func update_burst_track(aim_direction: Vector2, origin: Vector2) -> void:
	_track_aim = aim_direction
	_track_origin = origin


## 0..1 how charged we are — drives the held-sprite grow feedback.
func charge_ratio() -> float:
	if not _charging or data == null or data.charge_max_shots <= 1:
		return 0.0
	var full := data.charge_time_per_shot * float(data.charge_max_shots - 1)
	return clampf(_charge_time / full, 0.0, 1.0)


## Shots currently banked: 1 for a tap, +1 per charge_time_per_shot held,
## never more than the clip can pay for.
func charged_shots() -> int:
	if data == null:
		return 0
	var banked := 1 + int(_charge_time / data.charge_time_per_shot)
	return mini(mini(banked, data.charge_max_shots), clip)


## Loose the banked shots as a rapid salvo: the first bolt leaves immediately,
## the rest follow one per charge_burst_interval (each paid from the clip as it
## fires, each kicking recoil/HUD via the normal fired signals).
func release_charge(aim_direction: Vector2, origin: Vector2) -> void:
	if not _charging:
		return
	var shots := charged_shots()
	_charging = false
	_charge_time = 0.0
	if data == null or _reloading or shots <= 0 or _cooldown > 0.0:
		return
	_cooldown = 1.0 / (data.fire_rate * Upgrades.fire_rate_mult)
	update_burst_track(aim_direction, origin)
	_burst_left = shots
	_fire_burst_shot()


## One shot of the running salvo, aimed at the live-tracked cursor.
func _fire_burst_shot() -> void:
	if clip <= 0:
		_burst_left = 0
		start_reload()
		return
	_burst_left -= 1
	_burst_gap = data.charge_burst_interval
	clip -= 1
	_spawn_projectiles(_track_aim, _track_origin)
	fired.emit()
	EventBus.weapon_fired.emit()
	_emit_ammo()
	if clip <= 0:
		_burst_left = 0
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
	if data.curve_combo and data.projectile_data.curve_degrees != 0.0:
		_spawn_combo_throw(aim_direction, origin)
		return
	for i in data.pellets:
		var offset := deg_to_rad(RNG.randf_range(-data.spread_degrees * 0.5, data.spread_degrees * 0.5))
		# Curving pellets alternate side by index; straight shots don't curve.
		var curve := 0.0
		if data.projectile_data.curve_degrees != 0.0:
			curve = 1.0 if i % 2 == 0 else -1.0
		_spawn_one(aim_direction.rotated(offset), origin, curve)


## How far outward each boomerang of the dual throw launches before its curve
## bends it back across the aim line (the pincer).
const DUAL_LAUNCH_DEGREES := 40.0


## The bonerang's hit-driven cycle: landed hits (not throws) advance the stage —
## stage 0 throws a LEFT curver, stage 1 a RIGHT curver, stage 2 BOTH hands
## launched fanned outward and curving back inward, closing like pincers.
## A miss leaves the counter alone, so the same throw repeats until it connects.
func _spawn_combo_throw(aim_direction: Vector2, origin: Vector2) -> void:
	var stage := _combo_hits % 3
	if stage == 2:
		var off := deg_to_rad(DUAL_LAUNCH_DEGREES)
		_hook_combo(_spawn_one(aim_direction.rotated(-off), origin, 1.0))
		_hook_combo(_spawn_one(aim_direction.rotated(off), origin, -1.0))
		return
	_hook_combo(_spawn_one(aim_direction, origin, -1.0 if stage == 0 else 1.0))


func _hook_combo(projectile: Projectile) -> void:
	projectile.hit_landed.connect(func(): _combo_hits += 1)


## Spawn a single projectile steering toward `curve` side (+1 right, -1 left,
## 0 straight). Returns it so callers can hook its signals.
func _spawn_one(dir: Vector2, origin: Vector2, curve: float) -> Projectile:
	var projectile: Projectile = data.projectile_scene.instantiate()
	projectile.setup(data.projectile_data, dir, origin)
	projectile.curve_sign = curve
	_get_projectile_parent().add_child(projectile)
	return projectile


func _get_projectile_parent() -> Node:
	var scene := get_tree().current_scene
	return scene if scene else get_tree().root


func _emit_ammo() -> void:
	ammo_changed.emit(clip, reserve)
	EventBus.weapon_ammo_changed.emit(clip, reserve)
