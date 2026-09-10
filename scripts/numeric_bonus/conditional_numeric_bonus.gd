class_name ConditionalNumericBonus
extends NumericBonus

@export var condition: Condition

func compute(user: Combatant, target: Combatant) -> int:
	if condition.is_met(user, target):
		return base_amount(user, target)
	else:
		return 0

func describe_qualifier() -> String:
	if condition == null:
		return ""
	return "if %s" % condition.describe()
