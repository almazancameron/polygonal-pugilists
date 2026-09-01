class_name StunStatus
extends Status

## Prevents the target from acting for a turn. Generally only applied by reaching max stacks of stagger for now.

func status_id() -> StringName:
    return &"stun"

func on_tick(target: Combatant) -> String:
    target.is_stunned = true
    stacks = 0

    return ""

func preview_color() -> Color:
    return Color(1.0, 1.0, 1.0, 1.0)

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/stun_icon.tres")

func describe() -> String:
    return "Prevents the target from acting for a turn."

func on_applied(target: Combatant) -> String:
    return "%s is stunned and will skip its next turn!" % target.familiar.familiar_name