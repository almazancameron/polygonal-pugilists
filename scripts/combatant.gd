class_name Combatant
extends RefCounted

## Per-battle runtime state for one side of a fight. Wraps a Familiar's
## static stats with the things that change during combat (current_hp,
## is_defending). Created fresh each battle, never saved or edited directly.

var familiar: Familiar
var current_hp: int
var is_defending: bool = false
var statuses: Array[Status] = []

func _init(f: Familiar) -> void:
	familiar = f
	current_hp = f.max_hp

func take_damage(amount: int) -> void:
	current_hp = max(current_hp - amount, 0)

func is_defeated() -> bool:
	return current_hp <= 0

## Re-applying an already-active status stacks onto it instead of tracking
## a second independent instance. Also trigger the status's on_reapply() callback, which can do things like refresh
## duration or trigger a bonus effect. Returns the combat log message from on_reapply(), or "" if nothing happened.
func add_status(new_status: Status) -> String:
	for existing in statuses:
		if existing.status_id() == new_status.status_id():
			var message: String = existing.on_reapply(self)
			existing.stack_with(new_status)
			return message

	statuses.append(new_status)
	return ""

func effective_defense() -> int:
	var modified_defense: int = familiar.defense

	for status in statuses:
		modified_defense = status.modify_defense(modified_defense)

	return modified_defense

## Evaluates familiar.priority_rules in order and returns the first rule
## whose conditions all hold, plus a skip reason for every rule passed over
## along the way -- the caller logs those to explain the choice, per
## GAME_DESIGN.md's "every skip needs a visible reason" requirement.
## Expects the rule list to end with an unconditional catch-all rule (an
## empty conditions array is vacuously true); if none matches, "technique"
## comes back null rather than guessing.
func choose_technique(target: Combatant) -> Dictionary:
	var skip_reasons: Array[String] = []

	for rule in familiar.priority_rules:
		var failed_condition: Condition = null
		for condition in rule.conditions:
			if not condition.is_met(self, target):
				failed_condition = condition
				break

		if failed_condition == null:
			return {"technique": rule.technique, "skip_reasons": skip_reasons}

		skip_reasons.append("%s skipped (condition not met: %s)" % [rule.technique.technique_name, failed_condition.describe()])

	return {"technique": null, "skip_reasons": skip_reasons}