class_name RuinStatus
extends Status

var percent_increase: float = 0.5
var stacks_lost_per_tick: int = 1

func status_id() -> StringName:
    return &"ruin"

func modify_incoming_damage(value: int) -> int:
    return int(value * (1.0 + percent_increase))

func preview_color() -> Color:
    return Color(0.35, 0.02, 0.05, 1.0)

func describe() -> String:
    return "Increases damage taken by %d%%." % [int(percent_increase * 100)]

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/ruin_icon.tres")

func on_tick(target) -> String:
    stacks -= stacks_lost_per_tick

    if stacks <= 0:
        return "The ruin effect fades."
    else:
        return "%s's defenses are shattered by a ruinous curse. (%d stack%s remain.)" % [
            target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
        ]