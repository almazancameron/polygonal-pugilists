class_name StatusComparisonCondition
extends Condition

## Retires both TargetMissingStatusCondition and TargetStatusStacksBelowXCondition --
## "missing" and "stacks < 1" are the same fact (a status still present
## always has stacks > 0, see Status.is_expired()/Combatant._settle_status()),
## so the old presence check was redundant with a stack-count comparison,
## not a genuinely different one. Same left/right/target/comparator shape
## as StatComparisonCondition/HpComparisonCondition, resolving a status's
## current stacks instead of a stat or HP. Left and right can reference
## different statuses (e.g. "my Poison stacks vs their Acid stacks").

enum Target { SELF, TARGET }
enum CompareMode { STATUS, FLAT_VALUE }
enum Comparator { GREATER, GREATER_OR_EQUAL, LESS, LESS_OR_EQUAL, EQUAL }

@export var left_status_effect: Status.StatusEffect
@export var left_target: Target = Target.SELF

@export var compare_mode: CompareMode = CompareMode.FLAT_VALUE
@export var right_status_effect: Status.StatusEffect
@export var right_target: Target = Target.TARGET
@export var right_value: int = 0

## When true, ignores left/right_status_effect and sums every active
## status's stacks instead -- same idea as StackCountNumericBonus's
## count_all. Applies to both sides.
@export var check_all: bool = false

@export var comparator: Comparator = Comparator.LESS

func _resolve(combatant: Combatant, status_effect: Status.StatusEffect) -> int:
	if check_all:
		var total: int = 0
		for status in combatant.statuses:
			total += status.stacks
		return total

	var status: Status = combatant.get_status(status_effect)
	return status.stacks if status != null else 0

func is_met(user: Combatant, target: Combatant) -> bool:
	var left_combatant: Combatant = user if left_target == Target.SELF else target
	var left_value: int = _resolve(left_combatant, left_status_effect)

	var right: int = right_value
	if compare_mode == CompareMode.STATUS:
		var right_combatant: Combatant = user if right_target == Target.SELF else target
		right = _resolve(right_combatant, right_status_effect)

	match comparator:
		Comparator.GREATER:
			return left_value > right
		Comparator.GREATER_OR_EQUAL:
			return left_value >= right
		Comparator.LESS:
			return left_value < right
		Comparator.LESS_OR_EQUAL:
			return left_value <= right
		Comparator.EQUAL:
			return left_value == right
	return false

func describe() -> String:
	var left_str: String = "target's" if left_target == Target.TARGET else "user's"
	var left_name: String = "total status stacks" if check_all else String(Status.status_effect_id(left_status_effect)).capitalize()
	var comparator_str: String = {
		Comparator.GREATER: ">", Comparator.GREATER_OR_EQUAL: ">=",
		Comparator.LESS: "<", Comparator.LESS_OR_EQUAL: "<=", Comparator.EQUAL: "==",
	}[comparator]

	if compare_mode == CompareMode.FLAT_VALUE:
		return "%s %s stacks %s %d" % [left_str, left_name, comparator_str, right_value]

	var right_str: String = "target's" if right_target == Target.TARGET else "user's"
	var right_name: String = "total status stacks" if check_all else String(Status.status_effect_id(right_status_effect)).capitalize()
	return "%s %s stacks %s %s %s stacks" % [left_str, left_name, comparator_str, right_str, right_name]
