class_name Familiar
extends Resource

## A familiar's build: static stats authored in the Inspector and saved as a
## .tres file. Used identically for the player's familiar and any opponent.

enum Stat { MAX_HP, POWER, DEFENSE, SPEED, FOCUS }

@export var familiar_name: String = "Familiar"
@export var sprite: Texture2D
@export var max_hp: int = 50
@export var power: int = 10
@export var defense: int = 5
@export var speed: int = 10
@export var focus: int = 10
@export var techniques: Array[Technique] = []
@export var priority_rules: Array[PriorityRule] = []
@export var passives: Array[PassiveEffect] = []
@export var focus_table: FocusTable

## How much Focus each breakpoint tier requires (tier * focus_step_size),
## read fresh by FocusBreakpointCondition rather than baked into each
## breakpoint's own threshold -- lets a future passive that changes this
## value (e.g. "your Focus breakpoints land at steps of 4 instead of 5")
## retroactively reshape every breakpoint's actual threshold at once.
@export var focus_step_size: int = 5

## This species' reward-tailoring identity -- weighted tags consulted
## only by the Species reward slot (scripts/reward/reward_selector.gd),
## e.g. Ashwing might weight BURN heavily and TARGET_STATUS lightly.
## Deliberately never read by the Run slot, which tracks currently-
## equipped techniques/passives instead -- see BuildSnapshot.
@export var species_affinities: Array[TagAffinity] = []

## Human-readable display name for a Stat value -- used by upgrade
## descriptions rather than exposing the raw enum name or property name.
static func stat_name(stat: Stat) -> String:
	match stat:
		Stat.MAX_HP:
			return "Max HP"
		Stat.POWER:
			return "Power"
		Stat.DEFENSE:
			return "Defense"
		Stat.SPEED:
			return "Speed"
		Stat.FOCUS:
			return "Focus"
		_:
			return "Stat"

func get_stat(stat: Stat) -> int:
	match stat:
		Stat.MAX_HP:
			return max_hp
		Stat.POWER:
			return power
		Stat.DEFENSE:
			return defense
		Stat.SPEED:
			return speed
		Stat.FOCUS:
			return focus
		_:
			return 0