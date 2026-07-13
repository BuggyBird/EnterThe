class_name HitboxComponent
extends Area2D
## The DEALING half of combat: an Area2D that applies damage to any
## HurtboxComponent it overlaps. Use for melee swings, contact damage (an enemy
## body that hurts on touch), and hazards. Projectiles deal damage directly (see
## projectile.gd) for efficiency, but reuse the same DamageInfo/HurtboxComponent
## contract so everything is interchangeable.
##
## Setup: put it on the appropriate *hitbox* layer and set its mask to the
## target's *hurtbox* layer so `area_entered` fires against the right team.

@export var damage: float = 10.0
@export var knockback_force: float = 0.0
## If true, stop dealing damage after the first hit (e.g. one-use spike).
@export var one_shot: bool = false
## Seconds between repeat hits while overlapping (0 = only on entry).
@export var hit_interval: float = 0.0

var _active: bool = true
var _cooldowns: Dictionary = {}  ## Hurtbox -> seconds until it can be hit again.


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if hit_interval <= 0.0:
		return
	# Re-hit hurtboxes we are still overlapping once their cooldown elapses.
	for hurtbox in _cooldowns.keys():
		_cooldowns[hurtbox] -= delta
		if _cooldowns[hurtbox] <= 0.0 and is_instance_valid(hurtbox) and overlaps_area(hurtbox):
			_hit(hurtbox)


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		_hit(area)


func _hit(hurtbox: HurtboxComponent) -> void:
	if not _active:
		return
	var knockback := Vector2.ZERO
	if knockback_force > 0.0:
		knockback = (hurtbox.global_position - global_position).normalized() * knockback_force
	hurtbox.take_hit(DamageInfo.new(damage, self, knockback))
	if hit_interval > 0.0:
		_cooldowns[hurtbox] = hit_interval
	if one_shot:
		_active = false
		set_deferred("monitoring", false)
