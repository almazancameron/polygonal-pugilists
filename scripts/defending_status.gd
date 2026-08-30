class_name DefendingStatus
extends Status

## Doubles defense until this combatant is next hit, then removes itself.
## Applied directly by DefendTechnique rather than through a Technique's
## status_effect field, the same way Stagger applies Stun directly.

func status_id() -> StringName:
	return &"defending"

func modify_defense(base_defense: int) -> int:
	return base_defense * 2

func on_hit(target: Combatant) -> String:
	stacks = 0
	return ""

func preview_color() -> Color:
	return Color(0.3, 0.7, 1.0, 1.0)

func icon() -> Texture2D:
	return null  # TODO: no icon asset yet

func describe() -> String:
	return "Doubles defense until this familiar is hit."
