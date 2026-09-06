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

## round_completed is 1-indexed (battle_controller.gd's current_round,
## read right after it increments in start_next_round() -- "how many
## rounds have been completed so far"). Past the authored cadence,
## returns NONE explicitly -- prize-fight/extra-round rewards are a
## separate, not-yet-decided future task, not something this silently
## improvises by repeating or wrapping the cadence.
static func kind_for_round(round_completed: int) -> RewardKind:
	if round_completed >= 1 and round_completed <= CADENCE.size():
		return CADENCE[round_completed - 1]
	return RewardKind.NONE
