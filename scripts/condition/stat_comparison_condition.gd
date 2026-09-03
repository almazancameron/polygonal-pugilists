class_name StatComparisonCondition
extends Condition

enum Target {
    SELF,
    TARGET
}

enum CompareMode {
    STAT,
    FLAT_VALUE
}

enum Comparator {
    GREATER,
    GREATER_OR_EQUAL,
    LESS,
    LESS_OR_EQUAL,
    EQUAL
}

@export var left_stat: Familiar.Stat
@export var left_target: Target = Target.SELF

@export var compare_mode: CompareMode = CompareMode.STAT
@export var right_stat: Familiar.Stat
@export var right_target: Target = Target.TARGET
@export var right_value: int = 0

@export var comparator: Comparator = Comparator.GREATER

func is_met(user: Combatant, target: Combatant) -> bool:
    var left_combatant: Combatant = user if left_target == Target.SELF else target
    var left_value: int = left_combatant.effective_stat(left_stat)

    var right: int = right_value
    if compare_mode == CompareMode.STAT:
        var right_combatant: Combatant = user if right_target == Target.SELF else target
        right = right_combatant.effective_stat(right_stat)

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
    var left_target_str: String = "target's" if left_target == Target.TARGET else "user's"
    var left_stat_str: String = Familiar.stat_name(left_stat)
    var comparator_str: String = {
        Comparator.GREATER: ">", Comparator.GREATER_OR_EQUAL: ">=",
        Comparator.LESS: "<", Comparator.LESS_OR_EQUAL: "<=", Comparator.EQUAL: "==",
    }[comparator]

    if compare_mode == CompareMode.FLAT_VALUE:
        return "%s %s %s %d" % [left_target_str, left_stat_str, comparator_str, right_value]

    var right_target_str: String = "target's" if right_target == Target.TARGET else "user's"
    return "%s %s %s %s %s" % [left_target_str, left_stat_str, comparator_str, right_target_str, Familiar.stat_name(right_stat)]