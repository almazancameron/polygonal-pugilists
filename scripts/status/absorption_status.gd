class_name AbsorptionStatus
extends Status

func status_id() -> StringName:
    return &"absorption"

func describe() -> String:
    return "Absorbs the next %d damage taken by the target." % [stacks]

func preview_color() -> Color:
    return Color(0.15, 0.7, 0.65, 1.0)

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/absorption_icon.tres")