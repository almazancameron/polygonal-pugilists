class_name PassiveEffect
extends Resource

## Shared shape for every rule-following passive (GAME_DESIGN.md §7.3): an
## event to react to, whether it's watching itself or its opponent, what has
## to hold true, and how often it's allowed to fire. What happens when it
## fires is deliberately NOT here -- see the concrete subclasses
## (OperationPassiveEffect, ModifyStatusPassiveEffect, ModifyHealPassiveEffect,
## PermanentStatPassiveEffect), each with its own payload shape rather than
## this base carrying several mutually-exclusive, mostly-unused fields.

## New values must be appended at the end, never inserted -- an authored
## PassiveEffect .tres stores trigger as this enum's raw integer index, so
## inserting a value would silently shift every trigger already saved after
## it onto the wrong meaning.
enum Trigger {
	STATUS_APPLIED,
	STATUS_REDUCED,
	STATUS_REMOVED,
	BATTLE_START,
	BATTLE_END,
	TURN_START,
	TURN_END,
	HIT,
	ATTACK,
	TECHNIQUE_USED,
	DAMAGE_DEALT,
	DAMAGE_TAKEN,

	## Retired -- ModifyHealPassiveEffect now keys off HEALED instead (see
	## below). Kept only because Trigger is append-only; no current content
	## uses this value and nothing should be authored against it going forward.
	HEAL_CAST,
	STATUS_CREATED,

	## Fires on whoever's HP actually went up, from a direct HealAction, a
	## status's on_tick() (Renewal), or a status's on_hit() (Regeneration's
	## heal-when-hit) alike -- unlike DAMAGE_DEALT/DAMAGE_TAKEN, which
	## deliberately skip DoT ticks. Serves two different consultation paths
	## that never cross-contaminate (each filters by passive type as well as
	## trigger): check_passives() dispatches OperationPassiveEffect/
	## PermanentStatPassiveEffect reactively after the heal has already
	## landed, while Combatant.passive_heal_bonus() separately queries
	## ModifyHealPassiveEffect *during* Technique.apply_heal(), before the
	## heal amount is finalized, to fold in a bonus.
	HEALED
}

enum Target {
	SELF,
	TARGET,
}

enum Limiter {
	NONE,
	ONCE_PER_TURN,
	ONCE_PER_BATTLE,
	ONCE_PER_TECHNIQUE
}

## Short display name for reward cards/tooltips -- passive_effect.gd's own
## describe() below builds the full sentence, but a card title needs a
## short name the same way Technique.technique_name/UpgradeOption.label do.
@export var passive_name: String = "Passive"

@export var trigger: Trigger
@export var trigger_target: Target = Target.TARGET

## Only meaningful for STATUS_APPLIED/STATUS_CREATED/STATUS_REDUCED/
## STATUS_REMOVED -- when set (anything but the default NONE), this passive
## only matches when the specific status the event concerns is this one, e.g.
## "when Recharge is removed, gain Enlarge" rather than "when any status is
## removed." NONE means no filter: match regardless of which status, the same
## behavior every passive had before this field existed. Harmlessly inert on
## every other trigger, since those have no specific status to compare
## against -- Combatant._matching_passives() never has one to check there.
@export var status_effect_filter: Status.StatusEffect = Status.StatusEffect.NONE

@export var conditions: Array[Condition] = []

@export var limiter: Limiter = Limiter.NONE

## Reward-tailoring metadata, consulted only by the reward-selection system
## (scripts/reward/), never by combat logic. tags is a flat, unweighted set
## of this passive's 1-3 genuinely meaningful drafting hooks -- not an
## exhaustive list of everything it touches (see RewardTag's own doc
## comment). role_* are flat per-role contribution weights (offense/
## defense/sustain/control), mirroring Familiar's flat-field-per-stat
## convention rather than a wrapper Resource for a fixed 4-member set.
@export var tags: Array[RewardTag.Tag] = []
@export var role_offense: int = 0
@export var role_defense: int = 0
@export var role_sustain: int = 0
@export var role_control: int = 0

## A human-readable summary for reward cards/tooltips, mirroring
## Technique.describe()'s "Name: sentence." shape and its
## if-conditions-then-effect framing. Unlike Technique, the *effect* half is
## each subclass's own _effect_phrase() override (deliberately not here,
## same reasoning as the rest of this class's payload split) -- but the
## *when this even checks* half (trigger/trigger_target/status_effect_filter)
## is shared by every trigger-driven subclass, so it lives here once via
## _trigger_phrase() rather than being silently absent, which previously
## left e.g. "Reprisal: if user's Ruin stacks >= 1, executes Reprisal." with
## no indication of when it fires or what "executes Reprisal" even does.
func describe() -> String:
	var effect: String = _effect_phrase()
	if effect == "":
		return "%s does nothing." % passive_name

	var sentence: String = _trigger_phrase()

	if not conditions.is_empty():
		var condition_texts: Array[String] = []
		for condition in conditions:
			condition_texts.append(condition.describe())
		sentence = "%s, if %s" % [sentence, " and ".join(condition_texts)]

	return "%s: %s, %s." % [passive_name, sentence, effect]

## Override in subclasses -- the payload-specific half of describe(). Base
## returns "" (no describable effect), matching Technique.describe()'s
## "does nothing" fallback for an empty technique.
func _effect_phrase() -> String:
	return ""

## "When this passive's trigger actually matches" in plain English, built
## from trigger + trigger_target + status_effect_filter -- all base-class
## fields, so this covers every trigger-driven subclass without needing its
## own override. trigger_target is rendered literally (not "corrected" to
## whatever would actually fire) even for the triggers that only ever get
## checked in a self-referential way in practice (HIT, ATTACK, BATTLE_START,
## BATTLE_END, TURN_START, TURN_END, TECHNIQUE_USED, DAMAGE_DEALT,
## DAMAGE_TAKEN, HEALED -- see DECISIONS.md) -- a passive accidentally left
## at trigger_target = TARGET on one of those is a real, silent dead passive
## (Combatant._matching_passives() just never matches it), and describing it
## as if it meant SELF would hide that misconfiguration instead of surfacing
## it. STATUS_APPLIED/STATUS_CREATED/STATUS_REDUCED/STATUS_REMOVED are
## genuinely dual-sided in practice (both this combatant's own passives and
## its opponent's get checked, with SELF/TARGET correctly distinguishing
## "when I..." from "when my opponent..." -- see Technique.apply_status()),
## so trigger_target varies meaningfully there.
func _trigger_phrase() -> String:
	var is_self: bool = trigger_target == Target.SELF
	var who: String = "you" if is_self else "the opponent"
	var possessive: String = "your" if is_self else "the opponent's"
	var s: String = "" if is_self else "s"
	var be: String = "are" if is_self else "is"

	match trigger:
		Trigger.STATUS_APPLIED:
			return "when %s gain%s %s" % [who, s, _status_filter_name("a status")]
		Trigger.STATUS_CREATED:
			return "when %s first gain%s %s" % [who, s, _status_filter_name("a status")]
		Trigger.STATUS_REDUCED:
			return "when %s %s stacks decrease" % [possessive, _status_filter_name("status")]
		Trigger.STATUS_REMOVED:
			return "when %s %s wears off completely" % [possessive, _status_filter_name("status")]
		Trigger.BATTLE_START:
			return "at the start of the battle"
		Trigger.BATTLE_END:
			return "at the end of the battle"
		Trigger.TURN_START:
			return "at the start of %s turn" % possessive
		Trigger.TURN_END:
			return "at the end of %s turn" % possessive
		Trigger.HIT:
			return "when %s %s hit" % [who, be]
		Trigger.ATTACK:
			return "when %s attack%s" % [who, s]
		Trigger.TECHNIQUE_USED:
			return "when %s use%s a technique" % [who, s]
		Trigger.DAMAGE_DEALT:
			return "when %s deal%s damage" % [who, s]
		Trigger.DAMAGE_TAKEN:
			return "when %s take%s damage" % [who, s]
		Trigger.HEALED:
			return "when %s %s healed" % [who, be]
	return "under an unhandled condition"

## status_effect_filter's name for a trigger phrase, or `generic` when no
## specific status is filtered (NONE, meaning "any status matches").
func _status_filter_name(generic: String) -> String:
	if status_effect_filter == Status.StatusEffect.NONE:
		return generic
	return String(Status.status_effect_id(status_effect_filter)).capitalize()
