class_name StatusApplicationAction
extends TechniqueAction

enum Target { SELF, TARGET }

@export var target: Target
@export var effect: Status.StatusEffect
@export var stacks: int = 1

#maybe additional vars like tick_magnitude, stack_value, stacks_lost_per_turn, etc eventually