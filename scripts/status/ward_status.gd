class_name WardStatus
extends Status

## Absorbs incoming status effects, preventing them from being applied to the combatant.
## Ward prevents both negative and beneficial effects, allowing it to be used offensively or
## defensively. A stack is consumed for each stack of status that would be applied.

func status_id() -> StringName:
    return &"ward"

func preview_color() -> Color:
    return Color(0.45, 0.8, 0.85, 1.0)

func describe() -> String:
    return "Absorbs the next %d stack%s of status effects that would be applied to the target." % [
        stacks, "s" if stacks != 1 else ""
    ]

func on_applied(target: Combatant) -> String:
    return "%s puts up a magical ward! (%d stack%s)" % [
        target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
    ]

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/ward_icon.tres")