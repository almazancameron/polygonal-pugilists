class_name TargetStatusStacksBelowXCondition
extends Condition

enum Target {
	SELF,
	TARGET
}

## Met when the target lacks the given status OR has the given status, but with fewer than the
## specified number of stacks -- e.g. "target has fewer than 3 stacks of Poison."

@export var status_effect: Status.StatusEffect = Status.StatusEffect.POISON
@export var stacks: int = 1
@export var target: Target = Target.TARGET

func is_met(user: Combatant, target: Combatant) -> bool:
	var combatant: Combatant = target if self.target == Target.TARGET else user
	var status: Status = combatant.get_status(status_effect)
	if status == null:
		return true
	return status.stacks < stacks

func describe() -> String:
	return "target has fewer than %d stack%s of %s" % [
		stacks, "s" if stacks != 1 else "", String(Status.status_effect_id(status_effect)).capitalize()
	]
