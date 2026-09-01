class_name HexStatus
extends Status

var damage_per_stack: int = 1

func status_id() -> StringName:
    return &"hex"

func on_status_applied(target: Combatant, applied_status: Status) -> String:
    var damage: int = target.take_damage(stacks * damage_per_stack)

    return "%s's hex lashes out, dealing %d damage! (%d stacks remain)" % [
        target.familiar.familiar_name, damage, stacks
    ]