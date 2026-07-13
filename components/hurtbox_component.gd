class_name HurtboxComponent
extends Area2D
## The RECEIVING half of combat: an Area2D that represents "the space where this
## entity can be hurt." Damage dealers (projectiles, HitboxComponents) detect it
## and call `take_hit`. It forwards damage to its HealthComponent.
##
## Setup: place as a child of the entity with a CollisionShape2D, put it on the
## entity's *hurtbox* physics layer, and assign `health_component` (usually done
## in the owner's _ready to avoid unreliable exported-node-path resolution).
##
## i-frames: toggle `monitorable` off (see `set_invulnerable`) so dealers stop
## detecting this hurtbox entirely — used by the player's dodge roll.

signal hit_taken(info: DamageInfo)

## The health this hurtbox feeds. Assigned by the owner script in code.
@export var health_component: HealthComponent


## Called by a damage dealer that has detected this hurtbox.
func take_hit(info: DamageInfo) -> void:
	hit_taken.emit(info)
	if health_component:
		health_component.take_damage(info)


## Enable/disable i-frames. While invulnerable, dealers can't detect this box.
func set_invulnerable(value: bool) -> void:
	# Deferred because we may be inside a physics/area callback when toggling.
	set_deferred("monitorable", not value)
