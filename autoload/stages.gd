extends Node
## Run-local stage progression (autoload singleton "Stages").
##
## The campaign is a graph of StageDef resources; this singleton just walks it:
## start_run() enters at ENTRY_STAGE, advance() follows the current stage's
## next_for() edge (flag-gated branches first, then next_default). Special
## conditions fulfilled mid-run raise flags via set_flag(), which is how
## alternate story lines are unlocked. Wiped by start_run() each run.
##
## The stage COUNT until the endboss is whatever the .tres chain says — change
## the campaign by editing resources/stages/, not this file.

const ENTRY_STAGE: StageDef = preload("res://resources/stages/underhalls_1.tres")

var current: StageDef = null
var flags := {}   ## StringName -> true; raised by story/secret conditions.


## Begin a fresh run at the campaign's entry stage (or a custom graph's entry,
## for tests and future alternate campaigns).
func start_run(entry: StageDef = null) -> void:
	flags.clear()
	current = entry if entry != null else ENTRY_STAGE
	_track_depth()


## Step to the next stage (called when the player enters the boss portal).
func advance() -> StageDef:
	if current != null:
		current = current.next_for(flags)
		_track_depth()
	return current


## Raise a story flag ("special condition fulfilled") that branch edges test.
func set_flag(flag: StringName) -> void:
	flags[flag] = true


func _track_depth() -> void:
	if current != null:
		GameState.deepest_floor = maxi(GameState.deepest_floor, current.stage_number)
