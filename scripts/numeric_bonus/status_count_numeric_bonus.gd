class_name StatusCountNumericBonus
extends NumericBonus

## Multiplies the base flat+percent amount by how many distinct statuses
## are currently active -- not their combined stacks, see
## StackCountNumericBonus's count_all for that.

@export var count_on: Target = Target.TARGET

func compute(user: Combatant, target: Combatant) -> int:
	var combatant: Combatant = target if count_on == Target.TARGET else user

	return combatant.statuses.size() * base_amount(user, target)

func describe_qualifier() -> String:
	var whose: String = "the user" if count_on == Target.SELF else "the target"
	return "for each active status on %s" % whose
