class_name RewardProgression
extends RefCounted

## Owns the authored per-round reward cadence (GAME_DESIGN.md §9.4) --
## the ONLY place round-number logic lives in the reward system.
## RewardSelector never sees a round number at all, so it stays reusable
## by a later AI-drafting/simulation pass that may not have "round" mean
## the same thing.

enum RewardKind { TECHNIQUE, PASSIVE, PASSIVE_TRADE, NONE }

const CADENCE: Array[RewardKind] = [
	RewardKind.TECHNIQUE, RewardKind.PASSIVE, RewardKind.TECHNIQUE, RewardKind.PASSIVE_TRADE,
]

## round_completed counts completed rounds from 1, not the zero-based
## bracket position. The controller passes current_round after advancing to
## the next bracket round, or 4 at the pre-boss reward transition while
## current_round remains 3. Values outside CADENCE return NONE.
static func kind_for_round(round_completed: int) -> RewardKind:
	if round_completed >= 1 and round_completed <= CADENCE.size():
		return CADENCE[round_completed - 1]
	return RewardKind.NONE
