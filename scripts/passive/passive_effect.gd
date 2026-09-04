class_name PassiveEffect
extends Resource

## Shared shape for every rule-following passive (GAME_DESIGN.md §7.3): an
## event to react to, whether it's watching itself or its opponent, what has
## to hold true, and how often it's allowed to fire. What happens when it
## fires is deliberately NOT here -- see the concrete subclasses
## (OperationPassiveEffect, ModifyStatusPassiveEffect, ModifyHealPassiveEffect,
## PermanentStatPassiveEffect), each with its own payload shape rather than
## this base carrying several mutually-exclusive, mostly-unused fields.

## New values must be appended at the end, never inserted -- an authored
## PassiveEffect .tres stores trigger as this enum's raw integer index, so
## inserting a value would silently shift every trigger already saved after
## it onto the wrong meaning.
enum Trigger {
	STATUS_APPLIED,
	STATUS_REDUCED,
	STATUS_REMOVED,
	BATTLE_START,
	BATTLE_END,
	TURN_START,
	TURN_END,
	HIT,
	ATTACK,
	TECHNIQUE_USED,
	DAMAGE_DEALT,
	DAMAGE_TAKEN,
	HEAL_CAST,
	STATUS_CREATED
}

enum Target {
	SELF,
	TARGET,
}

enum Limiter {
	NONE,
	ONCE_PER_TURN,
	ONCE_PER_BATTLE,
	ONCE_PER_TECHNIQUE
}

@export var trigger: Trigger
@export var trigger_target: Target = Target.TARGET

@export var conditions: Array[Condition] = []

@export var limiter: Limiter = Limiter.NONE
