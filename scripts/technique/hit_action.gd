class_name HitAction
extends TechniqueAction

## Uses the normal Power/Defense formula unless ignore_power_and_defense is
## set. Flat hits use int(Technique.power_multiplier) as a literal base, add
## the group's HIT bonuses, and clamp to at least 1 before incoming-damage
## effects and Absorption. The base does not multiply the user's Power.
@export var ignore_power_and_defense: bool = false

## Which side takes the hit. SELF supports techniques that cost their user
## HP (e.g. Relikarn's Grudge Strike self-damage) -- combine with
## ignore_power_and_defense for a fixed self-inflicted cost independent of
## either combatant's stats. Put a self-targeted HitAction in its own
## TechniqueStepGroup, separate from any target-targeted HitAction in the same
## technique -- numeric_bonuses are summed per step group, not per action, so
## sharing a group would apply the same bonuses to both hits.
enum Target { SELF, TARGET }
@export var target: Target = Target.TARGET
