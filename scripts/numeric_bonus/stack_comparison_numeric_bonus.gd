class_name StackComparisonNumericBonus
extends NumericBonus

## Multiplies the base flat+percent amount by the difference between two
## statuses' stack counts -- e.g. "1 damage for each Poison stack you have
## more than the target" is just flat_bonus=1 with the defaults below (self
## Poison vs target Poison). Same left/right/target/compare_mode/check_all
## vocabulary as StatusComparisonCondition. Not clamped to a minimum of 0:
## being behind multiplies the base amount by a negative number (a real
## penalty), not zero.

enum CompareMode { STATUS, FLAT_VALUE }

@export var left_status_effect: Status.StatusEffect = Status.StatusEffect.POISON
@export var left_target: Target = Target.SELF

@export var compare_mode: CompareMode = CompareMode.STATUS
@export var right_status_effect: Status.StatusEffect = Status.StatusEffect.POISON
@export var right_target: Target = Target.TARGET
@export var right_value: int = 0

@export var check_all: bool = false  # ignores left/right_status_effect, compares total stacks instead

func _resolve(combatant: Combatant, status_effect: Status.StatusEffect) -> int:
	if check_all:
		var total: int = 0
		for status in combatant.statuses:
			total += status.stacks
		return total

	var status: Status = combatant.get_status(status_effect)
	return status.stacks if status != null else 0

func compute(user: Combatant, target: Combatant) -> int:
	var left_combatant: Combatant = user if left_target == Target.SELF else target
	var left_val: int = _resolve(left_combatant, left_status_effect)

	var right: int = right_value
	if compare_mode == CompareMode.STATUS:
		var right_combatant: Combatant = user if right_target == Target.SELF else target
		right = _resolve(right_combatant, right_status_effect)

	return (left_val - right) * base_amount(user, target)

## Multiplicative, like StackCountNumericBonus -- describe_bonus()'s default
## "" when describe_lead() is empty is correct here, since the whole bonus
## is 0 regardless of the stack difference in that case (unlike
## StatComparisonNumericBonus's additive difference term, which survives on
## its own and so has to override describe_bonus() directly instead).
func describe_qualifier() -> String:
	var left_str: String = _stack_phrase(left_target, left_status_effect)
	var right_str: String = str(right_value) if compare_mode == CompareMode.FLAT_VALUE else _stack_phrase(right_target, right_status_effect)
	return "times (%s minus %s)" % [left_str, right_str]

func _stack_phrase(stack_target: Target, status_effect: Status.StatusEffect) -> String:
	var whose: String = "the user's" if stack_target == Target.SELF else "the target's"
	if check_all:
		return "%s total status stacks" % whose
	return "%s %s stacks" % [whose, Status.status_link(status_effect)]
