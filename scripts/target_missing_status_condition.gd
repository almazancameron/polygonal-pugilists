class_name TargetMissingStatusCondition
extends Condition

## Met when the target does NOT currently have the given status -- e.g.
## "target lacks Acid"

@export var status_effect: Status.StatusEffect = Status.StatusEffect.POISON

func is_met(user: Combatant, target: Combatant) -> bool:
	var target_id: StringName = Status.status_effect_id(status_effect)
	for status in target.statuses:
		if status.status_id() == target_id:
			return false
	return true

func describe() -> String:
	return "target does not have %s" % String(Status.status_effect_id(status_effect)).capitalize()
