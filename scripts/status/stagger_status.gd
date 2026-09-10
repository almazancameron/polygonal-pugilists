class_name StaggerStatus
extends Status

## Stacking counter that does nothing per-stack. Once stacks reach
## max_stack_count -- from a single application or from merging onto an existing
## Stagger -- it resets to 0 and arms a StunStatus on the target instead.

var max_stack_count: int = 5

func max_stacks() -> int:
	return max_stack_count

func status_id() -> StringName:
	return &"stagger"

func stack_with(other: Status) -> void:
	stacks = min(stacks + other.stacks, max_stack_count)

func on_applied(target: Combatant) -> String:
	if stacks < max_stack_count:
		return "%s is staggered! (%d/%d stacks)" % [
			target.familiar.familiar_name, stacks, max_stack_count
		]

	stacks = 0
	target.add_status(StunStatus.new())
	return "%s loses its balance and gets stunned!" % target.familiar.familiar_name

func preview_color() -> Color:
	return Color(1.0, 0.75, 0.1, 1.0)

func icon() -> Texture2D:
	return preload("res://assets/sprites/icons/stagger_icon.tres")

func describe() -> String:
	return ("Stacks up to %d times. At max stacks, resets to 0 and stuns the target,\n" +
	"causing it to skip its next turn.") % max_stack_count
