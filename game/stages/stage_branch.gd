class_name StageBranch
extends Resource
## One conditional edge in the stage graph: when the run has raised
## `required_flag` (via Stages.set_flag, e.g. a secret condition fulfilled
## mid-stage), the boss portal leads to `stage` instead of the stage's
## next_default. See StageDef.next_for().

@export var required_flag: StringName
@export var stage: StageDef
