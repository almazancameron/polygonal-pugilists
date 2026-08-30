class_name AcidStatus
extends Status

## Infinite duration stacking debuff that reduces the target's 
## defense by 10% per stack. Stacks are additive and cap at 5 by default,
## reducing the target's defense by 50% at max stacks.

const MAX_STACKS: int = 5

func status_id() -> StringName:
    return &"acid"

func stack_with(other: Status) -> void:
    stacks = min(stacks + other.stacks, MAX_STACKS)

func modify_defense(base_defense: int) -> int:
    var reduction: float = 0.1 * stacks
    return int(base_defense * (1.0 - reduction))

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/acid_icon.tres")

func preview_color() -> Color:
    return Color(0.0, 1.0, 0.5, 1.0)

func describe() -> String:
    return ("Reduces target's defense by 10%% for each stack. Max %d stacks.\n" +
    "Currently reducing defense by %d%%.") % [MAX_STACKS, int(10 * stacks)]