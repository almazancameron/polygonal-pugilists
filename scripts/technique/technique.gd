class_name Technique
extends Resource

## A familiar's authored combat action: static build data the same way
## Familiar's stats are, so it can be assigned in the Inspector via
## Familiar.techniques and saved to its own .tres file.

@export var technique_name: String = "Technique"

@export var power_multiplier: float = 1.0 #How much of the familiar's power stat is applied to damage

@export var step_groups: Array[TechniqueStepGroup] = []

## Deals damage (respecting Defend), heals, and applies each entry in
## status_effects, all per the hit_count/heal_applications/status_applications
## counts. Override this entirely for a technique whose control flow doesn't
## fit that loop shape at all (e.g. one that reaches into priority_rules or
## turn order).
func execute(user: Combatant, target: Combatant) -> Array[Callable]:
	var steps: Array[Callable] = []

	for step_group in step_groups:
		var conditions_met: bool = true
		for condition in step_group.conditions:
			if not condition.is_met(user, target):
				conditions_met = false
				break
		
		if not conditions_met:
			continue

		for i in range(step_group.repeat_count):
			for action in step_group.actions:

				if action is HitAction:
					var step = func() -> String:
						return apply_hit(user, target, step_group.damage_bonuses)
					steps.append(step)

				elif action is StatusApplicationAction:
					var step = func() -> String:
						return apply_status(user, target, action)
					steps.append(step)

				elif action is ModifyStatusAction:
					var step = func() -> String:
						return modify_status(user, target, action)
					steps.append(step)

				elif action is HealAction:
					var step = func() -> String:
						return apply_heal(user, target, action)
					steps.append(step)

	return steps

func apply_hit(user: Combatant, target: Combatant, damage_bonuses: Array[DamageBonus]) -> String:
	if target.is_defeated():
		return ""

	var mitigation: int = target.effective_defense()
	var damage_bonuses_total: int = 0
	for damage_bonus in damage_bonuses:
		damage_bonuses_total += damage_bonus.compute(user, target)
	var calculated_damage: int = int(user.effective_power() * power_multiplier) + damage_bonuses_total
	var damage: int = max(calculated_damage - mitigation, 1)

	var message: String = ""
	
	if damage > 0:
		var actual_damage: int = target.take_damage(damage)
		message += "%s uses %s on %s for %d damage!" % [
			user.familiar.familiar_name, technique_name, target.familiar.familiar_name, actual_damage
		]

		var attack_message: String = user.trigger_on_attack()
		if attack_message != "":
			message += " " if message != "" else ""
			message += attack_message

		var hit_message: String = target.trigger_on_hit(user)
		if hit_message != "":
			message += " " if message != "" else ""
			message += hit_message

	return message

func apply_status(user: Combatant, target: Combatant, status_application: StatusApplicationAction) -> String:
	if status_application.target == StatusApplicationAction.Target.TARGET and target.is_defeated():
		return ""

	var message: String = ""

	var status: Status = Status.create(status_application.effect, status_application.stacks)
	var status_target: Combatant = user if status_application.target == StatusApplicationAction.Target.SELF else target

	if status:
		var reapply_message: String = status_target.add_status(status)
		if reapply_message != "":
			message += " " if message != "" else ""
			message += reapply_message
		else:
			message += "%spplied %d stack%s of %s." % [
				" Also a" if message != "" else "A",
				status.stacks, "s" if status.stacks != 1 else "", 
				String(status.status_id()).capitalize()
			]

	return message

func modify_status(user: Combatant, target: Combatant, modify_status_action: ModifyStatusAction) -> String:
	if modify_status_action.target == ModifyStatusAction.Target.TARGET and target.is_defeated():
		return ""

	var message: String = ""

	var status_target: Combatant = user if modify_status_action.target == ModifyStatusAction.Target.SELF else target

	var modify_message: String = status_target.modify_status_stacks(modify_status_action.effect, modify_status_action.modifier, modify_status_action.operator)
	if modify_message != "":
		message += " " if message != "" else ""
		message += modify_message

	return message
	
func apply_heal(user: Combatant, target: Combatant, heal: HealAction) -> String:
	var mitigation: int = target.effective_defense()
	var damage: int = max(int(user.effective_power() * power_multiplier) - mitigation, 1)

	var message: String = ""

	var heal_amount: int = int(damage * heal.heal_percent) + heal.heal_flat

	if heal_amount > 0:
		user.heal(heal_amount)
		message += "%s heals for %d health!" % [user.familiar.familiar_name, heal_amount]

	return message