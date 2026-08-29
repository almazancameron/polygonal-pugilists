class_name Combatant
extends RefCounted

## Per-battle runtime state for one side of a fight. Wraps a Familiar's
## static stats with the things that change during combat (current_hp,
## is_defending). Created fresh each battle, never saved or edited directly.

var familiar: Familiar
var current_hp: int
var is_defending: bool = false
var statuses: Array[Status] = []

func _init(f: Familiar) -> void:
	familiar = f
	current_hp = f.max_hp

func take_damage(amount: int) -> void:
	current_hp = max(current_hp - amount, 0)

func is_defeated() -> bool:
	return current_hp <= 0

## Re-applying an already-active status stacks onto it instead of tracking
## a second independent instance. Also trigger the status's on_reapply() callback, which can do things like refresh
## duration or trigger a bonus effect. Returns the combat log message from on_reapply(), or "" if nothing happened.
func add_status(new_status: Status) -> String:
	for existing in statuses:
		if existing.status_id() == new_status.status_id():
			var message: String = existing.on_reapply(self)
			existing.stack_with(new_status)
			return message

	statuses.append(new_status)
	return ""

func effective_defense() -> int:
	var modified_defense: int = familiar.defense

	for status in statuses:
		modified_defense = status.modify_defense(modified_defense)
		
	return modified_defense