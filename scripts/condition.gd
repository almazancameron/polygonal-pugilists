class_name Condition
extends Resource

## Base shape for a PriorityRule's condition: static, authored data the same
## way Technique is, checked against live battle state each time a familiar
## picks its next move. Subclassed per condition kind, not parameterized by
## an enum like Technique's status_effect -- each condition kind reads a
## genuinely different battle-state fact (status presence, HP ratio, ...),
## not just a different constant plugged into the same check.

## Whether this condition currently holds. Base default is "always true",
## so an unmodified Condition resource works as an unconditional catch-all
## rule -- the same role a plain Technique instance plays for Attack.
func is_met(user: Combatant, target: Combatant) -> bool:
	return true

## A short, human-readable statement of what this condition requires --
## used to explain why a rule was skipped when it isn't met. Override in
## subclasses.
func describe() -> String:
	return "always"
