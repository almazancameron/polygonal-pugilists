class_name PoisonStatus
extends Status

## Stacking damage-over-time with decay: deals damage equal to current
## stacks, then loses a stack, until it runs out.

func status_id() -> StringName:
	return &"poison"

func next_tick_damage() -> int:
	return stacks

func preview_color() -> Color:
	return Color(0.5, 0.2, 0.7, 1.0)

func on_tick(target: Combatant) -> String:
	var damage: int = target.take_damage(next_tick_damage())
	stacks -= 1
	return "%s suffers %d poison damage. (%d stacks remain)" % [target.familiar.familiar_name, damage, stacks]

func icon() -> Texture2D:
	return preload("res://assets/sprites/icons/poison_icon.tres")

func describe() -> String:
	return ("Deals %d damage (based on stacks) at the start of target's turn.\n" +
	"Loses 1 stack per turn.") % [stacks]

func on_applied(target: Combatant) -> String:
	return "%s is poisoned! (%d stack%s)" % [
		target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
	]