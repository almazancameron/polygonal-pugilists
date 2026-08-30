class_name ForetellStatus
extends Status

## Duration-based status that does nothing per tick. Once its duration
## reaches 0 -- whether from a normal upkeep tick or from an early reapply
## -- it fires a burst of damage instead of expiring quietly. Reapplying
## doesn't refresh or add to the duration; it costs the countdown one extra
## turn, which can trigger the burst immediately if that was its last turn.

var burst_damage: int = 15  # TODO: tune once there's a real technique using this

func status_id() -> StringName:
	return &"foretell"

## The newly-applied instance's own stack count is irrelevant -- reapplying
## always costs exactly one extra turn, handled in on_reapply() instead.
func stack_with(_other: Status) -> void:
	pass

func on_tick(target: Combatant) -> String:
	stacks -= 1
	if stacks <= 0:
		return _trigger_burst(target)
	return ""

func on_reapply(target: Combatant) -> String:
	stacks -= 1
	if stacks <= 0:
		return _trigger_burst(target)
	return "%s's foretell accelerates -- now %d turn%s away." % [
		target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
	]

func _trigger_burst(target: Combatant) -> String:
	stacks = 0
	target.take_damage(burst_damage)
	return "%s's foretell fires, dealing %d burst damage!" % [target.familiar.familiar_name, burst_damage]

func preview_color() -> Color:
	return Color(0.8, 0.1, 0.55, 1.0)

func icon() -> Texture2D:
	return preload("res://assets/sprites/icons/foretell_icon.tres")

func describe() -> String:
	return "After %d turn%s (reduced by 1 when reapplied) pass%s, deal a burst of %d damage." % [
		stacks, "s" if stacks != 1 else "", "es" if stacks == 1 else "", burst_damage
	]
