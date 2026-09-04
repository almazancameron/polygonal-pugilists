class_name FocusBreakpointCondition
extends Condition

## Checks whether a combatant has reached a given Focus breakpoint TIER,
## rather than a fixed Focus value -- required = tier * familiar.focus_step_size,
## read fresh every time this is checked. This indirection is the whole
## point: none of these hardcode an absolute Focus number the way a plain
## StatComparisonCondition would, so a future passive that changes
## focus_step_size (e.g. "your Focus breakpoints land at steps of 4 instead
## of 5") retroactively reshapes every FocusBreakpointCondition's actual
## threshold at once, just by changing the one field they all read from.

enum Target { SELF, TARGET }
enum Comparator { GREATER, GREATER_OR_EQUAL, LESS, LESS_OR_EQUAL, EQUAL }

@export var focus_target: Target = Target.SELF
@export var tier: int = 1
@export var comparator: Comparator = Comparator.GREATER_OR_EQUAL

func _combatant(user: Combatant, target: Combatant) -> Combatant:
	return user if focus_target == Target.SELF else target

func is_met(user: Combatant, target: Combatant) -> bool:
	var combatant: Combatant = _combatant(user, target)
	var focus: int = combatant.effective_stat(Familiar.Stat.FOCUS)
	var required: int = tier * combatant.familiar.focus_step_size

	match comparator:
		Comparator.GREATER:
			return focus > required
		Comparator.GREATER_OR_EQUAL:
			return focus >= required
		Comparator.LESS:
			return focus < required
		Comparator.LESS_OR_EQUAL:
			return focus <= required
		Comparator.EQUAL:
			return focus == required
	return false

func describe() -> String:
	var whose: String = "target's" if focus_target == Target.TARGET else "own"
	var comparator_str: String = {
		Comparator.GREATER: ">", Comparator.GREATER_OR_EQUAL: ">=",
		Comparator.LESS: "<", Comparator.LESS_OR_EQUAL: "<=", Comparator.EQUAL: "==",
	}[comparator]
	return "%s Focus tier %s %d" % [whose, comparator_str, tier]
