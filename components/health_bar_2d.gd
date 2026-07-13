class_name HealthBar2D
extends Node2D
## A tiny floating health bar drawn in world space above an entity. Reusable by
## the dummy now and by every enemy later. Call `track(health_component)` to bind
## it; it redraws whenever that health changes.

@export var bar_size: Vector2 = Vector2(30, 4)
@export var background_color: Color = Color(0, 0, 0, 0.6)
@export var fill_color: Color = Color(0.85, 0.25, 0.25)
@export var hide_when_full: bool = true

var _ratio: float = 1.0
var _health: HealthComponent


## Bind to a HealthComponent and start reflecting its value.
func track(health_component: HealthComponent) -> void:
	_health = health_component
	_health.health_changed.connect(_on_health_changed)
	_ratio = _health.get_ratio()
	_update_visibility()
	queue_redraw()


func _on_health_changed(current: float, maximum: float) -> void:
	_ratio = current / maximum if maximum > 0.0 else 0.0
	_update_visibility()
	queue_redraw()


func _update_visibility() -> void:
	visible = not (hide_when_full and is_equal_approx(_ratio, 1.0))


func _draw() -> void:
	var origin := -bar_size * 0.5
	draw_rect(Rect2(origin, bar_size), background_color)
	draw_rect(Rect2(origin, Vector2(bar_size.x * _ratio, bar_size.y)), fill_color)
