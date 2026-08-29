class_name Technique
extends Resource

## A familiar's authored combat action: static build data the same way
## Familiar's stats are, so it can be assigned in the Inspector via
## Familiar.techniques and saved to its own .tres file.

enum StatusEffect { NONE, POISON, BURN, ACID }

@export var technique_name: String = "Technique"
@export var power_multiplier: float = 1.0
@export var status_effect: StatusEffect = StatusEffect.NONE
@export var status_stacks: int = 1

## Deals damage (respecting Defend) and applies whatever _create_status()
## returns, if any. Override this entirely for techniques that don't fit
## the damage-then-maybe-status shape (see DefendTechnique).
func execute(user: Combatant, target: Combatant) -> String:
	var mitigation: int = target.effective_defense() * (2 if target.is_defending else 1)
	var damage: int = max(int(user.familiar.power * power_multiplier) - mitigation, 1)

	target.is_defending = false
	target.take_damage(damage)

	var message: String = "%s uses %s on %s for %d damage!" % [
		user.familiar.familiar_name, technique_name, target.familiar.familiar_name, damage
	]

	var status: Status = _create_status()
	if status:
		var reapply_message: String = target.add_status(status)
		if reapply_message != "":
			message += " " + reapply_message
		else:
			message += " Also applied %d stack%s of %s." % [
				status.stacks, "s" if status.stacks != 1 else "", String(status.status_id()).capitalize()
			]

	return message

## Builds the status this technique applies on hit, or null if it applies
## none, based on status_effect/status_stacks. Every current status just
## takes an initial-stacks int, so one factory covers all of them -- a
## technique with a genuinely different status shape can still bypass this
## entirely by overriding execute() instead, the way DefendTechnique does.
func _create_status() -> Status:
	match status_effect:
		StatusEffect.POISON:
			return PoisonStatus.new(status_stacks)
		StatusEffect.BURN:
			return BurnStatus.new(status_stacks)
		StatusEffect.ACID:
			return AcidStatus.new(status_stacks)
		_:
			return null
