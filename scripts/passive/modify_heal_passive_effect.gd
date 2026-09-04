class_name ModifyHealPassiveEffect
extends PassiveEffect

## Adjusts a heal already in progress rather than firing a separate
## reaction -- e.g. "+1 heal power." Consulted by Technique.apply_heal()
## via Combatant.passive_heal_bonus() before the heal amount is finalized,
## folded into the same total numeric_bonuses already contributes to. Runs
## unconditionally, like ModifyStatusPassiveEffect (which this mirrors,
## just for heals instead of a status's stacks) -- a computation input,
## not part of the hooks/cascade system. Kept as its own class rather than
## a second field on ModifyStatusPassiveEffect since a heal bonus has
## nothing to do with a status -- that would just reintroduce the
## dead-field problem PassiveEffect's own subclass split was meant to fix.
##
## Trigger should be HEAL_CAST; trigger_target should be SELF, since
## Technique.apply_heal() always heals user, never target -- there's no
## "target's" heal event for a TARGET-scoped instance to ever match.

@export var heal_bonus: int = 0
