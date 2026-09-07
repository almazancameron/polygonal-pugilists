class_name HpComparisonCondition
extends Condition

## Retires SelfHPBelowXCondition, which could only check the user's own HP
## against a flat percentage. Compares current HP -- self or target, as a
## percentage of max HP or as a raw value -- against either the other
## combatant's current HP or a flat number. Same left/right/target/
## comparator shape as StatComparisonCondition, just resolving "current HP"
## instead of a Familiar.Stat.

enum Target { SELF, TARGET }
enum CompareMode { HP, FLAT_VALUE }
enum Comparator { GREATER, GREATER_OR_EQUAL, LESS, LESS_OR_EQUAL, EQUAL }

@export var left_target: Target = Target.SELF

@export var compare_mode: CompareMode = CompareMode.FLAT_VALUE
@export var right_target: Target = Target.TARGET
@export var right_value: float = 0.0

## Whether HP is read as a fraction of max HP (0.0-1.0) or as a raw value.
## Applies to both sides -- comparing one side's percentage against the
## other's raw HP wouldn't mean anything.
@export var use_percent: bool = true

@export var comparator: Comparator = Comparator.LESS

func _resolve(combatant: Combatant) -> float:
	if use_percent:
		return float(combatant.current_hp) / combatant.familiar.max_hp
	return float(combatant.current_hp)

func is_met(user: Combatant, target: Combatant) -> bool:
	var left_combatant: Combatant = user if left_target == Target.SELF else target
	var left_value: float = _resolve(left_combatant)

	var right: float = right_value
	if compare_mode == CompareMode.HP:
		var right_combatant: Combatant = user if right_target == Target.SELF else target
		right = _resolve(right_combatant)

	match comparator:
		Comparator.GREATER:
			return left_value > right
		Comparator.GREATER_OR_EQUAL:
			return left_value >= right
		Comparator.LESS:
			return left_value < right
		Comparator.LESS_OR_EQUAL:
			return left_value <= right
		Comparator.EQUAL:
			return left_value == right
	return false

func describe() -> String:
	var left_str: String = "target's" if left_target == Target.TARGET else "user's"
	# Plain ASCII "<"/">" render as icon-like glyphs in yoster.ttf -- these
	# fullwidth/mathematical variants are ones it draws as plain angle
	# brackets instead. See condition_block.gd's matching COMPARATOR labels.
	var comparator_str: String = {
		Comparator.GREATER: "＞", Comparator.GREATER_OR_EQUAL: "≥",
		Comparator.LESS: "＜", Comparator.LESS_OR_EQUAL: "≤", Comparator.EQUAL: "==",
	}[comparator]

	if compare_mode == CompareMode.FLAT_VALUE:
		var right_str: String = ("%d%%" % int(right_value * 100)) if use_percent else str(right_value)
		return "%s HP %s %s" % [left_str, comparator_str, right_str]

	var right_target_str: String = "target's" if right_target == Target.TARGET else "user's"
	return "%s HP %s %s HP" % [left_str, comparator_str, right_target_str]
