class_name TradePassiveUpgrade
extends UpgradeOption

## The round-4 cadence's dedicated reward: give up one currently-held
## passive for a new one. passive_to_remove is resolved once, immediately,
## on the reward flow's sacrifice screen -- BEFORE these replacement
## candidates are even generated (see RewardFlowController), never left
## unresolved. Not @export: it's per-instance runtime state tied to which
## passive *this* familiar chose to give up, not authored data.

@export var new_passive: PassiveEffect
var passive_to_remove: PassiveEffect

func describe() -> String:
	return "Trade %s for %s" % [passive_to_remove.passive_name, new_passive.describe()]

func apply(familiar: Familiar) -> void:
	familiar.passives.erase(passive_to_remove)
	familiar.passives.append(new_passive)
