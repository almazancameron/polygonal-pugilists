class_name StaggerStatus
extends Status

## Stacking counter that does nothing per-stack. Once stacks reach
## MAX_STACKS -- from a single application or from merging onto an existing
## Stagger -- it resets to 0 and arms a StunStatus on the target instead.

const MAX_STACKS: int = 5

func status_id() -> StringName:
	return &"stagger"

func stack_with(other: Status) -> void:
	stacks = min(stacks + other.stacks, MAX_STACKS)

func on_applied(target: Combatant) -> String:
	if stacks < MAX_STACKS:
		return "%s is staggered! (%d/%d stacks)" % [
			target.familiar.familiar_name, stacks, MAX_STACKS
		]

	stacks = 0
	target.add_status(StunStatus.new())
	return "%s loses its balance and gets stunned!" % target.familiar.familiar_name

func preview_color() -> Color:
	return Color(1, 1, 0.6, 1.0)

func icon() -> Texture2D:
	return preload("res://assets/sprites/icons/stagger_icon.tres")

func describe() -> String:
	return ("Stacks up to %d times. At max stacks, resets to 0 and stuns the target,\n" + 
	"causing it to skip its next turn.") % MAX_STACKS
