class_name TargetMissingStatusCondition
extends Condition

## Met when the target does NOT currently have the given status -- e.g.
## "target lacks Acid" 

@export var status_id: StringName = &"poison"

func is_met(user: Combatant, target: Combatant) -> bool:
	for status in target.statuses:
		if status.status_id() == status_id:
			return false
	return true

func describe() -> String:
	return "target does not have %s" % String(status_id).capitalize()
