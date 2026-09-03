class_name ConditionalNumericBonus
extends NumericBonus

## Yields the base flat+percent amount only when condition holds,
## otherwise 0.

@export var condition: Condition

func compute(user: Combatant, target: Combatant) -> int:
	if condition.is_met(user, target):
		return base_amount(user, target)
	else:
		return 0
