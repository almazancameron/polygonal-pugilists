class_name CleanseStatus
extends Status

## Strips one other active status (picked at random) from the target on
## tick, then loses a stack itself. The strip goes through the victim's
## normal stacks setter (set to 0) rather than a direct statuses.erase() --
## same as every other stack loss in the game, so Stasis can intercept a
## cleanse exactly like it intercepts decay or self-consumption.

var statuses_stripped_per_tick: int = 1
var stacks_lost_per_tick: int = 1

func status_id() -> StringName:
    return &"cleanse"

func on_tick(target: Combatant) -> String:
    var candidates: Array[Status] = []
    for status in target.statuses:
        if status != self:
            candidates.append(status)

    var messages: Array[String] = []
    for i in range(statuses_stripped_per_tick):
        if candidates.is_empty():
            break

        var victim: Status = candidates.pick_random()
        candidates.erase(victim)
        var victim_id: String = String(victim.status_id()).capitalize()
        victim.stacks = 0
        if victim.is_expired():
            target.statuses.erase(victim)
            messages.append("%s's cleanse washes away its %s!" % [target.familiar.familiar_name, victim_id])
        else:
            messages.append("%s's cleanse fails to wash away its %s!" % [target.familiar.familiar_name, victim_id])

    stacks -= stacks_lost_per_tick
    return " ".join(messages)

func preview_color() -> Color:
    return Color(0.85, 1.0, 0.95, 1.0)

func icon() -> Texture2D:
    #return preload("res://assets/sprites/icons/cleanse_icon.tres")
    return null # change after adding cleanse_icon.tres

func describe() -> String:
    return "Removes %d other active status%s from the target at random. Loses %d stack%s per turn." % [
        statuses_stripped_per_tick, "es" if statuses_stripped_per_tick != 1 else "",
        stacks_lost_per_tick, "s" if stacks_lost_per_tick != 1 else ""
    ]

func on_applied(target: Combatant) -> String:
    return "%s begins cleansing itself! (%d stack%s)" % [
        target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
    ]
