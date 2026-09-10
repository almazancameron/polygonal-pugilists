class_name LifestealStatus
extends Status

## On attack, heals int(effective Power * heal_percent_of_power), capped by
## missing HP, then reduces stacks by stacks_lost_per_hit. Healing depends
## on the configured fraction of Power, not the damage the attack dealt.
var heal_percent_of_power: float = 0.333
var stacks_lost_per_hit: int = 1

func status_id() -> StringName:
    return &"lifesteal"

func on_attack(user: Combatant) -> String:
    var healed: int = user.heal(int(user.effective_power() * heal_percent_of_power))
    stacks -= stacks_lost_per_hit
    return "%s drains %d HP from its own strike! (%d stack%s remain)" % [
        user.familiar.familiar_name, healed, stacks, "s" if stacks != 1 else ""
    ]

func preview_color() -> Color:
    return Color(0.55, 0.0, 0.2, 1.0)

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/lifesteal_icon.tres")

func describe() -> String:
    return "Heals the user for %d%% of their own Power whenever they attack. Loses %d stack%s per attack." % [
        int(heal_percent_of_power * 100), stacks_lost_per_hit, "s" if stacks_lost_per_hit != 1 else ""
    ]

func on_applied(target: Combatant) -> String:
    return "%s's strikes begin draining life! (%d stack%s)" % [
        target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
    ]
