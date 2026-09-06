class_name ModifyStatPassiveEffect
extends PassiveEffect

## A permanent, always-active stat modifier for as long as this passive is
## equipped -- e.g. "+2 Power" -- consulted directly by
## Combatant.effective_stat() alongside every active status's modify_stat(),
## rather than through the trigger/check_passives() reactive system.
## trigger/conditions/limiter are unused: there's no event to react to.
##
## Distinct from PermanentStatPassiveEffect, which instead mutates the
## Familiar resource itself once, permanently, the moment its trigger fires
## (persisting across battles, like a stat upgrade pick) -- this one only
## affects the current battle's computed stat, recomputed every time
## effective_stat() runs, for as long as the passive is present on the
## familiar.

@export var stat: Familiar.Stat = Familiar.Stat.POWER
@export var flat_bonus: int = 0

func _effect_phrase() -> String:
	if flat_bonus == 0:
		return ""
	return "%s%d %s" % ["+" if flat_bonus > 0 else "", flat_bonus, Familiar.stat_name(stat)]

## Bypasses PassiveEffect.describe()'s trigger/condition phrasing entirely --
## trigger/conditions are unused for this subclass (see the class's own
## docstring: consulted directly by effective_stat(), not through the
## trigger/check_passives() system at all), so describing "when X, +2
## Power" would invent an event that never actually gates anything.
func describe() -> String:
	var effect: String = _effect_phrase()
	if effect == "":
		return "%s does nothing." % passive_name
	return "%s: always active, %s." % [passive_name, effect]
