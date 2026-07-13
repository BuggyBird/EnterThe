class_name HealthComponent
extends Node
## Reusable hit-points container. Drop this on ANY entity that can be hurt or die
## (player, enemies, bosses, destructible props). It holds no visuals and no
## collision — a HurtboxComponent feeds it damage; the owner reacts to its signals.

signal health_changed(current: float, maximum: float)  ## Any change (damage or heal).
signal damaged(info: DamageInfo)                        ## Took damage specifically.
signal healed(amount: float)                            ## Gained health.
signal died()                                           ## Reached zero.

@export var max_health: float = 30.0
@export var invulnerable: bool = false  ## When true, ignores all incoming damage.

var current_health: float
var is_dead: bool = false


func _ready() -> void:
	current_health = max_health


## Apply a damage packet. Safe to call repeatedly; ignored once dead.
func take_damage(info: DamageInfo) -> void:
	if is_dead or invulnerable or info.amount <= 0.0:
		return
	current_health = clampf(current_health - info.amount, 0.0, max_health)
	damaged.emit(info)
	health_changed.emit(current_health, max_health)
	EventBus.damage_dealt.emit(get_parent(), info.amount)
	if current_health <= 0.0:
		_die()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = clampf(current_health + amount, 0.0, max_health)
	healed.emit(amount)
	health_changed.emit(current_health, max_health)


func get_ratio() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0


func _die() -> void:
	is_dead = true
	died.emit()
	EventBus.entity_died.emit(get_parent())
