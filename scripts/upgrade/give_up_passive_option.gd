class_name GiveUpPassiveOption
extends UpgradeOption

## Display-only wrapper for the sacrifice screen's first step (which
## currently-held passive to give up) -- RewardCard.setup() expects an
## UpgradeOption to read label/describe() from, but apply() is never
## called on this one (inherits UpgradeOption's own no-op). Choosing a
## passive here isn't itself a Familiar mutation -- it just tells
## RewardFlowController.resolve_sacrifice() which passive to build the
## replacement (TradePassiveUpgrade) candidates around; the actual trade
## only happens once the step-2 replacement card is confirmed.

@export var passive: PassiveEffect

func describe() -> String:
	return passive.describe()
