class_name CleanseStatus
extends Status

## Strips one other active status (picked at random) from the target on
## tick, then loses a stack itself. The strip goes through the victim's
## normal stacks setter (set to 0) rather than a direct statuses.erase() --
## same as every other stack loss in the game, so Stasis can intercept a
## cleanse exactly like it intercepts decay or self-consumption.

func status_id() -> StringName:
    return &"cleanse"

func on_tick(target: Combatant) -> String:
    var candidates: Array[Status] = []
    for status in target.statuses:
        if status != self:
            candidates.append(status)

    var message: String = ""
    if not candidates.is_empty():
        var victim: Status = candidates.pick_random()
        var victim_id: String = String(victim.status_id()).capitalize()
        victim.stacks = 0
        if victim.is_expired():
            target.statuses.erase(victim)
            message = "%s's cleanse washes away its %s!" % [target.familiar.familiar_name, victim_id]
        else:
            message = "%s's cleanse fails to wash away its %s!" % [target.familiar.familiar_name, victim_id]

    stacks -= 1
    return message

func preview_color() -> Color:
    return Color(0.85, 1.0, 0.95, 1.0)

func icon() -> Texture2D:
    #return preload("res://assets/sprites/icons/cleanse_icon.tres")
    return null # change after adding cleanse_icon.tres

func describe() -> String:
    return "Removes one other active status from the target at random. Loses 1 stack per turn."

func on_applied(target: Combatant) -> String:
    return "%s begins cleansing itself! (%d stack%s)" % [
        target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
    ]
