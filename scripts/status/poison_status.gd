class_name PoisonStatus
extends Status

## Stacking damage-over-time with decay: deals damage equal to current
## stacks (times damage_per_stack), then loses a stack, until it runs out.

var damage_per_stack: int = 1
var stacks_lost_per_tick: int = 1

func status_id() -> StringName:
	return &"poison"

func next_tick_damage() -> int:
	return damage_per_stack * stacks

func preview_color() -> Color:
	return Color(0.5, 0.2, 0.7, 1.0)

func on_tick(target: Combatant) -> String:
	var damage: int = target.take_damage(next_tick_damage())
	stacks -= stacks_lost_per_tick
	return "%s suffers %d poison damage. (%d stacks remain)" % [target.familiar.familiar_name, damage, stacks]

func icon() -> Texture2D:
	return preload("res://assets/sprites/icons/poison_icon.tres")

func describe() -> String:
	return ("Deals %d damage (based on stacks) at the start of target's turn.\n" +
	"Loses %d stack%s per turn.") % [next_tick_damage(), stacks_lost_per_tick, "s" if stacks_lost_per_tick != 1 else ""]

func on_applied(target: Combatant) -> String:
	return "%s is poisoned! (%d stack%s)" % [
		target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
	]