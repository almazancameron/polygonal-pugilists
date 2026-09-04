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
## trigger_hooks controls whether this run's hit/status actions cascade into
## the action-level ambient triggers (HIT/ATTACK/STATUS_APPLIED, see
## apply_hit()/apply_status()) -- true for every real turn (the default an
## ordinary take_turn() call relies on), false when a PassiveEffect's own
## operation is what's executing, unless that passive explicitly opts in via
## PassiveEffect.triggers_hooks. Turn-level triggers (TECHNIQUE_USED, etc.)
## are unaffected either way -- those aren't wired inside apply_hit()/
## apply_status() at all, so a passive's operation can never reach them
## regardless of this flag.
func execute(user: Combatant, target: Combatant, trigger_hooks: bool = true) -> Array[Callable]:
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
						return apply_hit(user, target, step_group.numeric_bonuses, trigger_hooks)
					steps.append(step)

				elif action is StatusApplicationAction:
					var step = func() -> String:
						return apply_status(user, target, action, step_group.numeric_bonuses, trigger_hooks)
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

func apply_hit(user: Combatant, target: Combatant, numeric_bonuses: Array[NumericBonus], trigger_hooks: bool = true) -> String:
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

		if trigger_hooks:
			var attack_message: String = user.trigger_on_attack()
			if attack_message != "":
				message += " " if message != "" else ""
				message += attack_message

			var hit_message: String = target.trigger_on_hit(user)
			if hit_message != "":
				message += " " if message != "" else ""
				message += hit_message

			# Scoped to direct technique hits only, same as HIT/ATTACK -- not
			# take_damage() generically, since DoT ticks have no real
			# "dealer" to attribute DAMAGE_DEALT/DAMAGE_TAKEN to.
			var damage_message: String = Combatant._combine_messages([
				user.check_passives(PassiveEffect.Trigger.DAMAGE_DEALT, user),
				target.check_passives(PassiveEffect.Trigger.DAMAGE_TAKEN, target),
			])
			if damage_message != "":
				message += " " if message != "" else ""
				message += damage_message

	return message

func apply_status(user: Combatant, target: Combatant, status_application: StatusApplicationAction, numeric_bonuses: Array[NumericBonus], trigger_hooks: bool = true) -> String:
	if status_application.target == StatusApplicationAction.Target.TARGET and target.is_defeated():
		return ""

	var message: String = ""

	var status_target: Combatant = user if status_application.target == StatusApplicationAction.Target.SELF else target
	var opponent: Combatant = target if status_target == user else user

	# Path B (PassiveEffect.stack_bonus_*): runs unconditionally, unlike the
	# STATUS_APPLIED notification below -- it's a computation input like
	# numeric_bonuses, not a cascade, so it applies to every status
	# application regardless of trigger_hooks.
	var bonus_total: int = _sum_bonuses(numeric_bonuses, NumericBonus.ActionType.STATUS, user, target)
	bonus_total += status_target.passive_stack_bonus(status_application.effect, status_target)
	bonus_total += opponent.passive_stack_bonus(status_application.effect, status_target)

	var status: Status = Status.create(status_application.effect, status_application.stacks + bonus_total)

	if status:
		status_target.pre_application_snapshot = status_target.snapshot_statuses()
		var add_result: Dictionary = status_target.add_status(status)
		var reapply_message: String = add_result.message
		if reapply_message != "":
			message += " " if message != "" else ""
			message += reapply_message
		else:
			message += "%spplied %d stack%s of %s." % [
				" Also a" if message != "" else "A",
				status.stacks, "s" if status.stacks != 1 else "",
				String(status.status_id()).capitalize()
			]

		if trigger_hooks:
			# STATUS_APPLIED is inclusive (fresh or merged); STATUS_CREATED
			# fires additionally, as the more exclusive subset, only when
			# add_status() reports a genuinely new status -- same
			# inclusive/exclusive relationship STATUS_REDUCED/STATUS_REMOVED
			# already have for the opposite direction.
			var triggers: Array[PassiveEffect.Trigger] = [PassiveEffect.Trigger.STATUS_APPLIED]
			if add_result.created:
				triggers.append(PassiveEffect.Trigger.STATUS_CREATED)

			var passive_messages: Array[String] = []
			for trigger in triggers:
				passive_messages.append(status_target.check_passives(trigger, status_target))
				passive_messages.append(opponent.check_passives(trigger, status_target))

			var passive_message: String = Combatant._combine_messages(passive_messages)
			if passive_message != "":
				message += " " if message != "" else ""
				message += passive_message

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
	bonus_total += user.passive_heal_bonus(user)
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
				group_parts.append(_status_application_phrase(action, step_group.numeric_bonuses, status_bonus))

			elif action is ModifyStatusAction:
				group_parts.append(_modify_status_phrase(action))

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

## Summarizes whichever of a group's bonuses are tagged for one action type,
## as a trailing fragment ("" when there are none). Delegates each bonus's
## own fragment to NumericBonus.describe_bonus(), which subclasses override
## to describe how they scale the base flat/percent amount (e.g.
## StackCountNumericBonus adding "for each X stack on..."), rather than
## branching per subclass here.
func _bonus_summary(bonuses: Array[NumericBonus], action_type: NumericBonus.ActionType) -> String:
	var fragments: Array[String] = []

	for bonus in bonuses:
		if bonus.applies_to != action_type:
			continue

		var fragment: String = bonus.describe_bonus()
		if fragment != "":
			fragments.append(fragment)

	if fragments.is_empty():
		return ""

	# Leading ", " rather than a bare space -- a multiplicative fragment
	# (StackCount/StackComparison's "times (...)") only multiplies its own
	# bonus amount, not the base damage/heal/stacks that came before it, and
	# a bare space made that easy to misread as one continuous expression.
	return ", " + " ".join(fragments)

## Normally "applies N Status to X[, bonus clause]" -- but when stacks is
## authored as 0, the count comes entirely from a numeric_bonus (e.g.
## Sticky Residue's self-Absorption, scaled purely off the target's status
## stacks), and "applies 0 Status to self, +1 for each..." would misleadingly
## read as a separate 0 base plus a bonus rather than one combined amount.
## In that case the first usable bonus's own lead ("+1") takes the position
## the count normally holds, with its qualifier following directly instead
## of trailing the whole sentence. Only decomposes bonuses that split
## cleanly into lead+qualifier; a bonus that overrides describe_bonus()
## directly instead (StatComparisonNumericBonus) would only contribute its
## lead here, not its always-on difference term -- not a concern for any
## currently-authored content, but worth knowing if that combination ever
## gets authored.
func _status_application_phrase(action: StatusApplicationAction, numeric_bonuses: Array[NumericBonus], status_bonus: String) -> String:
	var whose: String = "self" if action.target == StatusApplicationAction.Target.SELF else "target"
	var status_text: String = Status.status_link(action.effect)

	if action.stacks == 0:
		for bonus in numeric_bonuses:
			if bonus.applies_to != NumericBonus.ActionType.STATUS:
				continue

			var lead: String = bonus.describe_lead()
			if lead == "":
				continue

			var qualifier: String = bonus.describe_qualifier()
			if qualifier == "":
				return "applies %s %s to %s" % [lead, status_text, whose]
			return "applies %s %s to %s %s" % [lead, status_text, whose, qualifier]

	return "applies %d %s to %s%s" % [action.stacks, status_text, whose, status_bonus]

func _modify_status_phrase(action: ModifyStatusAction) -> String:
	var is_self: bool = action.target == ModifyStatusAction.Target.SELF
	var possessive: String = "its own" if is_self else "target's"
	var object_form: String = "itself" if is_self else "the target"
	var status_text: String = Status.status_link(action.effect)

	match action.operator:
		ModifyStatusAction.Operator.MULTIPLY:
			return "multiplies %s current %s stacks by %s" % [possessive, status_text, action.modifier]
		ModifyStatusAction.Operator.DIVIDE:
			return "divides %s current %s stacks by %s" % [possessive, status_text, action.modifier]
		ModifyStatusAction.Operator.SUBTRACT:
			return "removes %d %s stack%s from %s" % [
				int(action.modifier), status_text, "s" if int(action.modifier) != 1 else "", object_form
			]
		ModifyStatusAction.Operator.SET:
			return "sets %s %s stacks to %d" % [possessive, status_text, int(action.modifier)]

	return "changes %s %s stacks" % [possessive, status_text]