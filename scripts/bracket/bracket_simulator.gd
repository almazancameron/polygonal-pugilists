class_name BracketSimulator
extends RefCounted

## Plays an off-screen bracket match through the real combat engine, with
## no UI and no pacing, and reports how decisively it went.
##
## Scouting and resolution each call the real engine for eligible off-screen
## matches. Opening character selection scouts all eight first-round matches
## before a player is chosen; resolution then simulates the other seven.
## Later rounds likewise scout and resolve separately. Count these repeated
## calls when measuring cost, rather than counting each match only once.
const MAX_TURNS: int = 200

## Returns {"winner": Familiar, "loser": Familiar, "margin": float,
## "stalemate": bool}. winner/loser are never null: a stalemate nominates
## whichever side held more HP at the turn cap, which produces a small
## margin and therefore near-coin-flip odds.
static func simulate(entrant_a: Familiar, entrant_b: Familiar) -> Dictionary:
	var side_a := Combatant.new(entrant_a)
	var side_b := Combatant.new(entrant_b)
	side_a.opponent = side_b
	side_b.opponent = side_a

	var engine := BattleEngine.new(side_a, side_b)
	var result: Dictionary = engine.run_to_completion(MAX_TURNS)

	# float() on both sides -- integer division would truncate every
	# fraction to 0 (see LEARNING.md's int-division entry).
	var a_pct: float = float(side_a.current_hp) / float(entrant_a.max_hp)
	var b_pct: float = float(side_b.current_hp) / float(entrant_b.max_hp)

	var a_won: bool
	if result.winner == side_a:
		a_won = true
	elif result.winner == side_b:
		a_won = false
	else:
		a_won = a_pct >= b_pct

	if a_won:
		return {
			"winner": entrant_a, "loser": entrant_b,
			"margin": BracketOdds.margin(a_pct, b_pct), "stalemate": result.stalemate,
		}
	return {
		"winner": entrant_b, "loser": entrant_a,
		"margin": BracketOdds.margin(b_pct, a_pct), "stalemate": result.stalemate,
	}
