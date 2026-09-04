class_name RechargeStatus
extends Status

## Status that does nothing except lose a stack every turn on its own.
## Many techniques apply recharge to the user. Any technique that applies recharge
## to the user has extremely diminshed effect (if any) if the user is already recharging.
## Some techniques might also apply recharge to the target as a debuff, but this is less common.

var stacks_lost_per_tick: int = 1

func status_id() -> StringName:
    return &"recharge"

func on_tick(target: Combatant) -> String:
    stacks -= stacks_lost_per_tick
    return "%s recharges its energy %d time%s. (%d stack%s remaining.)" % [
        target.familiar.familiar_name, stacks_lost_per_tick, "s" if stacks_lost_per_tick != 1 else "", stacks, "s" if stacks != 1 else ""
    ]

func preview_color() -> Color:
    return Color(0.35, 0.25, 1.0, 1.0)

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/recharge_icon.tres")

func describe() -> String:
    return ("Loses %d stack%s per turn. While recharging, abilities that apply recharge to the target are significantly weaker.") % [
        stacks_lost_per_tick, "s" if stacks_lost_per_tick != 1 else ""
    ]

func on_applied(target: Combatant) -> String:
    return "%s begins recharging its energy! (%d stack%s remain.)" % [
        target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
    ]