class_name LifestealStatus
extends Status

## Heals the owner for their own effective Power whenever they land an
## attack, then loses a stack -- same on_attack() shape as Hone, healing
## instead of buffing.

func status_id() -> StringName:
    return &"lifesteal"

func on_attack(user: Combatant) -> String:
    var healed: int = user.heal(user.effective_power())
    stacks -= 1
    return "%s drains %d HP from its own strike! (%d stack%s remain)" % [
        user.familiar.familiar_name, healed, stacks, "s" if stacks != 1 else ""
    ]

func preview_color() -> Color:
    return Color(0.55, 0.0, 0.2, 1.0)

func icon() -> Texture2D:
    #return preload("res://assets/sprites/icons/lifesteal_icon.tres")
    return null # change after adding lifesteal_icon.tres

func describe() -> String:
    return "Heals the user for their own Power whenever they attack. Loses 1 stack per attack."

func on_applied(target: Combatant) -> String:
    return "%s's strikes begin draining life! (%d stack%s)" % [
        target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
    ]
