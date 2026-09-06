class_name PermanentStatPassiveEffect
extends PassiveEffect

## A permanent, run-persistent stat change -- "gain 5 Focus permanently at
## the end of combat," "gain 1 Speed permanently at the start of each
## turn." Distinct from a temporary buff (already fully expressible as an
## OperationPassiveEffect applying a Fortify/Hone-style Status): this
## mutates the Familiar resource itself via the same ModifyStatUpgrade
## payload stat upgrades already use, so it carries over between battles
## the same way an upgrade pick does -- Combatant is recreated fresh every
## battle, but familiar is the same resource object across the whole run.
##
## stat_change.bonus is a flat amount for now. Scaling the amount with
## something else (e.g. "+5 Focus per Foretell stack you have") is expected
## eventually but deliberately deferred until a concrete passive needs it.
@export var stat_change: ModifyStatUpgrade

func _effect_phrase() -> String:
	if stat_change == null:
		return ""
	return stat_change.describe()
