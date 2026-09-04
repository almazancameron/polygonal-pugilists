class_name RetaliationStatus
extends Status

var damage_per_stack: int = 1

func status_id() -> StringName:
    return &"retaliation"

func on_hit(target: Combatant, attacker: Combatant) -> String:
    var damage: int = attacker.take_damage(damage_per_stack * stacks)
    stacks = 0

    var message: String = "%s strikes back in retaliation, dealing %d damage to %s!" % [
        target.familiar.familiar_name, damage, attacker.familiar.familiar_name
    ]

    var chain_message: String = attacker.trigger_on_hit(target)
    if chain_message != "":
        message += " " + chain_message

    return message

func describe() -> String:
    return ("Deals %d damage to the attacker next time the target is hit, triggering on-hit effects.\n" +
    "Loses all stacks after retaliating.") % [damage_per_stack * stacks]

func on_applied(target: Combatant) -> String:
    return "%s prepares a counterattack!" % [
        target.familiar.familiar_name
    ]

func preview_color() -> Color:
    return Color(0.8, 0.3, 0.1, 1.0)

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/retaliation_icon.tres")