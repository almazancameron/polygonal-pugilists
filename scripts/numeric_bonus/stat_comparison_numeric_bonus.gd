class_name StatComparisonNumericBonus
extends NumericBonus

## Adds the difference between two stats to the base flat+percent amount --
## e.g. "bonus damage equal to how much your Power exceeds their Defense."
## Same left/right/target/compare_mode vocabulary as StatComparisonCondition
## (learning one teaches the other), and the difference isn't clamped to a
## minimum of 0: being behind on the comparison subtracts from the bonus
## (a real penalty) rather than just contributing nothing. Leave flat_bonus
## and percent_bonus at 0 for a pure difference-only bonus.

enum CompareMode { STAT, FLAT_VALUE }

@export var left_stat: Familiar.Stat = Familiar.Stat.POWER
@export var left_target: Target = Target.SELF

@export var compare_mode: CompareMode = CompareMode.STAT
@export var right_stat: Familiar.Stat = Familiar.Stat.DEFENSE
@export var right_target: Target = Target.TARGET
@export var right_value: int = 0

func compute(user: Combatant, target: Combatant) -> int:
	var left_combatant: Combatant = user if left_target == Target.SELF else target
	var left_val: int = left_combatant.effective_stat(left_stat)

	var right: int = right_value
	if compare_mode == CompareMode.STAT:
		var right_combatant: Combatant = user if right_target == Target.SELF else target
		right = right_combatant.effective_stat(right_stat)

	return base_amount(user, target) + (left_val - right)
