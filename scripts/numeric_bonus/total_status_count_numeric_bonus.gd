class_name TotalStatusCountNumericBonus
extends NumericBonus

## Multiplies the base flat+percent amount by how many distinct statuses
## are active across BOTH combatants combined -- unlike StatusCountNumericBonus,
## which only ever reads one side. Built for Reap (the final boss's kit):
## a payoff hit that scales with how loaded up the whole fight state
## currently is, not just what one side is carrying.

func compute(user: Combatant, target: Combatant) -> int:
	var total_statuses: int = user.statuses.size() + target.statuses.size()
	return total_statuses * base_amount(user, target)

func describe_qualifier() -> String:
	return "for each active status on either combatant"
