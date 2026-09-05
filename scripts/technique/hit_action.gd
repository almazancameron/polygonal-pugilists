class_name HitAction
extends TechniqueAction

## A plain damaging hit, resolved through the normal power/defense formula --
## unless ignore_power_and_defense is set, in which case the hit deals exactly
## whatever numeric_bonuses sums to (e.g. a plain flat_bonus), with no power
## scaling and no defense mitigation at all. Needed for passives like "deal 3
## damage to the enemy" (see PassiveEffect.OperationPassiveEffect in
## DECISIONS.md), which shouldn't scale with either combatant's stats.
@export var ignore_power_and_defense: bool = false

## Which side takes the hit -- every other TechniqueAction already has this
## choice (StatusApplicationAction, ModifyStatusAction, HalveAllStatusesAction,
## RandomStatusApplicationAction); HitAction was the one holdout, implicitly
## always hitting the opponent. Needed for a technique that costs its own user
## HP (e.g. Relikarn's Grudge Strike self-damage) -- combine with
## ignore_power_and_defense for a fixed self-inflicted cost independent of
## either combatant's stats. Put a self-targeted HitAction in its own
## TechniqueStepGroup, separate from any target-targeted HitAction in the same
## technique -- numeric_bonuses are summed per step group, not per action, so
## sharing a group would apply the same bonuses to both hits.
enum Target { SELF, TARGET }
@export var target: Target = Target.TARGET
