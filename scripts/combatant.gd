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

## Set once per battle by battle_controller right after both Combatants
## exist (never re-derived), so any method here can reach "the other side"
## without a parameter threaded through every call site -- needed for
## STATUS_REDUCED/STATUS_REMOVED, whose stack mutations happen from several
## different places that don't otherwise have an opponent in scope. Safe to
## hold a plain reference (not a WeakRef): Combatant is RefCounted, and both
## sides get replaced together every battle, so there's no window where one
## side's opponent field could outlive and point at a stale instance.
var opponent: Combatant = null

var _passive_fire_counts: Dictionary[PassiveEffect, int] = {}
# var first_act_override: bool = false

## Stasis redirects a status's reduction into itself at most once per
## status per turn (keyed by Status.status_id()) -- guards against a
## reduction that wakes a passive whose own effect lands back on that
## same status, which would otherwise have no exit short of Stasis
## running out. See Status.stacks's own setter for the full mechanism.
## Not underscore-prefixed since Status (a different class) needs to
## read and set it on its owner; reset once per turn alongside
## _passive_fire_counts, in reset_turn_passive_limits().
var stasis_redirect_used_this_turn: Dictionary[StringName, bool] = {}

## Populated by Technique.apply_status() immediately before add_status()
## runs, mapping each currently-active status's id to its stacks as they
## were right before this application. StatusPresentBeforeApplicationCondition
## reads from this instead of live state, so a passive can correctly answer
## "did I already have this status" without being fooled by the very
## application that's about to land (a plain StatusComparisonCondition
## checked post-application can't tell "already had it" apart from "just
## gained it via this exact event," since by the time any STATUS_APPLIED/
## STATUS_CREATED passive is checked, add_status() has already run). Only
## meaningful for the instant right after being set -- stale or empty
## anywhere else, so this snapshot (and the condition that reads it) is
## only appropriate inside a PassiveEffect triggered by STATUS_APPLIED/
## STATUS_CREATED, never in a PriorityRule's conditions or similar, which
## are checked well outside any status application.
var pre_application_snapshot: Dictionary = {}

func snapshot_statuses() -> Dictionary:
	var snapshot: Dictionary = {}
	for status in statuses:
		snapshot[status.status_id()] = status.stacks
	return snapshot

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
		var absorption_stacks_before: int = absorption.stacks
		var absorbed: int = min(absorption.stacks, amount)
		absorption.stacks -= absorbed
		amount -= absorbed
		_settle_status(absorption, absorption_stacks_before)

	current_hp = max(current_hp - amount, 0)
	return amount

## Returns the amount actually added to current_hp, capped by max_hp -- same
## reasoning as take_damage()'s return value, so callers logging a heal
## message don't overstate one that was partially wasted overhealing.
func heal(amount: int) -> int:
	var actual: int = min(amount, familiar.max_hp - current_hp)
	current_hp += actual
	return actual

func is_defeated() -> bool:
	return current_hp <= 0

## Re-applying an already-active status merges into it instead of tracking a
## second instance: on_reapply() runs first, then on_applied() -- skipped if
## on_reapply() already left it expired -- and either path removes it once
## it's expired. Returns {"message": String, "created": bool} -- created is
## true only for a genuinely fresh application (no merge, and not fully
## absorbed by Ward), letting Technique.apply_status() distinguish
## STATUS_CREATED (the exclusive "brand new" case) from STATUS_APPLIED (the
## inclusive "applied at all, fresh or merged" case) the same way
## STATUS_REDUCED/STATUS_REMOVED already distinguish the opposite direction.
## is_self_applied is true when whoever is receiving new_status is the same
## combatant who chose to apply it (a technique/passive targeting SELF) --
## Ward only screens out effects imposed by someone else, not stacks a
## combatant is voluntarily giving itself, so it never eats a self-buff
## like Pebbloq's own Chronoparry/Sentinel Strike applications.
func add_status(new_status: Status, is_self_applied: bool = false) -> Dictionary:
	var absorb_message: String = ""
	var ward: Status = get_status(Status.StatusEffect.WARD)

	if ward != null and not is_self_applied and new_status.status_id() != Status.status_effect_id(Status.StatusEffect.WARD):
		var absorbed: int = min(ward.stacks, new_status.stacks)
		if absorbed > 0:
			var ward_stacks_before: int = ward.stacks
			ward.stacks -= absorbed
			new_status.stacks -= absorbed
			absorb_message = "%s's ward absorbs %d stack%s of %s!" % [
				familiar.familiar_name, absorbed, "s" if absorbed != 1 else "", String(new_status.status_id()).capitalize()
			]
			absorb_message = _combine_messages([absorb_message, _settle_status(ward, ward_stacks_before)])

	if new_status.stacks <= 0:
		return {"message": absorb_message, "created": false}  # fully absorbed -- nothing left to apply

	for existing in statuses:
		if existing.status_id() == new_status.status_id():
			apply_passive_field_bonuses(existing)
			var stacks_before: int = existing.stacks
			var reapply_message: String = existing.on_reapply(self)
			existing.stack_with(new_status)
			var settle_message: String = _combine_messages([reapply_message, absorb_message, _settle_status(existing, stacks_before)])
			return {"message": _combine_messages([settle_message, trigger_on_status_applied(existing)]), "created": false}

	statuses.append(new_status)
	new_status.owner = self
	apply_passive_field_bonuses(new_status)
	var appended_message: String = _combine_messages([absorb_message, _settle_status(new_status, new_status.stacks)])
	return {"message": _combine_messages([appended_message, trigger_on_status_applied(new_status)]), "created": true}

## ModifyStatusPassiveEffect's field_name/field_bonus (see PassiveEffect) --
## called from add_status() itself, on whichever Status instance is about
## to actually survive (existing on a merge, the freshly-appended one
## otherwise), before on_reapply()/on_applied() run so a status that reads
## its own field mid-reapply (e.g. Burn's flare reading flare_damage) sees
## the bonus already applied. Checks both this combatant's own passives and
## opponent's, mirroring passive_stack_bonus()'s two-sided check.
func apply_passive_field_bonuses(status: Status) -> void:
	var candidates: Array[Combatant] = [self]
	if opponent != null:
		candidates.append(opponent)

	for candidate in candidates:
		for passive in candidate._matching_passives(PassiveEffect.Trigger.STATUS_APPLIED, self):
			if not (passive is ModifyStatusPassiveEffect) or passive.field_name == &"":
				continue
			if Status.status_effect_id(passive.status_effect) != status.status_id():
				continue

			status.set(passive.field_name, status.get(passive.field_name) + passive.field_bonus)
			candidate._record_passive_fire(passive)

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
			var stacks_before: int = existing.stacks
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

			return _combine_messages([reapply_message, _settle_status(existing, stacks_before)])

	if operator == ModifyStatusAction.Operator.SET and modifier > 0:
		var new_status: Status = Status.create(effect, int(modifier))
		statuses.append(new_status)
		new_status.owner = self
		return _settle_status(new_status, new_status.stacks)
	else:
		return ""

## Halves every active status's stacks (integer division, so a 1-stack status
## is removed entirely) -- Reclaim Byproducts' "cut all status stacks in
## half" effect. Settled through the same _settle_status() choke point every
## other stack decrease uses, so STATUS_REDUCED/REMOVED passives fire
## correctly for each status actually reduced, and Stasis's own "stacks would
## be removed from something else? take it from me instead" interception
## (Status.stacks's setter) applies transparently, same as any other decrease.
func halve_all_statuses() -> String:
	var messages: Array[String] = []
	for status in statuses.duplicate():
		var stacks_before: int = status.stacks
		status.stacks = int(status.stacks / 2.0)
		messages.append(_settle_status(status, stacks_before))
	return _combine_messages(messages)

## Fires on_hit() on every active status, mirroring how run_upkeep() fires
## on_tick(). attacker is whoever dealt the hit, passed through for statuses
## like Thorns that retaliate against them. Returns every triggered message
## joined together, or "" if nothing had anything to say.
func trigger_on_hit(attacker: Combatant) -> String:
	var message: String = ""

	for status in statuses.duplicate():
		var stacks_before: int = status.stacks
		var hp_before: int = current_hp
		message = _combine_messages([message, status.on_hit(self, attacker)])
		message = _combine_messages([message, _notify_stack_change(status, stacks_before)])

		if current_hp > hp_before:
			message = _combine_messages([message, check_passives(PassiveEffect.Trigger.HEALED, self)])

		if status.is_expired():
			statuses.erase(status)

	message = _combine_messages([message, check_passives(PassiveEffect.Trigger.HIT, self)])

	return message

## Fires on_attack() on every active status, mirroring trigger_on_hit().
func trigger_on_attack() -> String:
	var message: String = ""

	for status in statuses.duplicate():
		var stacks_before: int = status.stacks
		message = _combine_messages([message, status.on_attack(self)])
		message = _combine_messages([message, _notify_stack_change(status, stacks_before)])
		if status.is_expired():
			statuses.erase(status)

	message = _combine_messages([message, check_passives(PassiveEffect.Trigger.ATTACK, self)])

	return message

func trigger_on_status_applied(applied_status: Status) -> String:
	var message: String = ""
	for status in statuses.duplicate():
		var stacks_before: int = status.stacks
		message = _combine_messages([message, status.on_status_applied(self, applied_status)])
		message = _combine_messages([message, _notify_stack_change(status, stacks_before)])
		if status.is_expired():
			statuses.erase(status)

	return message

func effective_stat(stat: Familiar.Stat) -> int:
	var base_value: int = familiar.get_stat(stat)

	for status in statuses:
		base_value = status.modify_stat(stat, base_value)

	var candidates: Array[PassiveEffect] = familiar.passives.duplicate()
	if familiar.focus_table != null:
		candidates.append_array(familiar.focus_table.effects)

	for passive in candidates:
		if passive is ModifyStatPassiveEffect and passive.stat == stat:
			base_value += passive.flat_bonus

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
## stacks_before is whatever the status's stacks were immediately before
## whatever mutation the caller just made (a fresh application should pass
## its own post-creation stacks, since there's no real "before" to compare
## against) -- forwarded to _notify_stack_change() so STATUS_REDUCED/REMOVED
## can fire from this one shared settling point.
func _settle_status(status: Status, stacks_before: int) -> String:
	var message: String = "" if status.is_expired() else status.on_applied(self)
	if status.is_expired():
		statuses.erase(status)
	return _combine_messages([message, _notify_stack_change(status, stacks_before)])

## Fires STATUS_REDUCED whenever a status's stacks have dropped, checked
## against both this combatant's own passives and opponent's -- REDUCED is
## the inclusive case (any decrease, whether or not the status survives it).
## STATUS_REMOVED fires *additionally*, as the more exclusive subset, when
## the decrease also fully expires the status -- a passive that only cares
## about "any decrease" listens to REDUCED alone and sees full depletions
## too; one that cares specifically about "gone entirely" listens to
## REMOVED. Called from every place stacks can decrease -- _settle_status(),
## and directly from trigger_on_hit()/trigger_on_attack()/
## trigger_on_status_applied() (whose own on_hit()/on_attack()/
## on_status_applied() calls can reduce a status internally, e.g. a
## self-consuming counter) -- rather than only where erasure happens, so a
## reduction that doesn't fully expire a status is still seen. A no-op if
## stacks didn't actually go down, or before opponent is set (shouldn't
## happen mid-battle, but guards throwaway/test Combatants).
func _notify_stack_change(status: Status, stacks_before: int) -> String:
	if opponent == null or status.stacks >= stacks_before:
		return ""

	var messages: Array[String] = [
		check_passives(PassiveEffect.Trigger.STATUS_REDUCED, self, status),
		opponent.check_passives(PassiveEffect.Trigger.STATUS_REDUCED, self, status),
	]

	if status.is_expired():
		messages.append(check_passives(PassiveEffect.Trigger.STATUS_REMOVED, self, status))
		messages.append(opponent.check_passives(PassiveEffect.Trigger.STATUS_REMOVED, self, status))

	return _combine_messages(messages)

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

func has_first_act_override() -> bool:
	# if first_act_override:
	# 	return true

	for status in statuses:
		if status.grants_first_act_override():
			return true

	return false

## Checks every passive this combatant owns (its own passives plus its
## focus_table's) against one fired trigger, running and logging whichever
## ones match -- OperationPassiveEffect and PermanentStatPassiveEffect only;
## ModifyStatusPassiveEffect is a query (see passive_stack_bonus()), not a
## reaction, so it's never matched here. affected is who the event concerns
## (e.g. who a status was just applied to) -- opponent is always read from
## this combatant's own opponent field, since every caller was already
## passing exactly that value. relevant_status is the specific Status this
## event concerns, when there is one (STATUS_APPLIED/CREATED/REDUCED/REMOVED)
## -- lets a passive's status_effect_filter react to one status by name (e.g.
## "when Recharge is removed, gain Enlarge") instead of matching every status
## that hits the same trigger. Left null for triggers with no specific status
## (BATTLE_START, HIT, TURN_START, ...), where a filter simply never matches.
func check_passives(trigger: PassiveEffect.Trigger, affected: Combatant, relevant_status: Status = null) -> String:
	var message: String = ""

	for passive in _matching_passives(trigger, affected, relevant_status):
		if not (passive is OperationPassiveEffect or passive is PermanentStatPassiveEffect):
			continue

		# Recorded before firing, not after -- passive.operation can itself
		# cascade back into this same trigger (e.g. an OperationPassiveEffect
		# with triggers_hooks = true whose own trigger is STATUS_APPLIED,
		# applying a status). Recording afterward left a window where the
		# limiter hadn't caught up yet, so the passive could match itself
		# again inside its own cascade -- unbounded recursion instead of a
		# single fire.
		_record_passive_fire(passive)

		var fired_message: String = ""
		if passive is OperationPassiveEffect:
			fired_message = _fire_operation(passive)
		else:
			fired_message = _fire_stat_passive(passive)

		message = _combine_messages([message, fired_message])

	return message

## ModifyStatusPassiveEffect (see PassiveEffect) -- consulted by
## Technique.apply_status() before Status.create() runs, so the bonus is
## baked into the stack count of the application currently resolving
## instead of bolted on afterward. Runs unconditionally (not gated by
## OperationPassiveEffect.triggers_hooks): this is a computation input like
## NumericBonus, not a cascade/notification.
func passive_stack_bonus(status_effect: Status.StatusEffect, affected: Combatant) -> int:
	var total: int = 0

	for passive in _matching_passives(PassiveEffect.Trigger.STATUS_APPLIED, affected):
		if not (passive is ModifyStatusPassiveEffect) or passive.status_effect != status_effect:
			continue

		total += passive.stack_bonus
		_record_passive_fire(passive)

	return total

## ModifyHealPassiveEffect (see PassiveEffect) -- consulted by
## Technique.apply_heal() before the heal amount is finalized, the same way
## passive_stack_bonus() feeds apply_status(). Runs unconditionally, not
## gated by OperationPassiveEffect.triggers_hooks. Queries the HEALED trigger
## like check_passives() does for reactive passives, but filtered to
## ModifyHealPassiveEffect specifically -- the two never overlap.
func passive_heal_bonus(affected: Combatant) -> int:
	var total: int = 0

	for passive in _matching_passives(PassiveEffect.Trigger.HEALED, affected):
		if not (passive is ModifyHealPassiveEffect):
			continue

		total += passive.heal_bonus
		_record_passive_fire(passive)

	return total

## Shared trigger/target/conditions/limiter filtering for check_passives(),
## passive_stack_bonus(), and passive_heal_bonus() -- affected is who the event
## concerns (e.g. who a status was just applied to); trigger_target compares
## against this combatant's own opponent, not affected, since a
## TARGET-scoped passive means "watching MY opponent's events," not
## "watching whoever happened to be affected." relevant_status is the specific
## Status the event concerns, when there is one -- see check_passives(). Does
## not distinguish which PassiveEffect subclass a match is -- callers filter
## for the payload kind(s) they handle.
func _matching_passives(trigger: PassiveEffect.Trigger, affected: Combatant, relevant_status: Status = null) -> Array[PassiveEffect]:
	var matches: Array[PassiveEffect] = []

	var candidates: Array[PassiveEffect] = familiar.passives.duplicate()
	if familiar.focus_table != null:
		candidates.append_array(familiar.focus_table.effects)

	for passive in candidates:
		if passive.trigger != trigger:
			continue

		var event_combatant: Combatant = self if passive.trigger_target == PassiveEffect.Target.SELF else opponent
		if event_combatant != affected:
			continue

		if passive.status_effect_filter != Status.StatusEffect.NONE:
			if relevant_status == null or relevant_status.status_id() != Status.status_effect_id(passive.status_effect_filter):
				continue

		var failed_condition: Condition = null
		for condition in passive.conditions:
			if not condition.is_met(self, opponent):
				failed_condition = condition
				break
		if failed_condition != null:
			continue

		if not _passive_limiter_allows(passive):
			continue

		matches.append(passive)

	return matches

func _passive_limiter_allows(passive: PassiveEffect) -> bool:
	if passive.limiter == PassiveEffect.Limiter.NONE:
		return true
	return _passive_fire_counts.get(passive, 0) == 0

func _record_passive_fire(passive: PassiveEffect) -> void:
	_passive_fire_counts[passive] = _passive_fire_counts.get(passive, 0) + 1

## Clears ONCE_PER_TURN/ONCE_PER_TECHNIQUE limits at the start of this
## combatant's own turn -- called from battle_controller.take_turn(). The
## two limiters behave identically today since a turn is always exactly one
## technique's execution; they'll only diverge once something makes that
## no longer true.
func reset_turn_passive_limits() -> void:
	for passive in _passive_fire_counts.keys().duplicate():
		if passive.limiter == PassiveEffect.Limiter.ONCE_PER_TURN or passive.limiter == PassiveEffect.Limiter.ONCE_PER_TECHNIQUE:
			_passive_fire_counts.erase(passive)
	stasis_redirect_used_this_turn.clear()

## Runs a matched OperationPassiveEffect's Technique against (self, opponent)
## and joins whatever messages its steps produce, the same way take_turn()
## would for an ordinary technique -- just without take_turn()'s per-step
## pacing, since a passive's operation is a reaction, not the turn itself.
func _fire_operation(passive: OperationPassiveEffect) -> String:
	if passive.operation == null:
		return ""

	var steps: Array[Callable] = passive.operation.execute(self, opponent, passive.triggers_hooks)
	var messages: Array[String] = []
	for step in steps:
		var step_message: String = step.call()
		if step_message != "":
			messages.append(step_message)

	return " ".join(messages)

## Applies a matched PermanentStatPassiveEffect's stat change directly to
## familiar -- the same Familiar resource object that carries forward
## across the whole run (Combatant is recreated fresh each battle, familiar
## is not), so this persists the same way a picked stat upgrade does.
func _fire_stat_passive(passive: PermanentStatPassiveEffect) -> String:
	if passive.stat_change == null:
		return ""

	passive.stat_change.apply(familiar)
	return "%s's passive triggers: %s." % [familiar.familiar_name, passive.stat_change.describe()]
