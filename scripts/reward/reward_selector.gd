class_name RewardSelector
extends RefCounted

## Weighted selection for Species/Run/Pivot rewards. Reads the current run
## Familiar, BuildSnapshot, content pool and RNG without mutating the build;
## no Combatant, UI or scene tree is required.
##
## BASE_WEIGHT is the starting weight, not a lower bound. Relevance adjusts
## it, and MIN_SAFETY_WEIGHT keeps every eligible candidate pickable even
## when Pivot's overlap penalty pushes it below baseline. With no tag or
## role contributions, candidates have equal weights within a slot.
enum RewardSlot { SPECIES, RUN, PIVOT }

## Tunable per slot independently; equal is just a starting default.
const BASE_WEIGHT: Dictionary = {
	RewardSlot.SPECIES: 5.0,
	RewardSlot.RUN: 5.0,
	RewardSlot.PIVOT: 5.0,
}

## Positive floor for the final draw weight, including when Pivot's penalty
## pushes BASE_WEIGHT + relevance below zero.
const MIN_SAFETY_WEIGHT: float = 0.1

const TAG_REPEAT_WEIGHT: float = 1.0
const PIVOT_BONUS: float = 2.0
const PIVOT_PENALTY: float = 1.0
const PIVOT_PEAK: float = 2.0

## pool: Array[Technique] or Array[PassiveEffect] (whichever this round's
## RewardProgression.RewardKind calls for). excluded_content: already-
## owned + already-shown-this-screen items, filtered out of the eligible
## set entirely (not merely down-weighted). Returns null if nothing
## eligible remains.
static func pick_candidate(slot: RewardSlot, familiar: Familiar, snapshot: BuildSnapshot,
		pool: Array, excluded_content: Array, rng: RandomNumberGenerator) -> Variant:
	var eligible: Array = pool.filter(func(c): return c not in excluded_content)
	if eligible.is_empty():
		return null

	var weights: Array[float] = []
	for candidate in eligible:
		weights.append(_weight_for(slot, candidate, familiar, snapshot))

	return _weighted_pick(eligible, weights, rng)

static func _weight_for(slot: RewardSlot, candidate, familiar: Familiar, snapshot: BuildSnapshot) -> float:
	var bonus: float = 0.0
	match slot:
		RewardSlot.SPECIES:
			bonus = _species_relevance(candidate, familiar)
		RewardSlot.RUN:
			bonus = _run_relevance(candidate, snapshot)
		RewardSlot.PIVOT:
			bonus = _pivot_relevance(_pivot_overlap(candidate, familiar, snapshot))
	return max(MIN_SAFETY_WEIGHT, BASE_WEIGHT[slot] + bonus)

static func _species_relevance(candidate, familiar: Familiar) -> float:
	var total: float = 0.0
	for affinity in familiar.species_affinities:
		if affinity.tag in candidate.tags:
			total += affinity.weight
	return total

static func _run_relevance(candidate, snapshot: BuildSnapshot) -> float:
	var tag_total: float = 0.0
	for tag in candidate.tags:
		tag_total += snapshot.owned_tag_counts.get(tag, 0)

	var role_total: float = 0.0
	role_total += candidate.role_offense * _deficiency_factor(snapshot.owned_role_totals["offense"])
	role_total += candidate.role_defense * _deficiency_factor(snapshot.owned_role_totals["defense"])
	role_total += candidate.role_sustain * _deficiency_factor(snapshot.owned_role_totals["sustain"])
	role_total += candidate.role_control * _deficiency_factor(snapshot.owned_role_totals["control"])

	return TAG_REPEAT_WEIGHT * tag_total + role_total

## Smooth, never-zero, monotonically-decreasing curve: full bonus per
## point at 0 current investment, shrinking (but never to a hard
## exclusion) as a role fills up. Exact curve shape is a tuning choice,
## not architecture -- swapping it touches only this function.
static func _deficiency_factor(current_total: int) -> float:
	return 1.0 / (1.0 + current_total)

static func _pivot_overlap(candidate, familiar: Familiar, snapshot: BuildSnapshot) -> float:
	var overlap: float = 0.0
	for tag in candidate.tags:
		overlap += snapshot.owned_tag_counts.get(tag, 0)
	for affinity in familiar.species_affinities:
		if affinity.tag in candidate.tags:
			overlap += affinity.weight
	return overlap

## A simple rise-then-fall (inverted-U) shape: near-zero overlap keeps
## this near zero (candidate's final weight is essentially just
## BASE_WEIGHT[PIVOT] -- still pickable, doesn't dominate); overlap near
## PIVOT_PEAK gives the highest bonus ("a little relevant, a little
## strange"); overlap climbing well past that goes negative, pulling a
## heavily-on-theme candidate's Pivot weight down, potentially below baseline --
## "just another on-theme pick," not novel.
static func _pivot_relevance(overlap: float) -> float:
	return PIVOT_BONUS * min(overlap, PIVOT_PEAK) - PIVOT_PENALTY * max(0.0, overlap - PIVOT_PEAK)

static func _weighted_pick(candidates: Array, weights: Array[float], rng: RandomNumberGenerator) -> Variant:
	var total: float = 0.0
	for weight in weights:
		total += weight

	var roll: float = rng.randf() * total
	var cumulative: float = 0.0
	for i in range(candidates.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return candidates[i]

	return candidates[-1]  # float-rounding safety net
