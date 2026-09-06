class_name AddPassiveUpgrade
extends UpgradeOption

## Grants a new passive. Uncapped/always-additive -- Familiar.passives has
## no cap, so this always just appends; no trade-off logic here (see
## TradePassiveUpgrade for the round-4 cadence's dedicated trade reward).

@export var passive: PassiveEffect

func describe() -> String:
	return passive.describe()

func apply(familiar: Familiar) -> void:
	familiar.passives.append(passive)
