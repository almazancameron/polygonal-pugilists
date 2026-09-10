class_name Condition
extends Resource

## Reusable predicate evaluated against live combat state by priority rules,
## StepGroups, numeric bonuses and passives. Subclasses express different
## checks, such as status presence or HP comparisons.
##
## The base predicate always passes, imposing no restriction on its caller.
func is_met(user: Combatant, target: Combatant) -> bool:
	return true

## A short, human-readable statement of what this condition requires --
## used to explain why a rule was skipped when it isn't met. Override in
## subclasses.
func describe() -> String:
	return "always"
