class_name BurnStatus
extends Status

## Duration-based damage-over-time with fixed damage per tick and a fixed duration of
## 5 turns. Stacks represent turns remaining and refresh to 5 when re-applied.
## Re-applying Burn to an already-burning target causes a Flare, dealing immediate bonus damage.

var max_stack_count: int = 5
var damage_per_tick: int = 3
var flare_damage: int = 3
var stacks_lost_per_tick: int = 1
var stacks_multiply_flare_damage: int = 0 #0 = false, 1 = true

func max_stacks() -> int:
    return max_stack_count

func status_id() -> StringName:
    return &"burn"

func stack_with(other: Status) -> void:
    stacks = max(stacks, other.stacks)

func next_tick_damage() -> int:
    return damage_per_tick

func preview_color() -> Color:
    return Color(1.0, 0.5, 0.0, 1.0)

func on_tick(target: Combatant) -> String:
    var damage: int = target.take_damage(next_tick_damage())
    stacks -= stacks_lost_per_tick
    return "%s suffers %d burn damage. (%d turns remain)" % [target.familiar.familiar_name, damage, stacks]

func on_reapply(target: Combatant) -> String:
    var damage: int = target.take_damage((flare_damage * stacks) if stacks_multiply_flare_damage == 1 else flare_damage)

    return "%s's burn flares, dealing %d bonus damage!" % [target.familiar.familiar_name, damage]

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/burn_icon.tres")

func describe() -> String:
    return ("Deals %d damage at the start of target's turn for %d turns.\n" +
    "Applying a new burn will cause it to flare for\n" +
    "%d bonus damage%s and reset the duration.") % [next_tick_damage(), max_stack_count, flare_damage, " per remaining stack" if stacks_multiply_flare_damage == 1 else ""]

func on_applied(target: Combatant) -> String:
    return "%s is burning! (%d turns remain)" % [target.familiar.familiar_name, stacks]
