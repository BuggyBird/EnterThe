class_name HitEffect
extends GPUParticles2D
## One-shot placeholder impact burst, spawned where a bullet strikes an enemy and
## tinted to match the bullet. Frees itself once the burst finishes, so callers can
## fire-and-forget: instantiate -> setup(color) -> add_child -> set position.
##
## Uses a round particle texture so the burst is actually visible (bare GPU
## particles render as ~1px points). Tint is applied via `modulate` on the node.

## Tint the burst before adding to the tree.
func setup(tint: Color) -> void:
	modulate = tint


func _ready() -> void:
	finished.connect(queue_free)
	emitting = true
