class_name BracketMatch
extends Resource

## One pairing in the bracket tree. entrant_a/entrant_b are null until the
## previous round resolves into them (only round 1 starts populated).
##
## odds_label being set while winner is still null and revealed is still
## false is the normal "scouted but not resolved" state -- the player sees
## the odds before their own fight, and the true winner is rolled only
## afterward (see docs/superpowers/specs/2026-09-06-tournament-bracket-design.md).

@export var entrant_a: Familiar
@export var entrant_b: Familiar
@export var winner: Familiar
@export var odds_label: String = ""
@export var revealed: bool = false

## Decided at runtime by character select, never authored -- deliberately
## not @export so it can't be saved into a .tres by accident.
var is_player_match: bool = false

func is_ready() -> bool:
	return entrant_a != null and entrant_b != null

func has_entrant(familiar: Familiar) -> bool:
	return entrant_a == familiar or entrant_b == familiar

func other_entrant(familiar: Familiar) -> Familiar:
	if entrant_a == familiar:
		return entrant_b
	if entrant_b == familiar:
		return entrant_a
	return null
