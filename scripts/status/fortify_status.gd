class_name FortifyStatus
extends Status

## Adds a flat value to defense for a number of turns based on the stacks.

var stack_value: int = 1
var stacks_lost_per_tick: int = 2

func defense_bonus() -> int:
    return stack_value * stacks

func status_id() -> StringName:
    return &"fortify"

func modify_stat(stat: Familiar.Stat, value: int) -> int:
    if stat == Familiar.Stat.DEFENSE:
        return value + defense_bonus()
    else:
        return value

func on_tick(target: Combatant) -> String:
    stacks -= stacks_lost_per_tick
    if stacks <= 0:
        return "%s's fortification fades." % [target.familiar.familiar_name]
    else:
        return "%s's fortification holds strong. (%d stack%s remain.)" % [
            target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
        ]

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/fortify_icon.tres")

func preview_color() -> Color:
    return Color(0.1, 0.1, 0.4, 1.0)

func describe() -> String:
    return ("Increases target's defense by %d per stack. Loses %d stack%s per turn.") % [
        stack_value, stacks_lost_per_tick, "s" if stacks_lost_per_tick != 1 else ""
    ]

func on_applied(target: Combatant) -> String:
    return "%s fortifies its body, boosting defense! (%d stack%s)" % [
        target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
    ]