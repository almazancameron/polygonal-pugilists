class_name HoneStatus
extends Status

## Increases the target's power by a flat value for a number of hits based on the stacks.

var stack_value: int = 2
var stacks_lost_per_hit: int = 1

func status_id() -> StringName:
    return &"hone"

func modify_stat(stat: Familiar.Stat, value: int) -> int:
    if stat == Familiar.Stat.POWER:
        return value + (stack_value * stacks)
    else:
        return value

func on_attack(target: Combatant) -> String:
    stacks -= stacks_lost_per_hit
    if stacks <= 0:
        return "%s's honed strikes lose their edge." % [target.familiar.familiar_name]
    else:
        return "%s's strikes remain empowered. (%d stack%s remain.)" % [
            target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
        ]

func describe() -> String:
    return ("Increases target's power by %d per stack. Loses %d stack%s per hit.") % [
        stack_value, stacks_lost_per_hit, "s" if stacks_lost_per_hit != 1 else ""
    ]

func on_applied(target: Combatant) -> String:
    return "%s hones its strikes, increasing power! (%d stack%s)" % [
        target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
    ]

func preview_color() -> Color:
    return Color(0.55, 0.35, 0.15, 1.0)

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/hone_icon.tres")