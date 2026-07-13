class_name DamageInfo
extends RefCounted
## A lightweight, throwaway packet describing a single instance of damage.
##
## Created by a damage DEALER (projectile, melee hitbox, hazard) and passed to a
## HurtboxComponent, which forwards it to a HealthComponent. Keeping this as data
## (rather than a pile of function arguments) means we can add fields later
## (elemental type, status effects, crit info) without touching every call site.

var amount: float               ## Raw damage before any resistances.
var source: Node                ## The node that caused the damage (for attribution/synergies).
var knockback: Vector2          ## Impulse to apply to the victim (direction * strength).
var is_crit: bool = false       ## Whether this was a critical hit (feedback/scoring).


func _init(damage_amount: float = 0.0, damage_source: Node = null, knockback_impulse: Vector2 = Vector2.ZERO) -> void:
	amount = damage_amount
	source = damage_source
	knockback = knockback_impulse
