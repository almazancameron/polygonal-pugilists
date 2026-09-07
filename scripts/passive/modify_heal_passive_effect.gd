class_name ModifyHealPassiveEffect
extends PassiveEffect

## Adjusts a heal already in progress rather than firing a separate
## reaction -- e.g. "+1 heal power." Consulted by Technique.apply_heal()
## via Combatant.passive_heal_bonus() before the heal amount is finalized,
## folded into the same total numeric_bonuses already contributes to. Runs
## unconditionally, like ModifyStatusPassiveEffect (which this mirrors,
## just for heals instead of a status's stacks) -- a computation input,
## not part of the hooks/cascade system. Kept as its own class rather than
## a second field on ModifyStatusPassiveEffect since a heal bonus has
## nothing to do with a status -- that would just reintroduce the
## dead-field problem PassiveEffect's own subclass split was meant to fix.
##
## Trigger should be HEALED; trigger_target should be SELF, since
## Technique.apply_heal() always heals user, never target -- there's no
## "target's" heal event for a TARGET-scoped instance to ever match. Sharing
## HEALED with the reactive OperationPassiveEffect/PermanentStatPassiveEffect
## use of that same trigger value is safe: check_passives() only ever
## dispatches to those two types, passive_heal_bonus() only ever dispatches
## to this one, so the two paths never see each other's passives.

@export var heal_bonus: int = 0

func _effect_phrase() -> String:
	if heal_bonus == 0:
		return ""
	# "✚" not "+" -- yoster.ttf draws plain ASCII "+" as an icon-like glyph.
	return "✚%d heal power" % heal_bonus
