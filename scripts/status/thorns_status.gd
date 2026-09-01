class_name ThornsStatus
extends Status

## Deals damage back to whoever hits this combatant, equal to the stacks it
## had *before* that stack was consumed -- same shape as Bleed's on_hit(),
## just retaliating against the attacker instead of the owner.

func status_id() -> StringName:
	return &"thorns"

func on_hit(target: Combatant, attacker: Combatant) -> String:
	if stacks <= 0:
		return ""

	var damage: int = attacker.take_damage(stacks)
	stacks -= 1

	return "%s's thorns retaliate, dealing %d damage to %s! (%d stacks remain)" % [
		target.familiar.familiar_name, damage, attacker.familiar.familiar_name, stacks
	]

func preview_color() -> Color:
	return Color(0.2, 0.5, 0.1, 1.0)

func icon() -> Texture2D:
	#return preload("res://assets/sprites/icons/thorns_icon.tres")
	return null # change after adding thorns_icon.tres

func describe() -> String:
	return "Deals %d damage to whoever hits the target. Loses 1 stack per hit." % [stacks]

func on_applied(target: Combatant) -> String:
	return "%s bristles with thorns! (%d stack%s)" % [
		target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
	]
