class_name BracketRound
extends Resource

## One round's worth of matches: 8, then 4, then 2, then 1.

@export var matches: Array[BracketMatch] = []

## The match the player is actually fighting this round, or null (rounds
## the player has been eliminated from, or a bracket before selection).
func player_match() -> BracketMatch:
	for bracket_match in matches:
		if bracket_match.is_player_match:
			return bracket_match
	return null

## Everything the player is NOT in -- the set that gets simulated,
## scouted, and rolled off-screen.
func other_matches() -> Array[BracketMatch]:
	var result: Array[BracketMatch] = []
	for bracket_match in matches:
		if not bracket_match.is_player_match:
			result.append(bracket_match)
	return result
