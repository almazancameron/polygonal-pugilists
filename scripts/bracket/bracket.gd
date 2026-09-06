class_name Bracket
extends Resource

## A generated single-elimination tournament: 16 entrants, 4 rounds,
## then a fixed final-boss encounter that sits outside the tree.

const ENTRANT_COUNT: int = 16

@export var rounds: Array[BracketRound] = []
@export var boss_familiar: Familiar

## Builds a full bracket from a 16-entrant roster. rng is injected rather
## than using Array.shuffle() (which reads the unseedable global RNG), so
## a seeded run reproduces the same bracket exactly -- the same reasoning
## RewardSelector already uses for its own draws.
##
## Every entrant is duplicated: builds mutate in place across a run (the
## player's via the reward screen, the AI's via AIDrafter) and load()
## caches .tres by path, so sharing the base objects would corrupt them
## for the rest of the process.
static func generate(roster: Array[Familiar], rng: RandomNumberGenerator, boss: Familiar = null) -> Bracket:
	if roster.size() != ENTRANT_COUNT:
		push_error("Bracket.generate() needs exactly %d entrants, got %d" % [ENTRANT_COUNT, roster.size()])
		return null

	var entrants: Array[Familiar] = []
	for familiar in roster:
		entrants.append(familiar.duplicate())

	# Fisher-Yates against the injected rng.
	for i in range(entrants.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swapped: Familiar = entrants[i]
		entrants[i] = entrants[j]
		entrants[j] = swapped

	var bracket := Bracket.new()
	bracket.boss_familiar = boss

	var first_round := BracketRound.new()
	for i in range(0, entrants.size(), 2):
		var bracket_match := BracketMatch.new()
		bracket_match.entrant_a = entrants[i]
		bracket_match.entrant_b = entrants[i + 1]
		first_round.matches.append(bracket_match)
	bracket.rounds.append(first_round)

	var match_count: int = first_round.matches.size() / 2
	while match_count >= 1:
		var later_round := BracketRound.new()
		for _i in range(match_count):
			later_round.matches.append(BracketMatch.new())
		bracket.rounds.append(later_round)
		match_count = match_count / 2

	return bracket
