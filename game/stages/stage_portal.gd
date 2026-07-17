class_name StagePortal
extends Area2D
## The way onward: spawned where the stage boss died. The same swirling sheet
## as the door portals, tinted purple and scaled up so it reads as "exit", with
## the next stage's name floating underneath. Walking in emits
## EventBus.stage_portal_entered; the Dungeon answers by advancing Stages and
## generating the next floor.

const TINT := Color(0.72, 0.38, 1.0)     ## Purple — distinct from door portals.
const PORTAL_SCALE := 1.6
const LABEL_COLOR := Color(0.85, 0.7, 1.0)

var _used := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # PlayerBody
	z_index = RoomDef.PORTAL_Z

	var frames := RoomDef.portal_frames()
	if frames != null:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.modulate = TINT
		sprite.scale = Vector2.ONE * PORTAL_SCALE
		add_child(sprite)
		sprite.play(&"swirl")

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30.0, 52.0)
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)

	var next: StageDef = Stages.current.next_for(Stages.flags) if Stages.current else null
	if next != null:
		var label := Label.new()
		label.text = next.display_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", LABEL_COLOR)
		label.custom_minimum_size = Vector2(96.0, 0.0)
		label.position = Vector2(-48.0, 34.0)
		add_child(label)


func _on_body_entered(body: Node2D) -> void:
	if _used or not (body is Player):
		return
	_used = true
	EventBus.stage_portal_entered.emit()
