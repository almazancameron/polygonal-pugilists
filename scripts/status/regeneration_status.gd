class_name RegenerationStatus
extends Status

## Two independent heals: a flat amount whenever the owner is hit (a passive
## perk that doesn't spend stacks, same shape as Thorns' on_hit() but
## healing instead of retaliating), and another flat amount on tick that
## does spend a stack -- the tick heal is what actually uses stacks up as a
## duration counter, same shape as Poison's decay.

var heal_per_hit: int = 2
var heal_per_tick: int = 2
var stacks_lost_per_tick: int = 1

func status_id() -> StringName:
    return &"regeneration"

func on_hit(target: Combatant, attacker: Combatant) -> String:
    var healed: int = target.heal(heal_per_hit)
    return "%s's regeneration mends %d HP." % [target.familiar.familiar_name, healed]

func on_tick(target: Combatant) -> String:
    var healed: int = target.heal(heal_per_tick)
    stacks -= stacks_lost_per_tick
    return "%s steadily regenerates %d HP. (%d stack%s remain)" % [
        target.familiar.familiar_name, healed, stacks, "s" if stacks != 1 else ""
    ]

func preview_color() -> Color:
    return Color(0.6, 0.95, 0.7, 1.0)

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/regeneration_icon.tres")

func describe() -> String:
    return "Heals %d HP whenever hit. Heals %d HP and loses 1 stack at the start of the turn." % [
        heal_per_hit, heal_per_tick
    ]

func on_applied(target: Combatant) -> String:
    return "%s begins regenerating! (%d stack%s)" % [
        target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
    ]
