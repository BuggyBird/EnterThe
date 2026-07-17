extends Node2D
## A training dummy: the simplest possible thing that can be shot and killed.
## It exists to prove the combat pipeline (projectile -> hurtbox -> health ->
## feedback -> death) before real enemies arrive in Milestone 4. It composes the
## same HealthComponent / HurtboxComponent / HealthBar2D that enemies will use.

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: HealthComponent = $Health
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var health_bar: HealthBar2D = $HealthBar

## Base tint restored after a hit flash.
var _base_color := Color(0.9, 0.35, 0.35)


func _ready() -> void:
	# Wire component references in code (reliable; exported node paths in a
	# hand-authored scene do not resolve).
	hurtbox.health_component = health
	health_bar.track(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_base_color = sprite.modulate
	# Same shared rat animations the real monsters use; a dummy just idles.
	sprite.sprite_frames = RatFrames.frames()
	sprite.play(&"idle")


func _on_damaged(info: DamageInfo) -> void:
	_flash()
	if info.knockback != Vector2.ZERO:
		_nudge(info.knockback.normalized())


## Bright flash back to base color — cheap, readable hit feedback.
func _flash() -> void:
	sprite.modulate = Color(3.0, 3.0, 3.0)  # >1 blooms on Forward+ for a punchy pop.
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", _base_color, 0.15)


## Small positional knock in the hit direction, then settle back.
func _nudge(dir: Vector2) -> void:
	var start := position
	var tween := create_tween()
	tween.tween_property(self, "position", start + dir * 7.0, 0.05)
	tween.tween_property(self, "position", start, 0.12)


func _on_died() -> void:
	hurtbox.set_deferred("monitorable", false)  # stop absorbing further shots
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
