class_name RewardFlowController
extends RefCounted

## Orchestrates one reward-screen "session" for the post-round loop: owns
## the RNG instance, the current cadence/pool/snapshot for whichever round
## is active, the 3 slots' current candidates, the shared reroll charges,
## and the stat-allocation state for Phase A. battle_controller.gd stays
## UI glue only -- it reflects this object's state into visible nodes and
## calls back into it on every button press; RewardProgression/
## RewardSelector stay pure and untouched by any of this session state
## (mirrors how battle_controller.gd already delegates turn/upkeep
## resolution to BattleEngine rather than owning that logic itself).

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## -- Phase B (reward cards) session state --
var current_kind: RewardProgression.RewardKind = RewardProgression.RewardKind.NONE
var rerolls_remaining: int = 0
var _shown_this_screen: Array = []  # seeded with owned content -- see begin_reward_screen()
var _slot_candidates: Dictionary = {}  # RewardSelector.RewardSlot -> UpgradeOption
var _active_pool: Array = []
var _active_snapshot: BuildSnapshot

## -- Passive-trade sub-state (PASSIVE_TRADE rounds only) --
var passive_to_remove: PassiveEffect = null

## -- Phase A (stat allocation) session state --
var available_points: int = 0
var allocated: Dictionary = {}  # Familiar.Stat -> int

func seed_rng(seed_value: int) -> void:
	rng.seed = seed_value

func randomize_rng() -> void:
	rng.randomize()

## ---- Phase A: stat allocation ----

func begin_stat_phase(points: int) -> void:
	available_points = points
	allocated = {}

## +1 only succeeds while points remain; -1 only succeeds while this
## invocation has actually allocated a point to that stat -- "+ grayed
## out with no upgrades left, - grayed out until that stat has received
## one this round." Nothing is written to a Familiar here -- allocation
## is staged, transient state until confirm_stat_phase().
func try_allocate(stat: Familiar.Stat, delta: int) -> bool:
	if delta > 0:
		if available_points <= 0:
			return false
		available_points -= 1
		allocated[stat] = allocated.get(stat, 0) + 1
		return true
	elif delta < 0:
		if allocated.get(stat, 0) <= 0:
			return false
		allocated[stat] -= 1
		available_points += 1
		return true
	return false

## Applies every accumulated allocation via that stat's own
## ModifyStatUpgrade.apply() (looked up from stat_upgrade_pool, one entry
## expected per Familiar.Stat value), then clears the allocation state.
func confirm_stat_phase(familiar: Familiar, stat_upgrade_pool: Array) -> void:
	for stat in allocated.keys():
		var count: int = allocated[stat]
		if count <= 0:
			continue
		var upgrade: ModifyStatUpgrade = _find_stat_upgrade(stat_upgrade_pool, stat)
		if upgrade == null:
			continue
		for i in range(count):
			upgrade.apply(familiar)

	allocated = {}
	available_points = 0

func _find_stat_upgrade(pool: Array, stat: Familiar.Stat) -> ModifyStatUpgrade:
	for upgrade in pool:
		if upgrade.stat == stat:
			return upgrade
	return null

## ---- Phase B: reward cards ----

## Starts a fresh reward screen for the round just completed. Returns the
## cadence kind so the caller knows which UI path to show (3 cards right
## away, or the sacrifice screen first for PASSIVE_TRADE). Populates the
## 3 slots immediately for every kind except PASSIVE_TRADE, which waits
## on resolve_sacrifice() first, and NONE, which offers nothing.
func begin_reward_screen(round_completed: int, familiar: Familiar,
		technique_pool: Array, passive_pool: Array) -> RewardProgression.RewardKind:
	current_kind = RewardProgression.kind_for_round(round_completed)
	rerolls_remaining = 3
	_slot_candidates = {}
	passive_to_remove = null

	# Seeded with everything already owned, not just what gets shown this
	# screen -- this is how "never offer a duplicate of owned content" and
	# "never repeat a candidate already shown this screen" collapse into
	# one exclusion list instead of two separate checks.
	_shown_this_screen = []
	_shown_this_screen.append_array(familiar.techniques)
	_shown_this_screen.append_array(familiar.passives)

	match current_kind:
		RewardProgression.RewardKind.TECHNIQUE:
			_active_pool = technique_pool
			_active_snapshot = BuildSnapshot.compute(familiar)
			_populate_all_slots(familiar, _wrap_technique)
		RewardProgression.RewardKind.PASSIVE:
			_active_pool = passive_pool
			_active_snapshot = BuildSnapshot.compute(familiar)
			_populate_all_slots(familiar, _wrap_passive)
		RewardProgression.RewardKind.PASSIVE_TRADE:
			_active_pool = passive_pool
			# Slots stay empty until resolve_sacrifice() runs.
		RewardProgression.RewardKind.NONE:
			pass

	return current_kind

func sacrifice_options(familiar: Familiar) -> Array:
	return familiar.passives.duplicate()

## Called once the player picks which held passive to give up on the
## sacrifice screen (PASSIVE_TRADE rounds only). Computes the Run/Pivot
## snapshot as if that passive is already gone -- tailoring the
## replacement search on a profile that still counts an already-abandoned
## passive would recommend "more of what you just quit." The actual
## familiar.passives.erase() still only happens later, on confirm
## (TradePassiveUpgrade.apply()).
func resolve_sacrifice(sacrificed: PassiveEffect, familiar: Familiar) -> void:
	passive_to_remove = sacrificed
	_active_snapshot = BuildSnapshot.compute(familiar, [sacrificed])
	_populate_all_slots(familiar, _wrap_trade)

func _populate_all_slots(familiar: Familiar, wrap: Callable) -> void:
	for slot in [RewardSelector.RewardSlot.SPECIES, RewardSelector.RewardSlot.RUN, RewardSelector.RewardSlot.PIVOT]:
		_populate_slot(slot, familiar, wrap)

func _populate_slot(slot: RewardSelector.RewardSlot, familiar: Familiar, wrap: Callable) -> void:
	var content = RewardSelector.pick_candidate(slot, familiar, _active_snapshot, _active_pool, _shown_this_screen, rng)
	if content == null:
		_slot_candidates.erase(slot)
		return
	_shown_this_screen.append(content)
	_slot_candidates[slot] = wrap.call(content)

## Rerolls exactly one slot, spending one of the shared charges. No-op
## (returns false, spends nothing) if no charges remain or nothing unseen
## is left to draw for the currently active pool.
func reroll_slot(slot: RewardSelector.RewardSlot, familiar: Familiar) -> bool:
	if rerolls_remaining <= 0:
		return false

	var wrap: Callable
	match current_kind:
		RewardProgression.RewardKind.TECHNIQUE:
			wrap = _wrap_technique
		RewardProgression.RewardKind.PASSIVE:
			wrap = _wrap_passive
		RewardProgression.RewardKind.PASSIVE_TRADE:
			wrap = _wrap_trade
		_:
			return false

	var content = RewardSelector.pick_candidate(slot, familiar, _active_snapshot, _active_pool, _shown_this_screen, rng)
	if content == null:
		return false

	rerolls_remaining -= 1
	_shown_this_screen.append(content)
	_slot_candidates[slot] = wrap.call(content)
	return true

## Whether anything unseen remains for the active pool at all -- checked
## before offering a slot's reroll, since eligibility (unlike weighting)
## doesn't depend on which slot is asking.
func has_unseen_candidates() -> bool:
	for item in _active_pool:
		if item not in _shown_this_screen:
			return true
	return false

func candidate_for_slot(slot: RewardSelector.RewardSlot) -> UpgradeOption:
	return _slot_candidates.get(slot)

func _wrap_technique(technique: Technique) -> AddTechniqueUpgrade:
	var upgrade := AddTechniqueUpgrade.new()
	upgrade.technique = technique
	upgrade.label = "Learn %s" % technique.technique_name
	return upgrade

func _wrap_passive(passive: PassiveEffect) -> AddPassiveUpgrade:
	var upgrade := AddPassiveUpgrade.new()
	upgrade.passive = passive
	upgrade.label = "Gain %s" % passive.passive_name
	return upgrade

func _wrap_trade(passive: PassiveEffect) -> TradePassiveUpgrade:
	var upgrade := TradePassiveUpgrade.new()
	upgrade.new_passive = passive
	upgrade.passive_to_remove = passive_to_remove
	upgrade.label = "Trade for %s" % passive.passive_name
	return upgrade
