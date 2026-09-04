class_name OperationPassiveEffect
extends PassiveEffect

## Fires a separate, reactive consequence, e.g. "deal 3 damage to the
## enemy" or "apply 3 stacks of Ward to yourself at battle start" -- as
## opposed to ModifyStatusPassiveEffect (adjusts an application already in
## progress) or PermanentStatPassiveEffect (a permanent stat change).

## A full Technique rather than a bare TechniqueStepGroup -- Technique.execute()
## already runs standalone and returns exactly the Array[Callable] shape
## Combatant._fire_operation() needs, and its power_multiplier/technique_name
## read naturally in the combat log. Author its step_groups[].conditions
## empty -- this PassiveEffect's own conditions is the real gate.
@export var operation: Technique

## Whether running operation also fires the same action-level ambient
## triggers a real technique action would (HIT/ATTACK/STATUS_APPLIED, and
## anything else added inside Technique.apply_hit()/apply_status()/
## apply_heal() later) -- false by default so a passive's own damage
## doesn't silently look like an attack to other reactive statuses/passives
## unless explicitly authored to (e.g. "deals 1 damage at the start of each
## turn, triggers on-hit effects"). Has no effect on turn-level triggers
## (TECHNIQUE_USED, TURN_START/END) -- those live outside
## Technique.execute() entirely, so a passive's operation can never reach
## them regardless of this flag.
@export var triggers_hooks: bool = false
