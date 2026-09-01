class_name NotCondition
extends Condition

@export var wrapped_condition: Condition

func is_met(user: Combatant, target: Combatant) -> bool:
    return not wrapped_condition.is_met(user, target)

func describe() -> String:
    return "not (%s)" % wrapped_condition.describe()