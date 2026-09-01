class_name StatusCountDamageBonus
extends DamageBonus

enum Target {
    SELF,
    TARGET
}

@export var count_on: Target = Target.TARGET

func compute(user: Combatant, target: Combatant) -> int:
    var combatant: Combatant = target if count_on == Target.TARGET else user

    return combatant.statuses.size() * (flat_bonus + int(user.effective_power() * power_percent_bonus))