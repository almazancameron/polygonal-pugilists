class_name Combatant
extends RefCounted

## Per-battle runtime state for one side of a fight. Wraps a Familiar's
## static stats with the things that change during combat (current_hp,
## is_stunned, statuses). Created fresh each battle, never saved or edited
## directly.

var familiar: Familiar
var current_hp: int
var is_stunned: bool = false
var statuses: Array[Status] = []

func _init(f: Familiar) -> void:
	familiar = f
	current_hp = f.max_hp

## Returns the amount actually subtracted from current_hp, after
## modify_incoming_damage() (Ruin) and Absorption have had their say --
## callers should build their log messages from this return value, not
## whatever amount they originally passed in, or Ruin/Absorption's effects
## won't show up in the log at all.
func take_damage(amount: int) -> int:
	for status in statuses:
		amount = status.modify_incoming_damage(amount)

	var absorption: Status = get_status(Status.StatusEffect.ABSORPTION)
	if absorption != null:
		var absorbed: int = min(absorption.stacks, amount)
		absorption.stacks -= absorbed
		amount -= absorbed
		_settle_status(absorption)

	current_hp = max(current_hp - amount, 0)
	return amount

func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, familiar.max_hp)

func is_defeated() -> bool:
	return current_hp <= 0

## Re-applying an already-active status merges into it instead of tracking a
## second instance: on_reapply() runs first, then on_applied() -- skipped if
## on_reapply() already left it expired -- and either path removes it once
## it's expired. Returns their combined message, or "" if nothing happened.
func add_status(new_status: Status) -> String:
	var absorb_message: String = ""
	var ward: Status = get_status(Status.StatusEffect.WARD)

	if ward != null and new_status.status_id() != Status.status_effect_id(Status.StatusEffect.WARD):
		var absorbed: int = min(ward.stacks, new_status.stacks)
		if absorbed > 0:
			ward.stacks -= absorbed
			new_status.stacks -= absorbed
			absorb_message = "%s's ward absorbs %d stack%s of %s!" % [
				familiar.familiar_name, absorbed, "s" if absorbed != 1 else "", String(new_status.status_id()).capitalize()
			]
			absorb_message = _combine_messages([absorb_message, _settle_status(ward)])

	if new_status.stacks <= 0:
		return absorb_message  # fully absorbed -- nothing left to apply

	for existing in statuses:
		if existing.status_id() == new_status.status_id():
			var reapply_message: String = existing.on_reapply(self)
			existing.stack_with(new_status)
			var settle_message: String = _combine_messages([reapply_message, absorb_message, _settle_status(existing)])
			return _combine_messages([settle_message, trigger_on_status_applied(existing)])

	statuses.append(new_status)
	var appended_message: String = _combine_messages([absorb_message, _settle_status(new_status)])
	return _combine_messages([appended_message, trigger_on_status_applied(new_status)])

## Adjusts an already-existing status's stacks directly (SUBTRACT/DIVIDE/SET/
## MULTIPLY) -- not a reapplication, but on_reapply() still fires if the net
## result is a stack *increase* (e.g. SET to a higher value, or DIVIDE by a
## fraction below 1), the same way a real reapplication would trigger things
## like Burn's flare. Checked against the prospective result before mutating
## stacks, so on_reapply() sees the pre-change count just like it does via
## add_status() -- not the already-adjusted value.
func modify_status_stacks(effect: Status.StatusEffect, modifier: float, operator: ModifyStatusAction.Operator) -> String:
	for existing in statuses:
		if existing.status_id() == Status.status_effect_id(effect):
			var new_stacks: int = existing.stacks
			match operator:
				ModifyStatusAction.Operator.MULTIPLY:
					new_stacks = int(existing.stacks * modifier)
				ModifyStatusAction.Operator.SUBTRACT:
					new_stacks = existing.stacks - int(modifier)
				ModifyStatusAction.Operator.DIVIDE:
					new_stacks = int(existing.stacks / modifier)
				ModifyStatusAction.Operator.SET:
					new_stacks = int(modifier)
			
			var reapply_message: String = ""
			if new_stacks > existing.stacks:
				reapply_message = existing.on_reapply(self)

			existing.stacks = new_stacks
			if existing.max_stacks() >= 0:
				existing.stacks = min(existing.stacks, existing.max_stacks())

			return _combine_messages([reapply_message, _settle_status(existing)])

	if operator == ModifyStatusAction.Operator.SET and modifier > 0:
		var new_status: Status = Status.create(effect, int(modifier))
		statuses.append(new_status)
		return _settle_status(new_status)
	else:
		return ""

## Fires on_hit() on every active status, mirroring how run_upkeep() fires
## on_tick(). attacker is whoever dealt the hit, passed through for statuses
## like Thorns that retaliate against them. Returns every triggered message
## joined together, or "" if nothing had anything to say.
func trigger_on_hit(attacker: Combatant) -> String:
	var message: String = ""

	for status in statuses.duplicate():
		message = _combine_messages([message, status.on_hit(self, attacker)])
		if status.is_expired():
			statuses.erase(status)

	return message

## Fires on_attack() on every active status, mirroring trigger_on_hit().
func trigger_on_attack() -> String:
	var message: String = ""

	for status in statuses.duplicate():
		message = _combine_messages([message, status.on_attack(self)])
		if status.is_expired():
			statuses.erase(status)

	return message

func trigger_on_status_applied(applied_status: Status) -> String:
	var message: String = ""
	for status in statuses.duplicate():
		message = _combine_messages([message, status.on_status_applied(self, applied_status)])
		if status.is_expired():
			statuses.erase(status)

	return message

func effective_stat(stat: Familiar.Stat) -> int:
	var base_value: int = familiar.get_stat(stat)

	for status in statuses:
		base_value = status.modify_stat(stat, base_value)

	return base_value

func effective_defense() -> int:
	return effective_stat(Familiar.Stat.DEFENSE)

func effective_power() -> int:
	return effective_stat(Familiar.Stat.POWER)

## Evaluates familiar.priority_rules in order and returns the first rule
## whose conditions all hold, plus a skip reason for every rule passed over
## along the way -- the caller logs those to explain the choice, per
## GAME_DESIGN.md's "every skip needs a visible reason" requirement.
## Expects the rule list to end with an unconditional catch-all rule (an
## empty conditions array is vacuously true); if none matches, "technique"
## comes back null rather than guessing.
func choose_technique(target: Combatant) -> Dictionary:
	var skip_reasons: Array[String] = []

	for rule in familiar.priority_rules:
		var failed_condition: Condition = null
		for condition in rule.conditions:
			if not condition.is_met(self, target):
				failed_condition = condition
				break

		if failed_condition == null:
			return {"technique": rule.technique, "skip_reasons": skip_reasons}

		skip_reasons.append("%s skipped (condition not met: %s)" % [rule.technique.technique_name, failed_condition.describe()])

	return {"technique": null, "skip_reasons": skip_reasons}

## Runs on_applied() unless the status is already expired, then removes it
## from statuses if it's expired either way -- before or after on_applied().
func _settle_status(status: Status) -> String:
	var message: String = "" if status.is_expired() else status.on_applied(self)
	if status.is_expired():
		statuses.erase(status)
	return message

static func _combine_messages(messages: Array[String]) -> String:
	var filtered: Array[String] = []
	for message in messages:
		if message != "":
			filtered.append(message)

	return " ".join(filtered)

func has_status(effect: Status.StatusEffect) -> bool:
	var id: StringName = Status.status_effect_id(effect)
	for status in statuses:
		if status.status_id() == id:
			return true
	return false

func get_status(effect: Status.StatusEffect) -> Status:
	var id: StringName = Status.status_effect_id(effect)
	for status in statuses:
		if status.status_id() == id:
			return status
	return null
