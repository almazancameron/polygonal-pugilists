class_name AddTechniqueUpgrade
extends UpgradeOption

## Grants a new technique and wires a priority rule for it so
## the technique actually gets used rather than sitting unreferenced in
## the movepool. The rule is inserted just before the last entry in
## priority_rules (expected to be the unconditional catch-all -- see
## PriorityRule/DECISIONS.md), so it gets a chance to fire before the
## fallback swallows every turn.

@export var technique: Technique
@export var rule: PriorityRule

func describe() -> String:
	return "Learn %s" % technique.technique_name

func apply(familiar: Familiar) -> void:
	familiar.techniques.append(technique)

	if rule == null:
		return

	if familiar.priority_rules.is_empty():
		familiar.priority_rules.append(rule)
	else:
		familiar.priority_rules.insert(familiar.priority_rules.size() - 1, rule)
