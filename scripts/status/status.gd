class_name Status
extends RefCounted

## Base shape for an active status effect on a Combatant. Per-battle runtime
## state, same reasoning as Combatant: never saved or edited in the
## Inspector, so RefCounted rather than Resource or Node.

enum StatusEffect { NONE, POISON, BURN, ACID, BLEED, STAGGER, FORETELL, STUN, DEFENDING, INFESTATION, HONE, FORTIFY, ENLARGE, RECHARGE, THORNS, WARD, HEX, ABSORPTION, RUIN, RETALIATION, STASIS, RENEWAL, LIFESTEAL, REGENERATION, CLEANSE }

var stacks: int = 1:
	set(value):
		if value < stacks and owner != null and status_id() != Status.status_effect_id(Status.StatusEffect.STASIS):
			var stasis: Status = owner.get_status(Status.StatusEffect.STASIS)
			if stasis != null:
				# This status's own reduction is redirected into Stasis instead
				# (stacks left untouched below), so Stasis is the one whose
				# stacks actually just changed -- notify for *it*, not for
				# self, or STATUS_REDUCED/REMOVED never fires for Stasis at
				# all (every caller of _notify_stack_change() only ever knows
				# to check the status object it thinks it's ticking).
				var stasis_stacks_before: int = stasis.stacks
				stasis.stacks -= 1
				owner._notify_stack_change(stasis, stasis_stacks_before)
				if stasis.is_expired():
					owner.statuses.erase(stasis)
				return
		stacks = value

var owner: Combatant = null

func _init(initial_stacks: int = 1) -> void:
	stacks = initial_stacks

## Identifies "the same" status for stacking purposes. Compared by value
## since GDScript has no clean built-in "same subclass" check.
func status_id() -> StringName:
	return &"status"

func stack_with(other: Status) -> void:
	stacks += other.stacks

func max_stacks() -> int:
	return -1

## Called once when it's this status's turn to act. Returns a combat log
## message, or "" if nothing happened. Override in subclasses.
func on_tick(target: Combatant) -> String:
	return ""

## Called when this status is re-applied to a target that already has it.
## Returns a combat log message, or "" if nothing happened. Override in subclasses.
func on_reapply(target: Combatant) -> String:
	return ""

## Called whenever this combatant is hit by a technique's damage. attacker is
## whoever dealt it -- needed by statuses like Thorns that retaliate against
## them. Returns a combat log message, or "" if nothing happened. Override
## in subclasses.
func on_hit(target: Combatant, attacker: Combatant) -> String:
	return ""

## Called when the relevant combatant is the one dealing damage with a technique. Returns a
## combat log message, or "" if nothing happened. Override in subclasses.
func on_attack(user: Combatant) -> String:
	return ""

## Called whenever this status's stacks have just been set, whether from a
## fresh application or a stack_with() merge. Returns a combat log message,
## or "" if nothing happened. Override in subclasses.
func on_applied(target: Combatant) -> String:
	return ""

func on_status_applied(target: Combatant, applied_status: Status) -> String:
	return ""

func is_expired() -> bool:
	return stacks <= 0

func next_tick_damage() -> int:
	return 0

func preview_color() -> Color:
	return Color(0, 0, 0, 1)

func modify_stat(stat: Familiar.Stat, value: int) -> int:
	return value

func modify_incoming_damage(value: int) -> int:
	return value

func icon() -> Texture2D:
	return null

func describe() -> String:
	return "Status"

func grants_first_act_override() -> bool:
	return false

## Translates a StatusEffect enum value to the StringName a concrete
## Status subclass's own status_id() returns. Lets other classes
## (Technique, Condition subclasses) compare against StatusEffect
## directly instead of keeping their own separate enum-to-StringName table.
static func status_effect_id(effect: StatusEffect) -> StringName:
	match effect:
		StatusEffect.POISON:
			return &"poison"
		StatusEffect.BURN:
			return &"burn"
		StatusEffect.ACID:
			return &"acid"
		StatusEffect.BLEED:
			return &"bleed"
		StatusEffect.STAGGER:
			return &"stagger"
		StatusEffect.FORETELL:
			return &"foretell"
		StatusEffect.STUN:
			return &"stun"
		StatusEffect.DEFENDING:
			return &"defending"
		StatusEffect.INFESTATION:
			return &"infestation"
		StatusEffect.HONE:
			return &"hone"
		StatusEffect.FORTIFY:
			return &"fortify"
		StatusEffect.ENLARGE:
			return &"enlarge"
		StatusEffect.RECHARGE:
			return &"recharge"
		StatusEffect.THORNS:
			return &"thorns"
		StatusEffect.WARD:
			return &"ward"
		StatusEffect.HEX:
			return &"hex"
		StatusEffect.ABSORPTION:
			return &"absorption"
		StatusEffect.RUIN:
			return &"ruin"
		StatusEffect.RETALIATION:
			return &"retaliation"
		StatusEffect.STASIS:
			return &"stasis"
		StatusEffect.RENEWAL:
			return &"renewal"
		StatusEffect.LIFESTEAL:
			return &"lifesteal"
		StatusEffect.REGENERATION:
			return &"regeneration"
		StatusEffect.CLEANSE:
			return &"cleanse"
		_:
			return &""

static func create(effect: StatusEffect, initial_stacks: int = 1) -> Status:
	match effect:
		Status.StatusEffect.POISON:
			return PoisonStatus.new(initial_stacks)
		Status.StatusEffect.BURN:
			return BurnStatus.new(initial_stacks)
		Status.StatusEffect.ACID:
			return AcidStatus.new(initial_stacks)
		Status.StatusEffect.BLEED:
			return BleedStatus.new(initial_stacks)
		Status.StatusEffect.STAGGER:
			return StaggerStatus.new(initial_stacks)
		Status.StatusEffect.FORETELL:
			return ForetellStatus.new(initial_stacks)
		Status.StatusEffect.STUN:
			return StunStatus.new(initial_stacks)
		Status.StatusEffect.DEFENDING:
			return DefendingStatus.new(initial_stacks)
		Status.StatusEffect.INFESTATION:
			return InfestationStatus.new(initial_stacks)
		Status.StatusEffect.HONE:
			return HoneStatus.new(initial_stacks)
		Status.StatusEffect.FORTIFY:
			return FortifyStatus.new(initial_stacks)
		Status.StatusEffect.ENLARGE:
			return EnlargeStatus.new(initial_stacks)
		Status.StatusEffect.RECHARGE:
			return RechargeStatus.new(initial_stacks)
		Status.StatusEffect.THORNS:
			return ThornsStatus.new(initial_stacks)
		Status.StatusEffect.WARD:
			return WardStatus.new(initial_stacks)
		Status.StatusEffect.HEX:
			return HexStatus.new(initial_stacks)
		Status.StatusEffect.ABSORPTION:
			return AbsorptionStatus.new(initial_stacks)
		Status.StatusEffect.RUIN:
			return RuinStatus.new(initial_stacks)
		Status.StatusEffect.RETALIATION:
			return RetaliationStatus.new(initial_stacks)
		Status.StatusEffect.STASIS:
			return StasisStatus.new(initial_stacks)
		Status.StatusEffect.RENEWAL:
			return RenewalStatus.new(initial_stacks)
		Status.StatusEffect.LIFESTEAL:
			return LifestealStatus.new(initial_stacks)
		Status.StatusEffect.REGENERATION:
			return RegenerationStatus.new(initial_stacks)
		Status.StatusEffect.CLEANSE:
			return CleanseStatus.new(initial_stacks)
		_:
			return null

## Reverse of status_effect_id() -- looks up a StatusEffect by the
## StringName its status_id() would return, so a BBCode-authored nested
## tooltip reference (e.g. "[url=poison]Poison[/url]") can resolve back to
## a real Status without a separate hardcoded name table.
static func from_id(id: StringName, initial_stacks: int = 1) -> Status:
	for effect in StatusEffect.values():
		if status_effect_id(effect) == id:
			return create(effect, initial_stacks)
	return null

## Wraps a status name in the [url=...] markup TooltipPanel resolves into a
## nested status tooltip -- shared by Technique.describe() and
## NumericBonus.describe_bonus() so both quote status names the same way.
## Bold as well as underlined -- yoster.ttf's underline is thin enough that
## it reads as barely-there on its own, so [b] (see yoster_bold.tres, an
## embolden FontVariation set as both RichTextLabels' bold_font override)
## carries most of the "this is a link" signal.
static func status_link(effect: StatusEffect) -> String:
	var id: StringName = status_effect_id(effect)
	return "[url=%s][b]%s[/b][/url]" % [id, String(id).capitalize()]