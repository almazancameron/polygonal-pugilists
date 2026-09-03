class_name HexStatus
extends Status

var damage_per_stack: int = 1

func status_id() -> StringName:
    return &"hex"

func preview_color() -> Color:
    return Color(0.25, 0.0, 0.35, 1.0)

func on_status_applied(target: Combatant, applied_status: Status) -> String:
    var applied_status_stacks: int = applied_status.stacks
    stacks -= applied_status_stacks
    var damage: int = target.take_damage(applied_status_stacks * damage_per_stack)

    return "%s's hex lashes out, dealing %d damage! (%d stacks remain)" % [
        target.familiar.familiar_name, damage, stacks
    ]

func icon() -> Texture2D:
    return preload("res://assets/sprites/icons/hex_icon.tres")

func describe() -> String:
    return "Whenever any status is applied to the target, loses that many stacks and deals %d damage per stack." % [damage_per_stack]

func on_applied(target: Combatant) -> String:
    return "%s is cursed with a hex! (%d stack%s)" % [
        target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
    ]