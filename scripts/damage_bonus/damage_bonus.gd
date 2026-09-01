class_name DamageBonus
extends Resource

@export var flat_bonus: int = 0
@export var power_percent_bonus: float = 0.0

func compute(user: Combatant, target: Combatant) -> int:
    return flat_bonus + int(user.effective_power() * power_percent_bonus)