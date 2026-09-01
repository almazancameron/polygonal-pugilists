class_name BleedStatus
extends Status

## Stacking status with no per-tick effect. Instead, each hit this target
## takes consumes one stack and deals bonus damage equal to the stacks it
## had *before* that stack was consumed -- see on_hit().

func status_id() -> StringName:
	return &"bleed"

func on_hit(target: Combatant, _attacker: Combatant) -> String:
	if stacks <= 0:
		return ""

	var damage: int = target.take_damage(stacks)
	stacks -= 1

	return "%s's wound is aggravated, dealing %d bonus bleed damage! (%d stacks remain)" % [
		target.familiar.familiar_name, damage, stacks
	]

func preview_color() -> Color:
	return Color(0.75, 0.0, 0.0, 1.0)

func icon() -> Texture2D:
	return preload("res://assets/sprites/icons/bleed_icon.tres")

func describe() -> String:
	return ("Consumes a stack to deal %d damage (equal to the number of stacks)\n" + 
	"when the target is hit.") % [stacks]

func on_applied(target: Combatant) -> String:
	return "%s is bleeding! (%d stack%s)" % [
		target.familiar.familiar_name, stacks, "s" if stacks != 1 else ""
	]