class_name RuneBackground
extends Control
## Ambient background: Elder Futhark runes drifting and fading in the void, for
## the mythic-underworld mood. Fully programmatic (placeholder-first) — each rune
## is defined as line strokes in a unit box and drawn with draw_polyline, so there
## is no dependency on a font shipping the runic glyph block.
##
## A lightweight particle field: a fixed pool of glyphs slowly rises, sways, fades
## in and out, and respawns at the bottom with fresh parameters. Meant to sit on a
## background CanvasLayer (behind the world), so it is deliberately faint.

## Elder Futhark runes as stroke paths in a unit box: x in [-0.35, 0.35], y in
## [-0.6, 0.6] (y down). Each rune is an Array of PackedVector2Array polylines.
## (A var, not const: PackedVector2Array(...) isn't a constant expression.)
var RUNES: Array = [
	[PackedVector2Array([Vector2(-0.1, 0.6), Vector2(-0.1, -0.6)]),          # Fehu
		PackedVector2Array([Vector2(-0.1, -0.6), Vector2(0.3, -0.35)]),
		PackedVector2Array([Vector2(-0.1, -0.2), Vector2(0.3, 0.05)])],
	[PackedVector2Array([Vector2(-0.25, 0.6), Vector2(-0.25, -0.6),          # Uruz
		Vector2(0.25, -0.3), Vector2(0.25, 0.6)])],
	[PackedVector2Array([Vector2(0.0, -0.6), Vector2(0.0, 0.6)]),            # Thurisaz
		PackedVector2Array([Vector2(0.0, -0.22), Vector2(0.3, 0.0), Vector2(0.0, 0.22)])],
	[PackedVector2Array([Vector2(-0.1, 0.6), Vector2(-0.1, -0.6)]),          # Ansuz
		PackedVector2Array([Vector2(-0.1, -0.6), Vector2(0.3, -0.4)]),
		PackedVector2Array([Vector2(-0.1, -0.25), Vector2(0.3, -0.05)])],
	[PackedVector2Array([Vector2(-0.2, 0.6), Vector2(-0.2, -0.6),            # Raidho
		Vector2(0.25, -0.4), Vector2(-0.2, -0.1)]),
		PackedVector2Array([Vector2(-0.2, -0.1), Vector2(0.28, 0.6)])],
	[PackedVector2Array([Vector2(0.25, -0.5), Vector2(-0.15, 0.0),           # Kaunan
		Vector2(0.25, 0.5)])],
	[PackedVector2Array([Vector2(-0.3, -0.5), Vector2(0.3, 0.5)]),           # Gebo
		PackedVector2Array([Vector2(0.3, -0.5), Vector2(-0.3, 0.5)])],
	[PackedVector2Array([Vector2(-0.15, 0.6), Vector2(-0.15, -0.6)]),        # Wunjo
		PackedVector2Array([Vector2(-0.15, -0.6), Vector2(0.25, -0.35),
			Vector2(-0.15, -0.1)])],
	[PackedVector2Array([Vector2(-0.25, -0.6), Vector2(-0.25, 0.6)]),        # Hagalaz
		PackedVector2Array([Vector2(0.25, -0.6), Vector2(0.25, 0.6)]),
		PackedVector2Array([Vector2(-0.25, -0.1), Vector2(0.25, 0.1)])],
	[PackedVector2Array([Vector2(0.0, -0.6), Vector2(0.0, 0.6)]),            # Nauthiz
		PackedVector2Array([Vector2(-0.25, 0.15), Vector2(0.25, -0.15)])],
	[PackedVector2Array([Vector2(0.2, -0.6), Vector2(-0.1, -0.2),            # Sowilo
		Vector2(0.1, 0.2), Vector2(-0.2, 0.6)])],
	[PackedVector2Array([Vector2(0.0, 0.6), Vector2(0.0, -0.6)]),            # Tiwaz
		PackedVector2Array([Vector2(-0.25, -0.3), Vector2(0.0, -0.6),
			Vector2(0.25, -0.3)])],
	[PackedVector2Array([Vector2(-0.2, 0.6), Vector2(-0.2, -0.6)]),          # Berkanan
		PackedVector2Array([Vector2(-0.2, -0.6), Vector2(0.25, -0.35),
			Vector2(-0.2, -0.05), Vector2(0.25, 0.3), Vector2(-0.2, 0.6)])],
	[PackedVector2Array([Vector2(-0.25, 0.6), Vector2(-0.25, -0.6)]),        # Mannaz
		PackedVector2Array([Vector2(0.25, 0.6), Vector2(0.25, -0.6)]),
		PackedVector2Array([Vector2(-0.25, -0.6), Vector2(0.25, -0.05)]),
		PackedVector2Array([Vector2(0.25, -0.6), Vector2(-0.25, -0.05)])],
	[PackedVector2Array([Vector2(-0.25, -0.5), Vector2(0.25, 0.5)]),         # Dagaz
		PackedVector2Array([Vector2(-0.25, 0.5), Vector2(0.25, -0.5)]),
		PackedVector2Array([Vector2(-0.25, -0.5), Vector2(-0.25, 0.5)]),
		PackedVector2Array([Vector2(0.25, -0.5), Vector2(0.25, 0.5)])],
]

## Faint, cold, otherworldly tints.
const PALETTE: Array[Color] = [
	Color(0.85, 0.72, 0.4),    # pale gold
	Color(0.5, 0.8, 0.85),     # ghost cyan
	Color(0.7, 0.55, 0.9),     # violet
	Color(0.78, 0.8, 0.74),    # bone
]

@export var rune_count := 34            ## Glyphs alive at once.
@export var min_size := 16.0
@export var max_size := 42.0
@export var min_rise := 7.0             ## Upward drift speed range (px/s).
@export var max_rise := 20.0
@export var peak_alpha := 0.18          ## Brightest a glyph gets.
@export var stroke_width := 0.055       ## In unit space; scaled with the glyph.

var _particles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()   ## Local: purely cosmetic, off the seeded run RNG.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # Keep drifting even while the game is paused.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	var view := get_viewport_rect().size
	for i in rune_count:
		var p := _spawn(view)
		# Stagger initial life so they don't all fade together on the first cycle.
		p["age"] = _rng.randf_range(0.0, p["life"])
		p["pos"].y = _rng.randf_range(0.0, view.y)
		_particles.append(p)


## Build one glyph with fresh random parameters, entering from the bottom edge.
func _spawn(view: Vector2) -> Dictionary:
	var size := _rng.randf_range(min_size, max_size)
	return {
		"pos": Vector2(_rng.randf_range(0.0, view.x), view.y + size),
		"size": size,
		"rise": _rng.randf_range(min_rise, max_rise),
		"rune": _rng.randi_range(0, RUNES.size() - 1),
		"color": PALETTE[_rng.randi_range(0, PALETTE.size() - 1)],
		"rot": _rng.randf_range(-0.25, 0.25),
		"spin": _rng.randf_range(-0.15, 0.15),
		"sway_amp": _rng.randf_range(4.0, 16.0),
		"sway_freq": _rng.randf_range(0.2, 0.6),
		"sway_phase": _rng.randf_range(0.0, TAU),
		"life": _rng.randf_range(7.0, 13.0),
		"age": 0.0,
	}


func _process(delta: float) -> void:
	var view := get_viewport_rect().size
	for p in _particles:
		p["age"] += delta
		p["pos"].y -= p["rise"] * delta
		p["pos"].x += sin(p["age"] * p["sway_freq"] * TAU + p["sway_phase"]) * p["sway_amp"] * delta
		p["rot"] += p["spin"] * delta
		if p["age"] >= p["life"] or p["pos"].y < -p["size"]:
			var fresh := _spawn(view)
			p.merge(fresh, true)
	queue_redraw()


## Alpha envelope: fade in over the first stretch, hold, fade out at the end.
func _envelope(p: Dictionary) -> float:
	var t: float = p["age"]
	var life: float = p["life"]
	var fade := minf(1.5, life * 0.3)
	var in_a: float = clampf(t / fade, 0.0, 1.0)
	var out_a: float = clampf((life - t) / fade, 0.0, 1.0)
	return minf(in_a, out_a)


func _draw() -> void:
	for p in _particles:
		var alpha: float = _envelope(p) * peak_alpha
		if alpha <= 0.001:
			continue
		var col: Color = p["color"]
		col.a = alpha
		var size: float = p["size"]
		draw_set_transform(p["pos"], p["rot"], Vector2(size, size))
		for stroke in RUNES[p["rune"]]:
			draw_polyline(stroke, col, stroke_width, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
