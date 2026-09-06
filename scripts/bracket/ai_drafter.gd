class_name AIDrafter
extends RefCounted

## Placeholder build growth for the 15 AI bracket entrants, so opponents
## are "also accumulating power" (GAME_DESIGN.md §0.2) rather than frozen
## at their starting kit.
##
## Deliberately simple and build-unaware: it reuses the player's own
## reward machinery (RewardProgression's cadence, RewardSelector's Run
## slot) rather than inventing a parallel one, and picks stats by a fixed
## rule. The real system -- drafting personalities plus a shared priority
## optimizer -- is designed separately in
## docs/superpowers/specs/2026-09-06-ai-drafting-design.md and swaps in
## here later without the bracket needing to change.

## Each stat's typical authored range, matching the bounds the session-7
## stat-search pass used (recorded in DECISIONS.md's balance-testing
## entry; the search script itself was a throwaway and is long deleted).
## Needed because the stats are on wildly different scales: picking "the
## lowest stat" by raw value would never once choose max_hp.
const STAT_RANGES: Dictionary = {
	Familiar.Stat.MAX_HP: Vector2(35.0, 85.0),
	Familiar.Stat.POWER: Vector2(2.0, 20.0),
	Familiar.Stat.DEFENSE: Vector2(2.0, 20.0),
	Familiar.Stat.SPEED: Vector2(2.0, 20.0),
	Familiar.Stat.FOCUS: Vector2(2.0, 20.0),
}

## One round's worth of growth: always a stat point, plus whatever
## content this round's cadence calls for.
static func apply_round_reward(familiar: Familiar, round_completed: int,
		technique_pool: Array[Technique], passive_pool: Array[PassiveEffect],
		rng: RandomNumberGenerator) -> void:
	_apply_stat_point(familiar)

	var kind: RewardProgression.RewardKind = RewardProgression.kind_for_round(round_completed)
	match kind:
		RewardProgression.RewardKind.TECHNIQUE:
			_take_technique(familiar, technique_pool, rng)
		RewardProgression.RewardKind.PASSIVE:
			_take_passive(familiar, passive_pool, rng)
		RewardProgression.RewardKind.PASSIVE_TRADE:
			_trade_passive(familiar, passive_pool, rng)
		RewardProgression.RewardKind.NONE:
			pass

## Whichever stat sits lowest within its own typical range -- see
## STAT_RANGES for why this isn't a raw comparison.
static func lowest_stat(familiar: Familiar) -> Familiar.Stat:
	var best_stat: Familiar.Stat = Familiar.Stat.MAX_HP
	var best_fraction: float = 2.0

	for stat in STAT_RANGES:
		var bounds: Vector2 = STAT_RANGES[stat]
		var current: float = float(_stat_value(familiar, stat))
		var fraction: float = (current - bounds.x) / (bounds.y - bounds.x)
		if fraction < best_fraction:
			best_fraction = fraction
			best_stat = stat

	return best_stat

static func _apply_stat_point(familiar: Familiar) -> void:
	var upgrade := ModifyStatUpgrade.new()
	upgrade.stat = lowest_stat(familiar)
	upgrade.bonus = 1
	upgrade.apply(familiar)

## The Run slot specifically: it's the one scored against what the build
## already owns, which is the closest thing to a judgment call an AI can
## make without a real personality system.
static func _take_technique(familiar: Familiar, pool: Array[Technique], rng: RandomNumberGenerator) -> void:
	var snapshot: BuildSnapshot = BuildSnapshot.compute(familiar)
	var pick = RewardSelector.pick_candidate(
		RewardSelector.RewardSlot.RUN, familiar, snapshot, pool, familiar.techniques, rng)
	if pick == null:
		return

	var upgrade := AddTechniqueUpgrade.new()
	upgrade.technique = pick
	upgrade.apply(familiar)

static func _take_passive(familiar: Familiar, pool: Array[PassiveEffect], rng: RandomNumberGenerator) -> void:
	var snapshot: BuildSnapshot = BuildSnapshot.compute(familiar)
	var pick = RewardSelector.pick_candidate(
		RewardSelector.RewardSlot.RUN, familiar, snapshot, pool, familiar.passives, rng)
	if pick == null:
		return

	var upgrade := AddPassiveUpgrade.new()
	upgrade.passive = pick
	upgrade.apply(familiar)

## Sacrifice the oldest passive for a fresh pick -- the AI's stand-in for
## the player's trade screen. Scored against the build as it will be
## *after* the sacrifice, the same way RewardFlowController does it.
static func _trade_passive(familiar: Familiar, pool: Array[PassiveEffect], rng: RandomNumberGenerator) -> void:
	if familiar.passives.is_empty():
		_take_passive(familiar, pool, rng)
		return

	var sacrificed: PassiveEffect = familiar.passives[0]
	var snapshot: BuildSnapshot = BuildSnapshot.compute(familiar, [sacrificed])
	var pick = RewardSelector.pick_candidate(
		RewardSelector.RewardSlot.RUN, familiar, snapshot, pool, familiar.passives, rng)
	if pick == null:
		return

	familiar.passives.erase(sacrificed)
	var upgrade := AddPassiveUpgrade.new()
	upgrade.passive = pick
	upgrade.apply(familiar)

static func _stat_value(familiar: Familiar, stat: Familiar.Stat) -> int:
	match stat:
		Familiar.Stat.MAX_HP:
			return familiar.max_hp
		Familiar.Stat.POWER:
			return familiar.power
		Familiar.Stat.DEFENSE:
			return familiar.defense
		Familiar.Stat.SPEED:
			return familiar.speed
		Familiar.Stat.FOCUS:
			return familiar.focus
	return 0
