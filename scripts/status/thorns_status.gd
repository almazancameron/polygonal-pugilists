class_name ThornsStatus
extends Status

## Deals damage back to whoever hits this combatant, equal to the stacks it
## had *before* that stack was consumed -- same shape as Bleed's on_hit(),
## just retaliating against the attacker instead of the owner.

var damage_per_stack: int = 1
var stacks_lost_per_hit: int = 1

func status_id() -> StringName:
	return &"thorns"

func on_hit(target: Combatant, attacker: Combatant) -> String:
	if stacks <= 0:
		return ""

	var damage: int = attacker.take_damage(damage_per_stack * stacks)

	return "%s's thorns retaliate, dealing %d damage to %s!" % [
		target.familiar.familiar_name, damage, attacker.familiar.familiar_name
	]

func preview_color() -> Color:
	return Color(0.2, 0.5, 0.1, 1.0)

func icon() -> Texture2D:
	return preload("res://assets/sprites/icons/thorns_icon.tres")

func describe() -> String:
	return "Deals %d damage to whoever hits the target. Loses %d stack%s per hit." % [
		damage_per_stack * stacks, stacks_lost_per_hit, "s" if stacks_lost_per_hit != 1 else ""
	]

func on_applied(target: Combatant) -> String:
	return "%s bristles with thorns! (%d stack%s)" % [
		target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
	]
