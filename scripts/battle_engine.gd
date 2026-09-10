class_name BattleEngine
extends RefCounted

## Scene-independent battle sequencing: turn order, upkeep ticking, and technique
## resolution for one 1v1 fight between two Combatants. Extracted out of
## battle_controller.gd so the same rules can be driven headlessly (see
## scripts/tools/balance_test.gd) instead of only from inside battle.tscn.
##
## Deliberately owns *only* sequencing -- no CombatLog, no HPBar, no
## `await get_tree().create_timer(...)` anywhere in this file. battle_controller.gd
## calls into these methods for the logic and still owns presentation/pacing itself
## (it needs per-step pacing a headless harness has no use for) plus bracket/meta
## concerns (round advance, quitting) that only make sense for a live run, not a
## single simulated fight.

var player: Combatant
var enemy: Combatant

## Who opens the exchange currently in progress -- re-decided by
## determine_first_actor() every time an exchange completes (see advance_turn()),
## not just once per fight, so a mid-fight Speed swing can hand one side two turns
## in a row. Set by begin_battle().
var current_first_actor: Combatant

## Set by check_victory() once either side is defeated; null until then.
var winner: Combatant = null

## Populated by check_victory() alongside winner -- kept as two separate fields
## (rather than folded into check_victory()'s bool return) since the two sides'
## BATTLE_END messages need distinct CombatLog sources in the live UI, the same
## reason begin_battle() below splits its own two messages into two fields too.
var battle_end_player_message: String = ""
var battle_end_enemy_message: String = ""

## Populated by begin_battle(), read once by battle_controller.gd right after
## calling it. Two fields rather than one merged return value/array, since the
## live UI logs the player's and enemy's BATTLE_START messages under different
## CombatLog sources -- the one place in this class two sides' messages can't
## just be flattened into a single Array[String] the way every other method's can
## (battle_controller.gd already knows which single source every other method's
## messages belong to, from which Combatant it passed in as the acting side).
var battle_start_player_message: String = ""
var battle_start_enemy_message: String = ""

## Skip reasons from the most recent take_turn() call. A separate field rather
## than folded into take_turn()'s return value, since whether to show them at all
## is a presentation choice (battle_controller.gd's show_priority_skip_log toggle),
## not part of the turn's actual outcome.
var last_skip_reasons: Array[String] = []

func _init(p: Combatant, e: Combatant) -> void:
	player = p
	enemy = e

func _other(combatant: Combatant) -> Combatant:
	return enemy if combatant == player else player

## Verbatim port of battle_controller.gd's old _determine_first_actor(). Kept
## generic over which argument is "player" so the round-robin harness can call it
## with either familiar in either slot -- the tiebreak below is the one place
## argument order changes the result, which is exactly what lets the harness test
## both sides of a Speed tie.
func determine_first_actor(a: Combatant, b: Combatant) -> Combatant:
	var a_override := a.has_first_act_override()
	var b_override := b.has_first_act_override()

	if a_override != b_override:
		return a if a_override else b

	var a_speed := a.effective_stat(Familiar.Stat.SPEED)
	var b_speed := b.effective_stat(Familiar.Stat.SPEED)

	if a_speed == b_speed:
		return a
	return a if a_speed > b_speed else b

## Fires BATTLE_START on both sides and decides who opens. No upkeep before this --
## both Combatants are freshly created with no statuses yet, same as before
## Speed-based ordering existed.
func begin_battle() -> void:
	battle_start_player_message = player.check_passives(PassiveEffect.Trigger.BATTLE_START, player)
	battle_start_enemy_message = enemy.check_passives(PassiveEffect.Trigger.BATTLE_START, enemy)

	current_first_actor = determine_first_actor(player, enemy)

## Ticks every active status on combatant once (upkeep), same ordering as the old
## run_upkeep(): on_tick() then _notify_stack_change(), erase if expired. Returns
## one entry per status *ticked*, not per message -- an entry can be "" when a
## status has nothing to say this turn, and the caller still has to treat that as
## one beat (update its display, pause) rather than skipping it, matching how the
## live UI paced every tick before this refactor regardless of whether it logged
## anything. Stops early (without erroring) if a tick defeats combatant, same as
## the original's mid-loop is_defeated() check.
func run_upkeep(combatant: Combatant) -> Array[String]:
	var messages: Array[String] = []

	if combatant.statuses.is_empty():
		return messages

	for status in combatant.statuses.duplicate():
		var stacks_before: int = status.stacks
		var hp_before: int = combatant.current_hp
		var message: String = Combatant._combine_messages([
			status.on_tick(combatant),
			combatant._notify_stack_change(status, stacks_before),
		])

		if combatant.current_hp > hp_before:
			message = Combatant._combine_messages([
				message, combatant.check_passives(PassiveEffect.Trigger.HEALED, combatant),
			])

		messages.append(message)

		if status.is_expired():
			combatant.statuses.erase(status)

		if combatant.is_defeated():
			break

	return messages

## Ports battle_controller.gd's old take_turn(), minus UI/pacing. Always finishes
## its work (stunned or not) and returns; the caller calls advance_turn(actor)
## next either way, same invariant the original had.
##
## Returns one entry per message, each `{"message": String, "paced": bool}` --
## "paced" is true only for technique-execution steps (hit/heal/status-apply),
## matching the original's own asymmetry: those had a 0.6s pause between them,
## while the surrounding TURN_START/TECHNIQUE_USED/TURN_END passive messages
## never did. A plain Array[String] can't carry that distinction, and dropping it
## would give the live UI an extra pause it never had before.
func take_turn(actor: Combatant, target: Combatant) -> Array[Dictionary]:
	last_skip_reasons = []
	var entries: Array[Dictionary] = []

	var turn_start_message: String = actor.check_passives(PassiveEffect.Trigger.TURN_START, actor)
	if turn_start_message != "":
		entries.append({"message": turn_start_message, "paced": false})

	if actor.is_stunned:
		actor.is_stunned = false
		entries.append({
			"message": "%s is stunned and skips its turn!" % actor.familiar.familiar_name,
			"paced": false,
		})
		return entries

	var decision: Dictionary = actor.choose_technique(target)
	last_skip_reasons = decision.skip_reasons
	var technique: Technique = decision.technique

	var technique_used_message: String = actor.check_passives(PassiveEffect.Trigger.TECHNIQUE_USED, actor)
	if technique_used_message != "":
		entries.append({"message": technique_used_message, "paced": false})

	var steps: Array[Callable] = technique.execute(actor, target)
	for step in steps:
		var step_message: String = step.call()
		if step_message != "":
			entries.append({"message": step_message, "paced": true})

	var turn_end_message: String = actor.check_passives(PassiveEffect.Trigger.TURN_END, actor)
	if turn_end_message != "":
		entries.append({"message": turn_end_message, "paced": false})

	return entries

## Exchange-completion logic ported from the old advance_turn(): the same actor
## keeps going until the exchange it opened completes, then determine_first_actor()
## re-runs -- which is what lets one side take two turns in a row on a mid-fight
## Speed swing. Deliberately does *not* touch passive-limit resets, upkeep, or the
## next take_turn() call -- those stay the caller's job (battle_controller.gd's own
## advance_turn() for the live UI, run_to_completion() below for the harness) so
## each can sequence pacing/looping its own way against one shared decision here.
func advance_turn(actor: Combatant) -> Combatant:
	if actor == current_first_actor:
		return _other(actor)

	current_first_actor = determine_first_actor(player, enemy)
	return current_first_actor

## Defeat-detection and BATTLE_END passive firing, ported from the old
## check_victory() minus the bracket-round-advance and get_tree().quit() branches
## -- those stay meta-progression concerns in battle_controller.gd, since
## BattleEngine only ever resolves one fight. Sets winner and the two BATTLE_END
## message fields when returning true; the caller must stop driving this battle
## once it does (calling this again on an already-decided pair would refire
## BATTLE_END passives a second time -- safe today only because every caller obeys
## that rule, same guard the original relied on).
func check_victory() -> bool:
	if not (enemy.is_defeated() or player.is_defeated()):
		return false

	battle_end_player_message = player.check_passives(PassiveEffect.Trigger.BATTLE_END, player)
	battle_end_enemy_message = enemy.check_passives(PassiveEffect.Trigger.BATTLE_END, enemy)

	winner = player if enemy.is_defeated() else enemy
	return true

## Convenience driver for the headless harness (not used by the live UI, which
## needs per-step pacing this deliberately skips): runs begin_battle(), then loops
## take_turn()/check_victory()/advance_turn()/run_upkeep() exactly the same order
## the live UI's recursive await chain used to, until check_victory() says the
## fight is over or max_turns is exceeded. max_turns is new behavior -- today's
## live game has no such guard -- but it's cheap insurance against a content-pass
## familiar whose priority rules have no true damaging fallback.
##
## track_history (off by default -- no caller needs the extra bookkeeping except
## a kit-diagnosis tool) makes the return value's "history" a per-entry timeline
## instead of an empty array: {turn, phase, acting_familiar, target_familiar,
## damage_dealt, player_hp, enemy_hp, messages}. Two kinds of entry, told apart
## by phase:
## - "turn": one per take_turn() call. damage_dealt is target's HP loss from
##   that specific technique (0 if the actor healed, the technique was
##   self-targeted, or a hit landed but was fully absorbed) -- not the actor's
##   own HP change, which already shows up in player_hp/enemy_hp (a retaliation
##   status can still cost the actor HP the same turn).
## - "upkeep": one per run_upkeep() call that actually ticked something.
##   acting_familiar and target_familiar are the same combatant (this is
##   self-damage from its own statuses, e.g. Poison/Burn/Foretell), and
##   damage_dealt is its total HP loss across that whole upkeep phase. Without
##   this, a combatant dying to sustained DoT looks identical in the history to
##   one that was simply never hit -- exactly backwards for diagnosing whether
##   a kit's problem is damage output or survivability.
## messages is the real combat-log text for the entry (same strings the live UI
## would show) -- damage_dealt alone can't tell "the fallback technique fired"
## apart from "the real technique fired but did nothing after Absorption,"
## since both show up as 0; the messages make that distinction visible.
## Reusable across any two-familiar matchup, not specific to the round-robin --
## see scripts/tools/diagnose_matchup.gd.
func run_to_completion(max_turns: int = 1000, track_history: bool = false) -> Dictionary:
	begin_battle()

	var actor: Combatant = current_first_actor
	var turns: int = 0
	var history: Array[Dictionary] = []

	while turns < max_turns:
		var target: Combatant = _other(actor)
		var target_hp_before: int = target.current_hp

		var entries: Array[Dictionary] = take_turn(actor, target)
		turns += 1

		if track_history:
			var messages: Array[String] = []
			for entry in entries:
				messages.append(entry.message)

			history.append({
				"turn": turns,
				"phase": "turn",
				"acting_familiar": actor.familiar.familiar_name,
				"target_familiar": target.familiar.familiar_name,
				"damage_dealt": max(target_hp_before - target.current_hp, 0),
				"player_hp": player.current_hp,
				"enemy_hp": enemy.current_hp,
				"messages": messages,
			})

		if check_victory():
			return {"winner": winner, "turns": turns, "stalemate": false, "history": history}

		var next_actor: Combatant = advance_turn(actor)
		next_actor.reset_turn_passive_limits()

		var upkeep_hp_before: int = next_actor.current_hp
		var upkeep_entries: Array[String] = run_upkeep(next_actor)

		if track_history and not upkeep_entries.is_empty():
			var upkeep_messages: Array[String] = []
			for message in upkeep_entries:
				if message != "":
					upkeep_messages.append(message)

			history.append({
				"turn": turns,
				"phase": "upkeep",
				"acting_familiar": next_actor.familiar.familiar_name,
				"target_familiar": next_actor.familiar.familiar_name,
				"damage_dealt": max(upkeep_hp_before - next_actor.current_hp, 0),
				"player_hp": player.current_hp,
				"enemy_hp": enemy.current_hp,
				"messages": upkeep_messages,
			})

		if check_victory():
			return {"winner": winner, "turns": turns, "stalemate": false, "history": history}

		actor = next_actor

	return {"winner": null, "turns": turns, "stalemate": true, "history": history}
