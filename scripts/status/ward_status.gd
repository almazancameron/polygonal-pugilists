class_name WardStatus
extends Status

## Combatant.add_status() consumes Ward one-for-one against externally
## applied status stacks, whether beneficial or negative. Self-applications
## and incoming Ward bypass this interception.
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
