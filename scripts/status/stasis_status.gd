class_name StasisStatus
extends Status

func status_id() -> StringName:
    return &"stasis"

func preview_color() -> Color:
    return Color(0.75, 0.8, 0.9, 1.0)

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/stasis_icon.tres")

func on_applied(target: Combatant) -> String:
    return "%s is now in stasis! The next %d status reductions will be negated." % [target.familiar.familiar_name, stacks]

func describe() -> String:
    return "Next time a status effect's stacks would be removed or reduced, remove a stack of stasis instead. (%d remaining)" % stacks