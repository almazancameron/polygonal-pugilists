@tool
class_name ModifyStatusPassiveEffect
extends PassiveEffect

## Adjusts a status application already in progress rather than firing a
## separate reaction -- e.g. "+1 Poison stack applied per application."
## Consulted by Technique.apply_status() *before* Status.create() runs, via
## Combatant.passive_stack_bonus(), and folded into the same stacks total
## numeric_bonuses already contributes to. This can't be expressed as an
## OperationPassiveEffect: bolting a stack increase on *after* a status
## lands (e.g. via a hypothetical ModifyStatusAction ADD) would incorrectly
## fire on_reapply() on what the player experiences as a fresh application
## -- wrongly triggering Burn's Flare, consuming one of Foretell's countdown
## turns, etc. Runs unconditionally, unlike OperationPassiveEffect.triggers_hooks
## -- it's a computation input like NumericBonus, not part of the
## hooks/cascade system, so it applies to every status application (real
## techniques included) regardless of which passive/technique caused it.
##
## field_name/field_bonus (empty field_name = unused) generalizes this to
## any of the standardized numeric fields the status-field pass added
## (BurnStatus.flare_damage, ForetellStatus.burst_damage,
## LifestealStatus.heal_percent_of_power, etc.), via Object.get()/set()
## reflection -- Combatant.apply_passive_field_bonuses(), called from
## add_status() itself (not Technique.apply_status(), unlike stack_bonus)
## so it can target whichever Status instance actually survives a
## reapply-merge, not a transient pre-merge instance whose non-stacks
## fields stack_with() would otherwise silently discard. Applied before
## on_reapply()/on_applied() run, so a status that reads its own boosted
## field mid-reapply (e.g. Burn's flare reading flare_damage) sees it.
## Compounds across repeated reapplications exactly as much as the status's
## own stack_with()/reapply logic already lets stack_bonus compound --
## not a new behavior this introduces.
##
## @tool exists solely so the editor runs _validate_property() below, which
## turns field_name's Inspector row from a free-text box into a dropdown of
## the fields that actually exist on the selected status. Nothing here runs
## game logic in the editor.

@export var status_effect: Status.StatusEffect = Status.StatusEffect.NONE:
	set(value):
		status_effect = value
		# field_name's dropdown is built from whichever status is selected, so
		# picking a different one has to rebuild this resource's property list.
		notify_property_list_changed()

@export var stack_bonus: int = 0

@export var field_name: StringName = &""
@export var field_bonus: float = 0.0

## Rewrites how field_name is presented in the Inspector -- same StringName
## storage, but offered as a dropdown restricted to the selected status's own
## numeric fields, so a Poison passive can't be pointed at BurnStatus.flare_damage
## (or at a typo, which Combatant.apply_passive_field_bonuses() would turn into
## a null + float error).
func _validate_property(property: Dictionary) -> void:
	if property.name != "field_name":
		return

	var choices: Array[String] = _tunable_field_names()
	# Leading empty entry keeps "unused" selectable: a String/StringName enum
	# stores the chosen entry itself rather than an index, so there's no
	# separate NONE constant to offer -- the empty name *is* the empty value.
	choices.insert(0, "")

	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(choices)

## Every int/float field on the selected status except stacks, which has its
## own dedicated stack_bonus. Found by reflection rather than a hand-written
## enum + name table, so a numeric field added to any status shows up here
## without a second place needing to be updated.
func _tunable_field_names() -> Array[String]:
	var names: Array[String] = []

	var status: Status = Status.create(status_effect)
	if status == null:  # StatusEffect.NONE, or an effect create() doesn't build
		return names

	for property in status.get_property_list():
		if not (property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if property.type != TYPE_INT and property.type != TYPE_FLOAT:
			continue
		if property.name == &"stacks":
			continue

		names.append(String(property.name))

	return names

func _effect_phrase() -> String:
	if status_effect == Status.StatusEffect.NONE:
		return ""

	var parts: Array[String] = []

	if stack_bonus != 0:
		parts.append("+%d stack%s" % [stack_bonus, "s" if stack_bonus != 1 else ""])

	if field_name != &"":
		parts.append("+%s %s" % [field_bonus, field_name])

	if parts.is_empty():
		return ""

	return "boosts %s (%s)" % [Status.status_link(status_effect), ", ".join(parts)]
