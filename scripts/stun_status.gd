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
    return Color(0.9, 0.9, 0.3, 1.0)

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/stun_icon.tres")

func describe() -> String:
    return "Prevents the target from acting for a turn."