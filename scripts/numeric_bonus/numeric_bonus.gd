class_name NumericBonus
extends Resource

## Situational bonus computation shared across action types -- the same
## flat + percent formula whether it ends up added to a hit's damage, a
## status application's stack count, or a heal. applies_to says which
## action kind sums this bonus in, so a single step group can hold several
## independently-targeted bonuses (one for its hit, a different one for
## its status application) without needing to split into separate step
## groups just to keep them from crossing over.

enum ActionType { HIT, STATUS, HEAL }
enum ValueSource { STAT, STATUS_STACKS, STATUS_COUNT, HP }
enum Target { SELF, TARGET }

@export var applies_to: ActionType = ActionType.HIT
@export var flat_bonus: int = 0

@export var percent_bonus: float = 0.0
@export var percent_source: ValueSource = ValueSource.STAT
@export var percent_target: Target = Target.SELF

@export var percent_stat: Familiar.Stat = Familiar.Stat.POWER  # used when percent_source == STAT

@export var percent_status_effect: Status.StatusEffect = Status.StatusEffect.POISON  # used when percent_source == STATUS_STACKS
@export var percent_check_all: bool = false  # ignores percent_status_effect, sums every status's stacks instead (STATUS_STACKS only)

## Resolves whatever percent_source/percent_target point at. E.g. the
## default (STAT, SELF, POWER) reproduces the old "percent of the user's
## Power" behavior, but the same fields can just as easily read a specific
## status's stacks, how many distinct statuses are active, or either
## combatant's current HP instead.
func _percent_value(user: Combatant, target: Combatant) -> float:
	var combatant: Combatant = user if percent_target == Target.SELF else target

	match percent_source:
		ValueSource.STAT:
			return float(combatant.effective_stat(percent_stat))
		ValueSource.STATUS_STACKS:
			if percent_check_all:
				var total: int = 0
				for status in combatant.statuses:
					total += status.stacks
				return float(total)
			var status: Status = combatant.get_status(percent_status_effect)
			return float(status.stacks) if status != null else 0.0
		ValueSource.STATUS_COUNT:
			return float(combatant.statuses.size())
		ValueSource.HP:
			return float(combatant.current_hp)

	return 0.0

## The base flat+percent amount, before whatever a subclass does with it
## (gating on a condition, multiplying by a stack/status count, ...).
## Subclasses call this instead of re-deriving flat_bonus/percent_bonus
## themselves.
func base_amount(user: Combatant, target: Combatant) -> int:
	return flat_bonus + int(_percent_value(user, target) * percent_bonus)

func compute(user: Combatant, target: Combatant) -> int:
	return base_amount(user, target)
