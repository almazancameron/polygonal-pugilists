class_name ModifyStatUpgrade
extends UpgradeOption

## Grants a bonus to a particular stat. The bonus is applied to the familiar's base stat,
## so it persists across rounds and is not affected by temporary stat changes

@export var stat: Familiar.Stat = Familiar.Stat.MAX_HP
@export var bonus: int = 1

func apply(familiar: Familiar) -> void:
	match stat:
		Familiar.Stat.MAX_HP:
			familiar.max_hp += bonus
		Familiar.Stat.POWER:
			familiar.power += bonus
		Familiar.Stat.DEFENSE:
			familiar.defense += bonus
		Familiar.Stat.SPEED:
			familiar.speed += bonus
		Familiar.Stat.FOCUS:
			familiar.focus += bonus

func describe() -> String:
	return "%screase %s by %d" % ["In" if bonus > 0 else "De", Familiar.stat_name(stat), abs(bonus)]

func _init() -> void:
	unique = false  # the player can choose the same stat upgrade multiple times
