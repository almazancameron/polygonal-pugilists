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

## A copy safe to mutate for one run's worth of build growth.
##
## Resource.duplicate() is NOT enough on its own: it copies scalars by
## value but hands the copy the *same* Array objects the original holds,
## so `copy.techniques.append(...)` also grows the base .tres -- which
## load() caches by path, meaning every later run in the same process
## inherits the previous run's upgrades. Verified empirically, not
## assumed: a duplicate's append raised the base familiar's technique
## count from 2 to 3.
##
## Deliberately NOT duplicate(true) (deep): that would give this copy its
## own Technique/PassiveEffect instances, and RewardSelector decides "do
## I already own this?" by identity against the shared content pool, so
## deep copies would silently make every owned item re-offerable. Fresh
## arrays holding the same element references is exactly the middle
## ground both requirements need.
func duplicate_for_run() -> Familiar:
	var copy: Familiar = duplicate()
	copy.techniques = techniques.duplicate()
	copy.priority_rules = priority_rules.duplicate()
	copy.passives = passives.duplicate()
	copy.species_affinities = species_affinities.duplicate()
	return copy

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