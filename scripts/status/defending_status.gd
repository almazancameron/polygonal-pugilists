class_name DefendingStatus
extends Status

## Doubles defense for a number of hits equal to the stacks.
## Stacks are consumed on hit and the status is removed when stacks reach 0.

func status_id() -> StringName:
	return &"defending"

func modify_stat(stat: Familiar.Stat, value: int) -> int:
	if stat == Familiar.Stat.DEFENSE:
		return value * 2
	else:
		return value

func on_hit(target: Combatant, _attacker: Combatant) -> String:
	stacks -= 1

	if stacks <= 0:
		return "%s's defense is broken!" % [target.familiar.familiar_name]
	else:
		return "%s braces for the hit, reducing the damage taken! (%d stacks remain)" % [
			target.familiar.familiar_name, stacks
		]

func preview_color() -> Color:
	return Color(0.3, 0.7, 1.0, 1.0)

func icon() -> Texture2D:
	return preload("res://assets/sprites/icons/defend_icon.tres")

func describe() -> String:
	return "Doubles target's defense for %d hit%s. Loses 1 stack per hit." % [
		stacks, "s" if stacks != 1 else ""
	]

func on_applied(target: Combatant) -> String:
	return "%s raises its guard, increasing defense! (%d stack%s)" % [
		target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
	]