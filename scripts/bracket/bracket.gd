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
## Every entrant goes through duplicate_for_run(), not a plain
## duplicate(): builds mutate in place across a run (the player's via the
## reward screen, the AI's via AIDrafter) and load() caches .tres by path,
## and a plain duplicate() shares its Array properties with the original
## -- see Familiar.duplicate_for_run() for why that isn't enough.
static func generate(roster: Array[Familiar], rng: RandomNumberGenerator, boss: Familiar = null) -> Bracket:
	if roster.size() != ENTRANT_COUNT:
		push_error("Bracket.generate() needs exactly %d entrants, got %d" % [ENTRANT_COUNT, roster.size()])
		return null

	var entrants: Array[Familiar] = []
	for familiar in roster:
		entrants.append(familiar.duplicate_for_run())

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

## Feeds a resolved round's winners into the next round. Standard
## single-elimination pairing: this round's match 2k supplies next
## round's match k's entrant_a, match 2k+1 supplies its entrant_b.
## Expressed from the source side (walk this round, write forward), which
## keeps the caller from having to know the pairing rule at all.
func advance_round(round_index: int) -> void:
	if round_index < 0 or round_index >= rounds.size() - 1:
		push_error("advance_round(%d) has no following round to fill" % round_index)
		return

	var current: BracketRound = rounds[round_index]
	var next: BracketRound = rounds[round_index + 1]

	for i in range(current.matches.size()):
		var source: BracketMatch = current.matches[i]
		if source.winner == null:
			push_error("advance_round(%d): match %d has no winner yet" % [round_index, i])
			continue

		var target: BracketMatch = next.matches[i / 2]
		if i % 2 == 0:
			target.entrant_a = source.winner
		else:
			target.entrant_b = source.winner
