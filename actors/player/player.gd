class_name Player
extends CharacterBody2D
## The player avatar: twin-stick movement + aim + dodge roll.
##
## Movement/dodge behaviour lives in the child State nodes under StateMachine.
## This script owns shared data (stats, aim) and small helper methods the states
## call, so the states stay tiny and focused. Combat (weapons, health) is added
## in later milestones via components.

@export_group("Movement")
@export var move_speed := 220.0        ## Top movement speed (px/s).
@export var acceleration := 2000.0     ## How fast we reach top speed (px/s^2).
@export var friction := 2400.0         ## How fast we stop when no input (px/s^2).

@export_group("Dodge Roll")
@export var roll_speed := 470.0        ## Speed during a roll (px/s).
@export var roll_duration := 0.28      ## How long a roll lasts (s).
@export var roll_cooldown := 0.45      ## Delay before rolling again (s).

@export_group("Weapon Recoil")
@export var recoil_kick := 7.0         ## Backward jolt of the held weapon per shot (px).
@export var recoil_max := 13.0         ## Cap so rapid fire doesn't slide the gun away (px).
@export var recoil_return := 95.0      ## How fast the weapon settles back (px/s).
@export var recoil_tilt := 0.03        ## Muzzle-rise rotation per px of kick (radians).

@export_group("Light")
## The player carries a soft circle of light through the darkened dungeon. `light_radius`
## is read every frame, so changing it at runtime (a torch upgrade, a pickup, a
## flicker, fading out on death) grows or shrinks the lit circle live.
@export var light_enabled := true
@export var light_radius := 240.0                       ## Radius of the lit circle (px).
@export var light_energy := 1.25                        ## Brightness of the light.
@export var light_color := Color(1.0, 0.93, 0.78)       ## Warm torch tint.
## Organic wobble so the circle breathes over time. Kept small/slow so it's a gentle
## breathe, not a vibration. 0 = perfectly steady.
@export var light_flicker := 0.02                        ## Fraction the radius/energy wavers by.
@export var light_flicker_speed := 2.5

## Unit vector from the player toward the aim target (mouse). Read by states,
## the camera, and later the weapon system for firing direction.
var aim_direction := Vector2.RIGHT
## False while a roll is on cooldown.
var can_roll := true

@onready var aim_pivot: Node2D = $AimPivot
@onready var muzzle: Marker2D = $AimPivot/Muzzle
@onready var aim_ray: RayCast2D = $AimPivot/AimRay
@onready var aim_line: Line2D = $AimPivot/AimLine
@onready var weapon_sprite: Sprite2D = $AimPivot/WeaponSprite
@onready var weapon_holder: WeaponHolder = $WeaponHolder
@onready var health: HealthComponent = $Health
@onready var hurtbox: HurtboxComponent = $Hurtbox

## The scene's designed sprite scale; each weapon's `sprite_scale` multiplies this.
var _base_weapon_scale := Vector2.ONE
## The held weapon's resting local position (recoil kicks back from here).
var _base_weapon_pos := Vector2.ZERO
## Current backward recoil displacement, decaying to 0 each frame.
var _recoil := 0.0

## The player's radial light + its half-texture size (for radius -> scale), and a
## clock driving the flicker.
const LIGHT_TEX_HALF := 128.0
var _light: PointLight2D
var _light_time := 0.0


func _ready() -> void:
	# Wire component refs in code (reliable in hand-authored scenes).
	hurtbox.health_component = health
	health.died.connect(_on_died)
	_base_weapon_scale = weapon_sprite.scale
	_base_weapon_pos = weapon_sprite.position
	# Show the held weapon's sprite and keep it current as weapons switch. The
	# holder (a child) already equipped its first weapon in its own _ready, so we
	# also sync the current one now — the initial signal fired before we connected.
	EventBus.weapon_equipped.connect(_on_weapon_equipped)
	_on_weapon_equipped(weapon_holder.get_current_data())
	# Kick the held weapon back on every shot for tactile firing feedback.
	EventBus.weapon_fired.connect(_on_weapon_fired)
	_setup_light()
	EventBus.player_spawned.emit(self)


func _process(delta: float) -> void:
	_update_aim()
	_update_recoil(delta)
	_update_light(delta)
	_handle_shooting()
	_handle_weapon_input()


## Build the player's radial light once. Its texture is a soft white circle
## generated in code (a radial gradient, bright centre fading to transparent), so no
## art asset is needed; colour/energy/radius are all driven from the export vars.
func _setup_light() -> void:
	if not light_enabled:
		return
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	# A gentle falloff curve reads softer than a straight ramp.
	gradient.add_point(0.55, Color(1, 1, 1, 0.65))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = int(LIGHT_TEX_HALF * 2.0)
	tex.height = int(LIGHT_TEX_HALF * 2.0)

	_light = PointLight2D.new()
	_light.name = "PlayerLight"
	_light.texture = tex
	# MIX (not ADD) so this light UNIONs with others instead of stacking: where it
	# overlaps the lamp's glow the brightness merges rather than doubling into a
	# hotspot, while each light still fully radiates its own non-overlapping area.
	_light.blend_mode = Light2D.BLEND_MODE_MIX
	add_child(_light)
	_update_light(0.0)


## Read the export vars every frame so the lit circle tracks any runtime change to
## radius/energy/colour, plus a soft time-based flicker so it breathes.
func _update_light(delta: float) -> void:
	if _light == null:
		return
	_light_time += delta
	# Two out-of-phase sines make an organic, non-repetitive wobble in [-1, 1].
	var wobble := sin(_light_time * light_flicker_speed) * 0.6 \
		+ sin(_light_time * light_flicker_speed * 2.3 + 1.7) * 0.4
	var radius := light_radius * (1.0 + light_flicker * wobble)
	_light.texture_scale = maxf(radius, 1.0) / LIGHT_TEX_HALF
	_light.color = light_color
	_light.energy = light_energy * (1.0 + light_flicker * 0.5 * wobble)


## Set the light's base radius (px). Convenience for upgrades/pickups/effects that
## want to grow or shrink the circle; the change is picked up next frame.
func set_light_radius(radius: float) -> void:
	light_radius = maxf(radius, 0.0)


## Point the aim pivot (indicator + muzzle + held weapon) toward the mouse cursor.
func _update_aim() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 0.001:
		aim_direction = to_mouse.normalized()
		aim_pivot.rotation = aim_direction.angle()
		update_weapon_flip()
		update_aim_line()


## Flip the held weapon upright when aiming to the left, so it never appears
## upside down as the aim pivot swings past vertical.
func update_weapon_flip() -> void:
	weapon_sprite.flip_v = absf(aim_pivot.rotation) > PI * 0.5


## Draw the aim laser from the muzzle toward the cursor, cut short where it hits
## a wall (RayCast2D on the World layer). Points are local to the aim pivot, whose
## +x already faces the aim direction, so we only vary the line's length.
func update_aim_line() -> void:
	aim_ray.force_raycast_update()
	var start_x: float = muzzle.position.x
	var end_x: float = aim_ray.target_position.x
	if aim_ray.is_colliding():
		end_x = global_position.distance_to(aim_ray.get_collision_point())
	aim_line.points = PackedVector2Array([Vector2(maxf(start_x, 0.0), 0.0),
		Vector2(maxf(end_x, start_x), 0.0)])


## Show the newly equipped weapon's sprite in hand, tinted by its color.
func _on_weapon_equipped(data: WeaponData) -> void:
	if data == null:
		weapon_sprite.visible = false
		return
	weapon_sprite.visible = true
	weapon_sprite.texture = data.sprite
	weapon_sprite.modulate = data.color
	weapon_sprite.scale = _base_weapon_scale * data.sprite_scale
	# Tint the aim laser to match the equipped weapon.
	var laser := data.color
	laser.a = 0.85
	aim_line.default_color = laser


## Register a fresh recoil kick when the weapon fires; capped so holding an
## automatic doesn't walk the gun off the player.
func _on_weapon_fired() -> void:
	_recoil = minf(_recoil + recoil_kick, recoil_max)


## Ease the held weapon back to rest each frame. The kick pushes it along the aim
## pivot's -x (back toward the player) plus a small muzzle-rise tilt, signed by the
## flip so it reads correctly whether aiming left or right.
func _update_recoil(delta: float) -> void:
	_recoil = maxf(_recoil - recoil_return * delta, 0.0)
	weapon_sprite.position = _base_weapon_pos - Vector2(_recoil, 0.0)
	var tilt_sign := 1.0 if weapon_sprite.flip_v else -1.0
	weapon_sprite.rotation = tilt_sign * _recoil * recoil_tilt


## Current WASD/arrow movement intent as a (possibly zero) unit-ish vector.
func get_move_input() -> Vector2:
	var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	#print("Input vector: ", input) # <--- Add this temporarily
	return input


## Accelerate toward `direction * speed` and move. Called by movement states.
## Upgrades' move-speed bonus applies here so it covers walking AND dodge rolls.
func apply_movement(direction: Vector2, speed: float, accel: float, delta: float) -> void:
	velocity = velocity.move_toward(direction * speed * Upgrades.move_speed_mult, accel * delta)
	move_and_slide()


## Decelerate to a stop and move. Called by the idle state.
func apply_friction(decel: float, delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, decel * delta)
	move_and_slide()


## Begin the roll cooldown timer, re-enabling rolling when it elapses.
func start_roll_cooldown() -> void:
	can_roll = false
	await get_tree().create_timer(roll_cooldown).timeout
	can_roll = true


## Fire the held weapon while the shoot input is active. Independent of the
## movement state machine so the player can shoot while moving, idle, or rolling.
func _handle_shooting() -> void:
	var current: WeaponData = weapon_holder.get_current_data()
	if current == null:
		return
	var wants_to_fire := (
		Input.is_action_pressed("shoot") if current.auto
		else Input.is_action_just_pressed("shoot")
	)
	if wants_to_fire:
		weapon_holder.try_fire(aim_direction, muzzle.global_position)


## Reload and weapon-switching input (mouse wheel to cycle weapons, R to reload).
func _handle_weapon_input() -> void:
	if Input.is_action_just_pressed("reload"):
		weapon_holder.reload()
	if Input.is_action_just_pressed("weapon_next"):
		weapon_holder.next_weapon()
	if Input.is_action_just_pressed("weapon_prev"):
		weapon_holder.prev_weapon()


## Toggle dodge-roll invulnerability frames by enabling/disabling the hurtbox.
func set_invulnerable(value: bool) -> void:
	if hurtbox:
		hurtbox.set_invulnerable(value)


func _on_died() -> void:
	# Placeholder until the game-over flow exists (meta milestone).
	print("Player died.")
