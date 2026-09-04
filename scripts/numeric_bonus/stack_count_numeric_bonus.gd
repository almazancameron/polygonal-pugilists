class_name StackCountNumericBonus
extends NumericBonus

## Multiplies the base flat+percent amount by a status's current stacks --
## e.g. "2 bonus damage per stack of Acid on the target." count_all sums
## every active status's stacks instead of one specific effect. Reuses
## NumericBonus's own Target enum (SELF/TARGET) rather than declaring a
## second identical one -- see StatusCountNumericBonus for the same choice.

@export var count_on: Target = Target.TARGET
@export var count_status_effect: Status.StatusEffect = Status.StatusEffect.POISON
@export var count_all: bool = false

func compute(user: Combatant, target: Combatant) -> int:
	var combatant: Combatant = target if count_on == Target.TARGET else user

	if count_all:
		var total_stacks: int = 0
		for status in combatant.statuses:
			total_stacks += status.stacks
		return total_stacks * base_amount(user, target)
	else:
		var status: Status = combatant.get_status(count_status_effect)
		if status != null:
			return status.stacks * base_amount(user, target)
		else:
			return 0

func describe_qualifier() -> String:
	var whose: String = "the user" if count_on == Target.SELF else "the target"
	if count_all:
		return "for each active status stack on %s" % whose
	return "for each %s stack on %s" % [Status.status_link(count_status_effect), whose]
