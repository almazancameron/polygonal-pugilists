class_name UpgradeOption
extends Resource

## One offer on the post-round upgrade-choice screen. A familiar's build
## grows by applying one of these after each non-final round. Subclassed
## per upgrade kind -- "add a technique" and "boost a stat" are genuinely
## different operations, not the same shape with different constants.

@export var label: String = "Upgrade"
@export var unique: bool = true  # If true, this upgrade is removed from the upgrade pool after being applied.

## Describes what this upgrade does, for display on the choice screen.
## Override in subclasses that want a more specific message than the
## plain label.
func describe() -> String:
	return label

## Applies this upgrade's effect to the familiar. Override in subclasses.
func apply(familiar: Familiar) -> void:
	pass
