class_name RenewalStatus
extends Status

## Stacking heal-over-time with decay: heals for current stacks, then loses
## 2 stacks, until it runs out -- mirror of Poison's shape but healing
## instead of damaging.

func status_id() -> StringName:
    return &"renewal"

func on_tick(target: Combatant) -> String:
    var healed: int = target.heal(stacks)
    stacks -= 2
    return "%s is renewed, recovering %d HP. (%d stacks remain)" % [
        target.familiar.familiar_name, healed, stacks
    ]

func preview_color() -> Color:
    return Color(1.0, 0.75, 0.85, 1.0)

func icon() -> Texture2D:
    #return preload("res://assets/sprites/icons/renewal_icon.tres")
    return null # change after adding renewal_icon.tres

func describe() -> String:
    return ("Heals %d HP (based on stacks) at the start of target's turn.\n" +
    "Loses 2 stacks per turn.") % [stacks]

func on_applied(target: Combatant) -> String:
    return "%s is bathed in renewal! (%d stack%s)" % [
        target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
    ]
