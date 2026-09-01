class_name ConditionalDamageBonus
extends DamageBonus

@export var condition: Condition

func compute(user: Combatant, target: Combatant) -> int:
    if condition.is_met(user, target):
        return flat_bonus + int(user.effective_power() * power_percent_bonus)
    else:
        return 0