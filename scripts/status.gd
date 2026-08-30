class_name Status
extends RefCounted

## Base shape for an active status effect on a Combatant. Per-battle runtime
## state, same reasoning as Combatant: never saved or edited in the
## Inspector, so RefCounted rather than Resource or Node.

enum StatusEffect { NONE, POISON, BURN, ACID, BLEED, STAGGER, FORETELL, STUN, DEFENDING }

var stacks: int = 1

func _init(initial_stacks: int = 1) -> void:
	stacks = initial_stacks

## Identifies "the same" status for stacking purposes. Compared by value
## since GDScript has no clean built-in "same subclass" check.
func status_id() -> StringName:
	return &"status"

func stack_with(other: Status) -> void:
	stacks += other.stacks

## Called once when it's this status's turn to act. Returns a combat log
## message, or "" if nothing happened. Override in subclasses.
func on_tick(target: Combatant) -> String:
	return ""

## Called when this status is re-applied to a target that already has it.
## Returns a combat log message, or "" if nothing happened. Override in subclasses.
func on_reapply(target: Combatant) -> String:
	return ""

## Called whenever this combatant is hit by a technique's damage. Returns a
## combat log message, or "" if nothing happened. Override in subclasses.
func on_hit(target: Combatant) -> String:
	return ""

## Called whenever this status's stacks have just been set, whether from a
## fresh application or a stack_with() merge. Returns a combat log message,
## or "" if nothing happened. Override in subclasses.
func on_applied(target: Combatant) -> String:
	return ""

func is_expired() -> bool:
	return stacks <= 0

func next_tick_damage() -> int:
	return 0

func preview_color() -> Color:
	return Color(0, 0, 0, 1)

func modify_defense(base_defense: int) -> int:
	return base_defense

func icon() -> Texture2D:
	return null

func describe() -> String:
	return "Status"

## Translates a StatusEffect enum value to the StringName a concrete
## Status subclass's own status_id() returns. Lets other classes
## (Technique, Condition subclasses) compare against StatusEffect
## directly instead of keeping their own separate enum-to-StringName table.
static func status_effect_id(effect: StatusEffect) -> StringName:
	match effect:
		StatusEffect.POISON:
			return &"poison"
		StatusEffect.BURN:
			return &"burn"
		StatusEffect.ACID:
			return &"acid"
		StatusEffect.BLEED:
			return &"bleed"
		StatusEffect.STAGGER:
			return &"stagger"
		StatusEffect.FORETELL:
			return &"foretell"
		StatusEffect.STUN:
			return &"stun"
		StatusEffect.DEFENDING:
			return &"defending"
		_:
			return &""