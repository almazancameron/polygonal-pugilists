class_name RandomStatusApplicationAction
extends TechniqueAction

## Applies a fixed number of stacks of a status chosen at random each time
## this step actually runs -- picked fresh from every real Status.StatusEffect
## value (NONE excluded, since it's a placeholder rather than a real status),
## no authored pool to narrow it down.
##
## Genuine randomness: unlike the rest of this game's combat (deliberately
## deterministic -- see .claude/BALANCE_TEST_PLAN.md), a technique using this
## can't be evaluated by the round-robin harness's usual "run each pair twice"
## approach, since the same pairing can now produce different results run to
## run. Worth knowing before authoring content with this on a familiar meant
## to go through balance_test.gd.

enum Target { SELF, TARGET }

@export var target: Target
@export var stacks: int = 1

## Godot's Array.pick_random() handles the actual RNG. Returns a fresh pick
## every call -- not cached on this resource, since this action is shared,
## authored data (the same instance backs every use of the technique that
## owns it), and stashing "the current roll" on it would leak one execution's
## result into every other combatant/battle that references the same
## resource -- exactly the shared-mutable-state mistake this project's own
## fallback_attack.tres incident already taught (see DECISIONS.md).
func pick_random_effect() -> Status.StatusEffect:
	var choices: Array = Status.StatusEffect.values()
	choices.erase(Status.StatusEffect.NONE)
	return choices.pick_random()
