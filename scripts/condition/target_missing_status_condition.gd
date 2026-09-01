class_name TargetMissingStatusCondition
extends Condition

enum Target {
	SELF,
	TARGET
}

## Met when the target does NOT currently have the given status -- e.g.
## "target lacks Acid"

@export var status_effect: Status.StatusEffect = Status.StatusEffect.POISON
@export var target: Target = Target.TARGET

func is_met(user: Combatant, target: Combatant) -> bool:
	var combatant: Combatant = target if self.target == Target.TARGET else user
	if combatant.has_status(status_effect):
		return false
	return true

func describe() -> String:
	return "target does not have %s" % String(Status.status_effect_id(status_effect)).capitalize()
