class_name StackCountDamageBonus
extends DamageBonus

enum Target {
    SELF,
    TARGET
}

@export var count_on: Target = Target.TARGET
@export var status_effect: Status.StatusEffect
@export var count_all: bool = false

func compute(user: Combatant, target: Combatant) -> int:
    var combatant: Combatant = target if count_on == Target.TARGET else user

    if count_all:
        var total_stacks: int = 0
        for status in combatant.statuses:
            total_stacks += status.stacks
        return total_stacks * (flat_bonus + int(user.effective_power() * power_percent_bonus))
    else:
        var status: Status = combatant.get_status(status_effect)
        if status != null:
            return status.stacks * (flat_bonus + int(user.effective_power() * power_percent_bonus))
        else:
            return 0