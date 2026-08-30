class_name PriorityBuild
extends Resource

## A player-selectable set of priority rules, authored ahead of time so the
## pre-fight build-select screen has concrete choices to offer. Picking one
## assigns its priority_rules onto player_familiar_data (see
## battle_controller.gd's _on_build_selected()) -- this is deliberately the
## smallest possible slice of buildcrafting, not the eventual round/reward
## loop, just enough for two authored builds to visibly play differently.

@export var build_name: String = "Build"
@export var priority_rules: Array[PriorityRule] = []
