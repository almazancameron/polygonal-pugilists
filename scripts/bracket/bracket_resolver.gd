class_name BracketResolver
extends RefCounted

## The two halves of an off-screen round: scouting (simulate, derive odds,
## show them) happens before the player's own fight; resolving (roll
## against those odds, grow the winners, mark revealed) happens after it.
## Split deliberately -- the player sees odds they cannot yet know the
## outcome of, which is the whole point of scouting.

## Simulates every match the player isn't in and records its odds label.
## Deliberately leaves winner/revealed alone: scouting tells the player
## how a match looks, not how it went.
static func scout_round(bracket_round: BracketRound) -> void:
	for bracket_match in bracket_round.other_matches():
		if not bracket_match.is_ready():
			continue

		var simulated: Dictionary = BracketSimulator.simulate(bracket_match.entrant_a, bracket_match.entrant_b)
		var probability: float = BracketOdds.advance_probability(simulated.margin)

		if simulated.winner == bracket_match.entrant_a:
			bracket_match.odds_label = BracketOdds.winner_label(probability)
		else:
			bracket_match.odds_label = BracketOdds.loser_label(probability)

## Rolls every scouted match to its true winner, grows that winner's
## build, and marks it revealed. Returns one summary entry per match so
## the caller can report upsets.
##
## Re-simulates rather than caching the scouted probability: the sim is
## deterministic for a given pair of builds and nothing about those builds
## changes between scouting and resolving, so this reproduces the same
## numbers without needing a second field on BracketMatch to hold them.
static func resolve_round(bracket_round: BracketRound, round_completed: int,
		technique_pool: Array[Technique], passive_pool: Array[PassiveEffect],
		rng: RandomNumberGenerator) -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []

	for bracket_match in bracket_round.other_matches():
		if not bracket_match.is_ready():
			continue

		var simulated: Dictionary = BracketSimulator.simulate(bracket_match.entrant_a, bracket_match.entrant_b)
		var probability: float = BracketOdds.advance_probability(simulated.margin)

		var favored: Familiar = simulated.winner
		var upset: bool = rng.randf() > probability
		var true_winner: Familiar = simulated.loser if upset else favored

		bracket_match.winner = true_winner
		bracket_match.revealed = true

		AIDrafter.apply_round_reward(true_winner, round_completed, technique_pool, passive_pool, rng)

		summaries.append({
			"winner": true_winner,
			"loser": bracket_match.other_entrant(true_winner),
			"was_upset": upset,
		})

	return summaries
