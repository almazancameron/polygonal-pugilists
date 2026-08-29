class_name BurnStatus
extends Status

## Duration-based damage-over-time with fixed damage per tick and a fixed duration of 
## 5 turns. Stacks represent turns remaining and refresh to 5 when re-applied.
## Re-applying Burn to an already-burning target causes a Flare, dealing immediate bonus damage.

func status_id() -> StringName:
    return &"burn"

func stack_with(other: Status) -> void:
    ## Refresh duration to the highest of the two burns
    stacks = max(stacks, other.stacks)

func next_tick_damage() -> int:
    return 3

func preview_color() -> Color:
    return Color(1.0, 0.5, 0.0, 1.0)

func on_tick(target: Combatant) -> String:
    var damage: int = next_tick_damage()
    target.take_damage(damage)
    stacks -= 1
    return "%s suffers %d burn damage. (%d turns remain)" % [target.familiar.familiar_name, damage, stacks]

func on_reapply(target: Combatant) -> String:
    ## flare damage based on stacks might end up being a perk/passive later on, if so we'll switch to a flat value here
    var flare_damage: int = stacks
    target.take_damage(flare_damage)

    return "%s's burn flares, dealing %d bonus damage!" % [target.familiar.familiar_name, flare_damage]