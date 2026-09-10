class_name ForetellStatus
extends Status

## Countdown that bursts when upkeep or reapplication reduces stacks to zero.
## Both request a reduction of stacks_lost_per_tick; reapplication accelerates
## the countdown instead of refreshing or extending it.
var burst_damage: int = 9
var stacks_lost_per_tick: int = 1  # also spent by a reapply -- see on_reapply()

func status_id() -> StringName:
	return &"foretell"

## Incoming stacks do not extend the countdown. on_reapply() instead requests
## a reduction of stacks_lost_per_tick through the stack setter.
func stack_with(_other: Status) -> void:
	pass

func on_tick(target: Combatant) -> String:
	stacks -= stacks_lost_per_tick
	if stacks <= 0:
		return _trigger_burst(target)
	return ""

func on_reapply(target: Combatant) -> String:
	stacks -= stacks_lost_per_tick
	if stacks <= 0:
		return _trigger_burst(target)
	return "%s's foretold fate draws nearer. (%d turn%s remaining.)" % [
		target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
	]

func _trigger_burst(target: Combatant) -> String:
	stacks = 0
	var damage: int = target.take_damage(burst_damage)
	return "%s's foretold fate manifests, dealing %d burst damage!" % [target.familiar.familiar_name, damage]

func next_tick_damage() -> int:
	return burst_damage if stacks <= stacks_lost_per_tick else 0

func preview_color() -> Color:
	return Color(0.8, 0.1, 0.55, 1.0)

func icon() -> Texture2D:
	return preload("res://assets/sprites/icons/foretell_icon.tres")

func describe() -> String:
	return "After %d turn%s (reduced by 1 when reapplied) pass%s, deal a burst of %d damage." % [
		stacks, "s" if stacks != 1 else "", "es" if stacks == 1 else "", burst_damage
	]

func on_applied(target: Combatant) -> String:
	return "%s's fate is foretold! (%d turn%s remain.)" % [
		target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
	]
