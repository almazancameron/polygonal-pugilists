class_name SelfHPBelowXCondition
extends Condition

## Met when the user has less than the given percentage of HP remaining -- e.g.
## "user has less than 50% HP"

@export var hp_percent: float = 0.5

func is_met(user: Combatant, target: Combatant) -> bool:
	return (float(user.current_hp) / user.familiar.max_hp) < hp_percent

func describe() -> String:
	return "user has less than %d%% HP" % int(hp_percent * 100)
