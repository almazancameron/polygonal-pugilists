class_name BurnStatus
extends Status

## Duration-based damage-over-time with fixed damage per tick and a fixed duration of 
## 5 turns. Stacks represent turns remaining and refresh to 5 when re-applied.
## Re-applying Burn to an already-burning target causes a Flare, dealing immediate bonus damage.

const MAX_STACKS: int = 5

func max_stacks() -> int:
    return MAX_STACKS

func status_id() -> StringName:
    return &"burn"

func stack_with(other: Status) -> void:
    ## Refresh duration to the highest of the two burns
    stacks = max(stacks, other.stacks)

func next_tick_damage() -> int:
    return 2

func flare_damage() -> int:
    return 2

func preview_color() -> Color:
    return Color(1.0, 0.5, 0.0, 1.0)

func on_tick(target: Combatant) -> String:
    var damage: int = target.take_damage(next_tick_damage())
    stacks -= 1
    return "%s suffers %d burn damage. (%d turns remain)" % [target.familiar.familiar_name, damage, stacks]

func on_reapply(target: Combatant) -> String:
    var damage: int = target.take_damage(flare_damage())

    return "%s's burn flares, dealing %d bonus damage!" % [target.familiar.familiar_name, damage]

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/burn_icon.tres")

func describe() -> String:
    return ("Deals %d damage at the start of target's turn for 5 turns.\n" +
    "Applying a new burn will cause it to flare for\n" +
    "%d bonus damage and reset the duration.") % [next_tick_damage(), flare_damage()]

func on_applied(target: Combatant) -> String:
    return "%s is burning! (%d turns remain)" % [target.familiar.familiar_name, stacks]