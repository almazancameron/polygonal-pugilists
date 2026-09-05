class_name InfestationStatus
extends Status

## Infinitely stacking status that deals 1 damage and adds 1 stack per tick. 
## Stacks beyond the first do nothing on their own, but can be used by
## other techniques to increase damage or add additional effects.

## How much damage to do and how many stacks to add per tick.
var tick_magnitude: int = 1

func status_id() -> StringName:
    return &"infestation"

func on_tick(target: Combatant) -> String:
    stacks += tick_magnitude
    var damage: int = target.take_damage(tick_magnitude)

    return "%s's infestation grows, dealing %d damage and increasing the stacks to %d!" % [
        target.familiar.familiar_name, damage, stacks
    ]

func next_tick_damage() -> int:
    return tick_magnitude

func preview_color() -> Color:
    return Color(0.3, 0.6, 0.1, 1.0)

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/infestation_icon.tres")
    
func describe() -> String:
    return ("Deals %d damage to the target and gains %d stack%s per turn as the infestation spreads.") % [
        tick_magnitude, tick_magnitude, "s" if tick_magnitude != 1 else ""
    ]

func on_applied(target: Combatant) -> String:
    return "%s is infested with parasites! (%d stack%s)" % [
        target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
    ]