extends Node
## Central seeded random-number source (autoload singleton "RNG").
##
## ALL gameplay randomness (procgen, loot, enemy choices) should go through this
## so an entire run is reproducible from a single seed. That makes bugs
## repeatable and enables features like daily/shared-seed challenges later.
## Cosmetic-only randomness (particles, screen shake) may use local RNGs.

var _rng := RandomNumberGenerator.new()
var current_seed: int = 0


func _ready() -> void:
	randomize_seed()


## Generate and apply a fresh random seed. Call at the start of a new run.
func randomize_seed() -> void:
	set_seed(_rng.randi())


## Force a specific seed (e.g. for a daily challenge or a bug repro).
func set_seed(value: int) -> void:
	current_seed = value
	_rng.seed = value


func randf() -> float:
	return _rng.randf()


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## Return true with the given probability (0.0..1.0).
func chance(probability: float) -> bool:
	return _rng.randf() < probability


## Pick a uniformly random element from a non-empty array.
func pick(array: Array):
	if array.is_empty():
		return null
	return array[_rng.randi_range(0, array.size() - 1)]


## Weighted pick. `weights` must align 1:1 with `items` and sum to > 0.
func pick_weighted(items: Array, weights: Array[float]):
	if items.is_empty() or items.size() != weights.size():
		return null
	var total := 0.0
	for w in weights:
		total += w
	var roll := _rng.randf() * total
	for i in items.size():
		roll -= weights[i]
		if roll <= 0.0:
			return items[i]
	return items.back()
