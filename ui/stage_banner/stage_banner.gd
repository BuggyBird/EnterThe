extends CanvasLayer
## Big centred announcement when a stage's floor is ready ("UNDERHALLS — STAGE 2").
## Fades in, lingers, fades out. Purely an EventBus listener, like the rest of
## the HUD — it never touches the Dungeon or Stages directly.

const FADE_IN := 0.4
const HOLD := 2.2
const FADE_OUT := 0.9

@onready var label: Label = $Label

var _tween: Tween


func _ready() -> void:
	label.modulate.a = 0.0
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.88, 0.76, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.22, 0.08, 0.36, 0.85))
	label.add_theme_constant_override("shadow_offset_y", 2)
	EventBus.stage_started.connect(_on_stage_started)


func _on_stage_started(display_name: String, stage_number: int) -> void:
	label.text = "%s — STAGE %d" % [display_name.to_upper(), stage_number]
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(label, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(HOLD)
	_tween.tween_property(label, "modulate:a", 0.0, FADE_OUT)
