class_name HalveAllStatusesAction
extends TechniqueAction

## Halves every active status's stacks on one side (integer division, so a
## 1-stack status is removed entirely) -- unlike ModifyStatusAction, which
## targets one specific Status.StatusEffect, this touches every status
## currently active on whichever side it's aimed at. Genuinely different
## logic (iterate all active statuses vs. look up one by id), not just a
## different number, hence its own action class rather than a new field on
## ModifyStatusAction.

enum Target { SELF, TARGET }

@export var target: Target = Target.TARGET
