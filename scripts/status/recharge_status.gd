class_name RechargeStatus
extends Status

## Countdown marker reduced by stacks_lost_per_tick on upkeep. Authored
## conditions use its presence or stack count to gate technique effects;
## the executor does not impose a universal Recharge restriction.
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
