extends Node
## Headless automated test for the stage progression graph. Run as a SCENE:
##   godot --headless --path <proj> res://tests/stage_flow_test.tscn
##
## Verifies: (1) the shipped campaign chain walks Underhalls 1 -> 2 -> 3 with
## the last stage flagged final, (2) deepest_floor tracks the numbers, (3) a
## flag-gated branch reroutes advance() into an alternate story line while the
## default path is taken when the flag was never raised.

const StageDefScript := preload("res://game/stages/stage_def.gd")
const StageBranchScript := preload("res://game/stages/stage_branch.gd")


func _ready() -> void:
	# (1)/(2) The shipped campaign: a set number of stages until the endboss.
	GameState.deepest_floor = 0
	Stages.start_run()
	var chain_ok := Stages.current.id == &"underhalls_1" \
		and Stages.current.stage_number == 1 and not Stages.current.is_final
	chain_ok = chain_ok and Stages.advance().id == &"underhalls_2"
	chain_ok = chain_ok and Stages.advance().id == &"underhalls_3" \
		and Stages.current.is_final and Stages.current.next_default == null
	var depth_ok := GameState.deepest_floor == 3

	# (3) Branching: crypt_1 -> crypt_2 by default, but the &"heretic_rite"
	# flag reroutes into the sunken chapel story line.
	var chapel := _stage(&"sunken_chapel", 2)
	var crypt_2 := _stage(&"crypt_2", 2)
	var crypt_1 := _stage(&"crypt_1", 1)
	crypt_1.next_default = crypt_2
	var branch: StageBranch = StageBranchScript.new()
	branch.required_flag = &"heretic_rite"
	branch.stage = chapel
	crypt_1.branches = [branch]

	Stages.start_run(crypt_1)
	var default_ok := Stages.advance() == crypt_2
	Stages.start_run(crypt_1)
	Stages.set_flag(&"heretic_rite")
	var branch_ok := Stages.advance() == chapel
	# Flags are run-local: a new run must not inherit last run's rite.
	Stages.start_run(crypt_1)
	var wipe_ok := Stages.flags.is_empty() and Stages.advance() == crypt_2

	var all_ok := chain_ok and depth_ok and default_ok and branch_ok and wipe_ok
	print("STAGE FLOW TEST: %s (chain=%s depth=%s default=%s branch=%s wipe=%s)" % [
		"PASS" if all_ok else "FAIL", chain_ok, depth_ok, default_ok, branch_ok, wipe_ok
	])
	get_tree().quit(0 if all_ok else 1)


func _stage(id: StringName, number: int) -> StageDef:
	var stage: StageDef = StageDefScript.new()
	stage.id = id
	stage.stage_number = number
	return stage
