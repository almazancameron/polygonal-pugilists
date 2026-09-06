class_name AbsorptionStatus
extends Status

## Capped so a kit that keeps re-stacking Absorption faster than it's spent
## can't build an effectively-unbounded shield -- see DECISIONS.md/DEVLOG.md
## on the Absorption-driven stalemates this was meant to bound. Same
## stack_with()-clamping convention as AcidStatus/StaggerStatus.
var max_stack_count: int = 20

func max_stacks() -> int:
    return max_stack_count

func status_id() -> StringName:
    return &"absorption"

func stack_with(other: Status) -> void:
    stacks = min(stacks + other.stacks, max_stack_count)

func describe() -> String:
    return "Absorbs the next %d damage taken by the target. (max %d)" % [stacks, max_stack_count]

func preview_color() -> Color:
    return Color(0.15, 0.7, 0.65, 1.0)

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/absorption_icon.tres")