class_name EnlargeStatus
extends Status

## Multiplies power for a number of turns equal to the stacks.

var stack_value: float = 1.5

func status_id() -> StringName:
    return &"enlarge"

func modify_stat(stat: Familiar.Stat, value: int) -> int:
    if stat == Familiar.Stat.POWER:
        return int(value * stack_value)
    else:
        return value

func on_tick(target: Combatant) -> String:
    stacks -= 1

    if stacks <= 0:
        return "%s returns to normal." % [target.familiar.familiar_name]
    else:
        return "%s towers over the battlefield. (%d turn%s remain.)" % [
            target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
        ]

func preview_color() -> Color:
    return Color(0.6, 0.9, 0.2, 1.0)

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/enlarge_icon.tres")

func describe() -> String:
    return ("Increases target's power by %.1fx. Loses 1 stack per turn.") % [
        stack_value
    ]

func on_applied(target: Combatant) -> String:
    return "%s grows larger! (%d turn%s remain.)" % [
        target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
    ]