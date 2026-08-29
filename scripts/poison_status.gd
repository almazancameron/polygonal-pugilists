class_name PoisonStatus
extends Status

## Stacking damage-over-time with decay: deals damage equal to current
## stacks, then loses a stack, until it runs out.

func status_id() -> StringName:
	return &"poison"

func next_tick_damage() -> int:
	return stacks

func preview_color() -> Color:
	return Color(0.5, 0.2, 0.5, 1.0)

func on_tick(target: Combatant) -> String:
	var damage: int = next_tick_damage()
	target.take_damage(damage)
	stacks -= 1
	return "%s suffers %d poison damage. (%d stacks remain)" % [target.familiar.familiar_name, damage, stacks]