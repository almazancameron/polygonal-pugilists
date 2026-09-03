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
						return apply_hit(user, target, step_group.numeric_bonuses)
					steps.append(step)

				elif action is StatusApplicationAction:
					var step = func() -> String:
						return apply_status(user, target, action, step_group.numeric_bonuses)
					steps.append(step)

				elif action is ModifyStatusAction:
					var step = func() -> String:
						return modify_status(user, target, action)
					steps.append(step)

				elif action is HealAction:
					var step = func() -> String:
						return apply_heal(user, target, action, step_group.numeric_bonuses)
					steps.append(step)

	return steps

## Sums whichever of a step group's numeric_bonuses are tagged for the
## given action type -- see NumericBonus.applies_to for why a group can
## hold several independently-targeted bonuses at once instead of needing
## to be split per bonus target.
func _sum_bonuses(bonuses: Array[NumericBonus], action_type: NumericBonus.ActionType, user: Combatant, target: Combatant) -> int:
	var total: int = 0
	for bonus in bonuses:
		if bonus.applies_to == action_type:
			total += bonus.compute(user, target)
	return total

func apply_hit(user: Combatant, target: Combatant, numeric_bonuses: Array[NumericBonus]) -> String:
	if target.is_defeated():
		return ""

	var target_defense: int = target.effective_defense()

	var user_power: int = user.effective_power()
	var raw_technique_damage: int = int(user_power * power_multiplier)
	var bonuses_total: int = _sum_bonuses(numeric_bonuses, NumericBonus.ActionType.HIT, user, target)
	var raw_damage: int = raw_technique_damage + bonuses_total
	
	var post_mit_damage: int = (raw_damage * raw_damage / (raw_damage + target_defense))
	var damage = max(post_mit_damage, 1)

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

func apply_status(user: Combatant, target: Combatant, status_application: StatusApplicationAction, numeric_bonuses: Array[NumericBonus]) -> String:
	if status_application.target == StatusApplicationAction.Target.TARGET and target.is_defeated():
		return ""

	var message: String = ""

	var bonus_total: int = _sum_bonuses(numeric_bonuses, NumericBonus.ActionType.STATUS, user, target)
	var status: Status = Status.create(status_application.effect, status_application.stacks + bonus_total)
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
	
func apply_heal(user: Combatant, target: Combatant, heal: HealAction, numeric_bonuses: Array[NumericBonus]) -> String:
	var mitigation: int = target.effective_defense()
	var damage: int = max(int(user.effective_power() * power_multiplier) - mitigation, 1)

	var message: String = ""

	var bonus_total: int = _sum_bonuses(numeric_bonuses, NumericBonus.ActionType.HEAL, user, target)
	var heal_amount: int = int(damage * heal.heal_percent) + heal.heal_flat + bonus_total

	if heal_amount > 0:
		var actual_heal: int = user.heal(heal_amount)
		message += "%s heals for %d health!" % [user.familiar.familiar_name, actual_heal]

	return message

## A human-readable summary built from step_groups, for tooltips and reward
## offers. The only content class that lacked a describe() -- Status,
## Condition and UpgradeOption all had one -- which is why
## AddTechniqueUpgrade could only offer a bare "Learn <name>".
##
## Status names are wrapped in [url=...] so TooltipPanel's meta_hover path
## resolves them into nested status tooltips; see tooltip_panel.gd's
## _on_meta_hover_started().
func describe() -> String:
	var parts: Array[String] = []

	for step_group in step_groups:
		var group_parts: Array[String] = []

		# A group's numeric_bonuses can dwarf the base amount -- Ultra Beam's
		# charged hit is power_multiplier 0.1 plus a +390%-of-Power bonus, so
		# describing the multiplier alone would report 10% for a move that
		# actually lands around 400%.
		var hit_bonus: String = _bonus_summary(step_group.numeric_bonuses, NumericBonus.ActionType.HIT)
		var status_bonus: String = _bonus_summary(step_group.numeric_bonuses, NumericBonus.ActionType.STATUS)
		var heal_bonus: String = _bonus_summary(step_group.numeric_bonuses, NumericBonus.ActionType.HEAL)

		for action in step_group.actions:
			if action is HitAction:
				group_parts.append("deals %d%% damage%s" % [int(power_multiplier * 100), hit_bonus])

			elif action is StatusApplicationAction:
				group_parts.append("applies %d%s %s to %s" % [
					action.stacks,
					status_bonus,
					_status_link(action.effect),
					"self" if action.target == StatusApplicationAction.Target.SELF else "target",
				])

			elif action is ModifyStatusAction:
				group_parts.append("%s %s's %s" % [
					_operator_phrase(action.operator, action.modifier),
					"self" if action.target == ModifyStatusAction.Target.SELF else "target",
					_status_link(action.effect),
				])

			elif action is HealAction:
				if action.heal_percent > 0.0 and action.heal_flat > 0:
					group_parts.append("heals %d%% of damage dealt +%d%s" % [
						int(action.heal_percent * 100), action.heal_flat, heal_bonus
					])
				elif action.heal_percent > 0.0:
					group_parts.append("heals %d%% of damage dealt%s" % [
						int(action.heal_percent * 100), heal_bonus
					])
				else:
					group_parts.append("heals %d%s" % [action.heal_flat, heal_bonus])

		if group_parts.is_empty():
			continue

		var group_text: String = ", ".join(group_parts)

		if step_group.repeat_count > 1:
			group_text = "%s (x%d)" % [group_text, step_group.repeat_count]

		if not step_group.conditions.is_empty():
			var condition_texts: Array[String] = []
			for condition in step_group.conditions:
				condition_texts.append(condition.describe())
			group_text = "%s, if %s" % [group_text, " and ".join(condition_texts)]

		parts.append(group_text)

	if parts.is_empty():
		return "%s does nothing." % technique_name

	return "%s: %s." % [technique_name, "; ".join(parts)]

## Wraps a status name in the [url=...] markup TooltipPanel resolves, so a
## technique tooltip's status names get their own nested tooltips.
func _status_link(effect: Status.StatusEffect) -> String:
	var id: StringName = Status.status_effect_id(effect)
	return "[url=%s]%s[/url]" % [id, String(id).capitalize()]

## Summarizes whichever of a group's bonuses are tagged for one action type,
## as a trailing fragment ("" when there are none). Reads the base class's
## static flat_bonus/percent_bonus rather than calling compute(), which
## needs live combatants describe() doesn't have.
##
## Only the base NumericBonus appears in authored content today (ultra_beam
## is the sole user). The subclasses -- Conditional/StackCount/
## StackComparison/StatComparison/StatusCount -- change how compute() scales
## that base, so once one of them gets authored this will understate it, and
## the fix is a describe() on NumericBonus that subclasses override rather
## than more branching here.
func _bonus_summary(bonuses: Array[NumericBonus], action_type: NumericBonus.ActionType) -> String:
	var fragments: Array[String] = []

	for bonus in bonuses:
		if bonus.applies_to != action_type:
			continue
		if bonus.flat_bonus != 0:
			fragments.append("+%d" % bonus.flat_bonus)
		if not is_zero_approx(bonus.percent_bonus):
			fragments.append("+%d%% of %s" % [
				int(bonus.percent_bonus * 100), _percent_source_phrase(bonus)
			])

	if fragments.is_empty():
		return ""

	return " " + " ".join(fragments)

func _percent_source_phrase(bonus: NumericBonus) -> String:
	var whose: String = "user's" if bonus.percent_target == NumericBonus.Target.SELF else "target's"

	match bonus.percent_source:
		NumericBonus.ValueSource.STAT:
			return "%s %s" % [whose, Familiar.stat_name(bonus.percent_stat)]
		NumericBonus.ValueSource.STATUS_STACKS:
			if bonus.percent_check_all:
				return "%s total status stacks" % whose
			return "%s %s stacks" % [whose, _status_link(bonus.percent_status_effect)]
		NumericBonus.ValueSource.STATUS_COUNT:
			return "%s active status count" % whose
		NumericBonus.ValueSource.HP:
			return "%s current HP" % whose

	return whose

func _operator_phrase(operator: ModifyStatusAction.Operator, modifier: float) -> String:
	match operator:
		ModifyStatusAction.Operator.MULTIPLY:
			return "multiplies by %s" % modifier
		ModifyStatusAction.Operator.SUBTRACT:
			return "removes %d from" % int(modifier)
		ModifyStatusAction.Operator.DIVIDE:
			return "divides by %s" % modifier
		ModifyStatusAction.Operator.SET:
			return "sets to %d" % int(modifier)
	return "changes"