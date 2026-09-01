class_name AbsorptionStatus
extends Status

func status_id() -> StringName:
    return &"absorption"

func describe() -> String:
    return "Absorbs the next %d damage taken by the target." % [stacks]

func preview_color() -> Color:
    return Color(0.5, 1.0, 0.5, 1.0)

func icon() -> Texture2D:
    #return preload("res://assets/sprites/icons/absorption_icon.tres")
    return null # change after adding absorption_icon.tres