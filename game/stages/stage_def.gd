class_name StageDef
extends Resource
## One stage of the run, as a node in a story GRAPH. The run's whole campaign
## is a chain of these resources (resources/stages/*.tres): each stage links
## its default successor, plus optional flag-gated branches into alternate
## story lines. Rerouting the campaign, inserting a stage, or adding a branch
## is purely a .tres edit — no code changes.

@export var id: StringName
@export var display_name := "Underhalls"
## Shown in the stage banner ("Underhalls — Stage 2"). Kept on the stage (not
## counted globally) so branch lines can number themselves however they like.
@export var stage_number := 1
## The endboss stage: its boss drops loot but no onward portal.
@export var is_final := false
## Normal progression; null only makes sense on a final stage.
@export var next_default: StageDef
## Flag-gated detours, checked in order before next_default (first match wins).
@export var branches: Array[StageBranch] = []


## Where the boss portal leads, given the run's raised flags.
func next_for(flags: Dictionary) -> StageDef:
	for branch in branches:
		if branch != null and flags.has(branch.required_flag):
			return branch.stage
	return next_default
