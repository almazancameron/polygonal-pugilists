class_name TargetStatusStacksBelowXCondition
extends Condition

## Met when the target lacks the given status OR has the given status, but with fewer than the
## specified number of stacks -- e.g. "target has fewer than 3 stacks of Poison."

@export var status_effect: Status.StatusEffect = Status.StatusEffect.POISON
@export var stacks: int = 1

func is_met(user: Combatant, target: Combatant) -> bool:
	var target_id: StringName = Status.status_effect_id(status_effect)
	for status in target.statuses:
		if status.status_id() == target_id:
			return status.stacks < stacks
	return true

func describe() -> String:
	return "target has fewer than %d stack%s of %s" % [
		stacks, "s" if stacks != 1 else "", String(Status.status_effect_id(status_effect)).capitalize()
	]
