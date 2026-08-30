class_name PriorityRule
extends Resource

## Pairs a set of conditions (ALL must be met) with the technique to use
## when they are. A familiar's priority_rules is an ordered list of these
## -- the first rule whose conditions all hold wins. An empty conditions
## array is vacuously true, so it doubles as an unconditional catch-all.

@export var conditions: Array[Condition] = []
@export var technique: Technique
