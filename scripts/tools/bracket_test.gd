extends SceneTree

## Re-runnable bracket regression harness. Run with:
##   godot --headless --script res://scripts/tools/bracket_test.gd
##
## Every check calls _done() as its last line, and _report() fails if any
## expected check never completed -- a GDScript runtime error aborts only
## the function it happens in, so without completion markers a crashed
## check silently reports as a pass (see DEVLOG.md session 5).

const FAMILIARS_DIR := "res://resources/familiars/"

const EXPECTED_CHECKS: Array[String] = [
	"generate_shape",
	"generate_entrants_distinct",
	"generate_is_deterministic_per_seed",
	"generate_rejects_wrong_roster_size",
	"advance_round_pairs_winners",
	"advance_through_all_rounds",
	"odds_boundaries",
	"simulate_produces_winner_and_margin",
	"ai_drafter_grows_a_build",
	"resolver_scouts_and_resolves",
	"entrants_are_isolated_from_base_resources",
]

var _failures: Array[String] = []
var _completed: Array[String] = []

func _init() -> void:
	_check_generate_shape()
	_check_generate_entrants_distinct()
	_check_generate_is_deterministic_per_seed()
	_check_generate_rejects_wrong_roster_size()
	_check_advance_round_pairs_winners()
	_check_advance_through_all_rounds()
	_check_odds_boundaries()
	_check_simulate_produces_winner_and_margin()
	_check_ai_drafter_grows_a_build()
	_check_resolver_scouts_and_resolves()
	_check_entrants_are_isolated_from_base_resources()
	_report()

func _check_generate_shape() -> void:
	var bracket: Bracket = Bracket.generate(_roster(), _rng(1))
	_expect(bracket != null, "generate() returned null for a valid 16-entrant roster")
	_expect(bracket.rounds.size() == 4, "expected 4 rounds, got %d" % bracket.rounds.size())
	var expected_counts: Array[int] = [8, 4, 2, 1]
	for i in range(expected_counts.size()):
		_expect(bracket.rounds[i].matches.size() == expected_counts[i],
			"round %d should hold %d matches, held %d" % [i, expected_counts[i], bracket.rounds[i].matches.size()])
	for bracket_match in bracket.rounds[0].matches:
		_expect(bracket_match.is_ready(), "every round-1 match should have both entrants")
	for i in range(1, bracket.rounds.size()):
		for bracket_match in bracket.rounds[i].matches:
			_expect(not bracket_match.is_ready(), "round %d matches should start empty" % i)
	_done("generate_shape")

func _check_generate_entrants_distinct() -> void:
	var bracket: Bracket = Bracket.generate(_roster(), _rng(2))
	var seen: Array[String] = []
	for bracket_match in bracket.rounds[0].matches:
		for entrant in [bracket_match.entrant_a, bracket_match.entrant_b]:
			_expect(entrant != null, "round-1 entrant was null")
			_expect(entrant.familiar_name not in seen, "entrant %s appeared twice" % entrant.familiar_name)
			seen.append(entrant.familiar_name)
	_expect(seen.size() == Bracket.ENTRANT_COUNT, "expected %d entrants, saw %d" % [Bracket.ENTRANT_COUNT, seen.size()])
	_done("generate_entrants_distinct")

func _check_generate_is_deterministic_per_seed() -> void:
	var first: Bracket = Bracket.generate(_roster(), _rng(99))
	var second: Bracket = Bracket.generate(_roster(), _rng(99))
	for i in range(first.rounds[0].matches.size()):
		_expect(first.rounds[0].matches[i].entrant_a.familiar_name == second.rounds[0].matches[i].entrant_a.familiar_name,
			"same seed produced different pairings at match %d" % i)
	_done("generate_is_deterministic_per_seed")

func _check_generate_rejects_wrong_roster_size() -> void:
	var short_roster: Array[Familiar] = _roster().slice(0, 4)
	var bracket: Bracket = Bracket.generate(short_roster, _rng(3))
	_expect(bracket == null, "generate() should return null for a roster that isn't exactly 16")
	_done("generate_rejects_wrong_roster_size")

func _check_advance_round_pairs_winners() -> void:
	var bracket: Bracket = Bracket.generate(_roster(), _rng(7))

	# Every round-1 match resolves to entrant_a, so the expected round-2
	# pairing is (match0.a vs match1.a), (match2.a vs match3.a), ...
	for bracket_match in bracket.rounds[0].matches:
		bracket_match.winner = bracket_match.entrant_a

	bracket.advance_round(0)

	for k in range(bracket.rounds[1].matches.size()):
		var target: BracketMatch = bracket.rounds[1].matches[k]
		var expected_a: Familiar = bracket.rounds[0].matches[2 * k].winner
		var expected_b: Familiar = bracket.rounds[0].matches[2 * k + 1].winner
		_expect(target.entrant_a == expected_a,
			"round-2 match %d entrant_a should be round-1 match %d's winner" % [k, 2 * k])
		_expect(target.entrant_b == expected_b,
			"round-2 match %d entrant_b should be round-1 match %d's winner" % [k, 2 * k + 1])
		_expect(target.is_ready(), "round-2 match %d should be ready after advancing" % k)
	_done("advance_round_pairs_winners")

func _check_advance_through_all_rounds() -> void:
	var bracket: Bracket = Bracket.generate(_roster(), _rng(8))

	# Walk all three transitions, always advancing entrant_a, so the final
	# should end up holding the very first match's entrant_a.
	var expected_finalist: Familiar = bracket.rounds[0].matches[0].entrant_a

	for round_index in range(bracket.rounds.size()):
		for bracket_match in bracket.rounds[round_index].matches:
			_expect(bracket_match.is_ready(), "round %d should be fully populated before resolving" % round_index)
			bracket_match.winner = bracket_match.entrant_a
		if round_index < bracket.rounds.size() - 1:
			bracket.advance_round(round_index)

	var final_match: BracketMatch = bracket.rounds[3].matches[0]
	_expect(final_match.winner == expected_finalist,
		"advancing entrant_a every round should carry match 0's entrant_a to the final")
	_done("advance_through_all_rounds")

func _check_odds_boundaries() -> void:
	_expect(is_equal_approx(BracketOdds.margin(1.0, 0.0), 1.0), "a full-HP win over a dead opponent is margin 1.0")
	_expect(is_equal_approx(BracketOdds.margin(0.05, 0.0), 0.05), "a razor-thin win is a small margin")
	_expect(is_equal_approx(BracketOdds.margin(0.2, 0.9), 0.0), "margin never goes negative")

	_expect(is_equal_approx(BracketOdds.advance_probability(0.0), 0.5), "margin 0 is a coin flip")
	_expect(is_equal_approx(BracketOdds.advance_probability(1.0), 1.0), "margin 1 is a lock")
	_expect(is_equal_approx(BracketOdds.advance_probability(0.5), 0.75), "margin 0.5 is 75%")

	_expect(BracketOdds.winner_label(0.95) == "Heavy Favorite", "0.95 is a heavy favorite")
	_expect(BracketOdds.winner_label(0.90) == "Heavy Favorite", "0.90 is the heavy-favorite boundary")
	_expect(BracketOdds.winner_label(0.80) == "Favorite", "0.80 is a favorite")
	_expect(BracketOdds.winner_label(0.70) == "Favorite", "0.70 is the favorite boundary")
	_expect(BracketOdds.winner_label(0.69) == "Toss-up", "just under 0.70 is a toss-up")
	_expect(BracketOdds.winner_label(0.50) == "Toss-up", "an even match is a toss-up")

	_expect(BracketOdds.loser_label(0.95) == "Heavy Underdog", "the other side of a heavy favorite")
	_expect(BracketOdds.loser_label(0.80) == "Underdog", "the other side of a favorite")
	_expect(BracketOdds.loser_label(0.50) == "Toss-up", "both sides of an even match read the same")
	_done("odds_boundaries")

func _check_simulate_produces_winner_and_margin() -> void:
	var roster: Array[Familiar] = _roster()
	var a: Familiar = roster[0]
	var b: Familiar = roster[1]

	var result: Dictionary = BracketSimulator.simulate(a, b)

	_expect(result.winner != null, "simulate() must always name a winner, even on a stalemate")
	_expect(result.loser != null, "simulate() must always name a loser")
	_expect(result.winner != result.loser, "winner and loser must differ")
	_expect(result.winner == a or result.winner == b, "winner must be one of the two entrants")
	_expect(result.margin >= 0.0 and result.margin <= 1.0, "margin must be 0..1, got %f" % result.margin)

	# The real entrants must be untouched -- simulate() runs on Combatants
	# built from them, and must never mutate the Familiar resources.
	_expect(a.max_hp > 0 and b.max_hp > 0, "simulate() must not damage the source familiars")
	_done("simulate_produces_winner_and_margin")

func _check_ai_drafter_grows_a_build() -> void:
	var roster: Array[Familiar] = _roster()
	var familiar: Familiar = roster[0].duplicate_for_run()
	var technique_count_before: int = familiar.techniques.size()
	var stat_total_before: int = familiar.max_hp + familiar.power + familiar.defense + familiar.speed + familiar.focus

	var technique_pool: Array[Technique] = []
	for other in roster:
		for technique in other.techniques:
			if technique not in technique_pool:
				technique_pool.append(technique)

	var passive_pool: Array[PassiveEffect] = []
	for other in roster:
		for passive in other.passives:
			if passive not in passive_pool:
				passive_pool.append(passive)

	AIDrafter.apply_round_reward(familiar, 1, technique_pool, passive_pool, _rng(11))

	_expect(familiar.techniques.size() == technique_count_before + 1,
		"round 1's cadence is TECHNIQUE, so the AI should have gained one")
	var stat_total_after: int = familiar.max_hp + familiar.power + familiar.defense + familiar.speed + familiar.focus
	_expect(stat_total_after > stat_total_before, "the AI should also have spent its stat point")

	# max_hp must be reachable: comparing raw values would never pick it
	# (it runs 35-85 while the others run 2-20), so the rule compares each
	# stat's fraction of its own range instead.
	var hp_starved: Familiar = roster[0].duplicate_for_run()
	hp_starved.max_hp = 35
	hp_starved.power = 20
	hp_starved.defense = 20
	hp_starved.speed = 20
	hp_starved.focus = 20
	_expect(AIDrafter.lowest_stat(hp_starved) == Familiar.Stat.MAX_HP,
		"a familiar at the bottom of the HP range with everything else maxed should get HP")
	_done("ai_drafter_grows_a_build")

func _check_resolver_scouts_and_resolves() -> void:
	var bracket: Bracket = Bracket.generate(_roster(), _rng(21))
	bracket.rounds[0].matches[0].is_player_match = true

	BracketResolver.scout_round(bracket.rounds[0])

	_expect(bracket.rounds[0].matches[0].odds_label == "",
		"the player's own match should never be scouted")
	for bracket_match in bracket.rounds[0].other_matches():
		_expect(bracket_match.odds_label != "", "every off-screen match should be scouted")
		_expect(not bracket_match.revealed, "scouting must not resolve a match")
		_expect(bracket_match.winner == null, "scouting must not pick a winner")

	var technique_pool: Array[Technique] = []
	var passive_pool: Array[PassiveEffect] = []
	for other in _roster():
		for technique in other.techniques:
			if technique not in technique_pool:
				technique_pool.append(technique)
		for passive in other.passives:
			if passive not in passive_pool:
				passive_pool.append(passive)

	var results: Array[Dictionary] = BracketResolver.resolve_round(
		bracket.rounds[0], 1, technique_pool, passive_pool, _rng(22))

	_expect(results.size() == 7, "7 off-screen matches should resolve, got %d" % results.size())
	for bracket_match in bracket.rounds[0].other_matches():
		_expect(bracket_match.revealed, "every off-screen match should be revealed after resolving")
		_expect(bracket_match.winner != null, "every resolved match needs a winner")
		_expect(bracket_match.has_entrant(bracket_match.winner), "the winner must be one of the entrants")
	_done("resolver_scouts_and_resolves")

## A run's build growth must not reach the cached base .tres. Resource
## .duplicate() alone does NOT achieve this -- it hands the copy the same
## Array objects, so an append grows the original too, and every later
## run in the same process inherits the last one's upgrades. Regression
## guard for a real bug: restarting after a defeat left every familiar
## carrying the previous run's techniques.
func _check_entrants_are_isolated_from_base_resources() -> void:
	var roster: Array[Familiar] = _roster()
	var base: Familiar = roster[0]
	var base_techniques: int = base.techniques.size()
	var base_passives: int = base.passives.size()
	var base_rules: int = base.priority_rules.size()
	var base_name: String = base.familiar_name

	var bracket: Bracket = Bracket.generate(roster, _rng(31))
	for bracket_match in bracket.rounds[0].matches:
		for entrant in [bracket_match.entrant_a, bracket_match.entrant_b]:
			if entrant.familiar_name != base_name:
				continue
			entrant.techniques.append(load("res://resources/techniques/body_press.tres"))
			entrant.passives.append(load("res://resources/passives/gavel_drop.tres"))
			entrant.priority_rules.append(load("res://resources/priority_rules/mallegrav_wind_up_rule.tres"))

	_expect(base.techniques.size() == base_techniques,
		"a bracket entrant's techniques leaked into the base .tres (%d -> %d)" % [base_techniques, base.techniques.size()])
	_expect(base.passives.size() == base_passives,
		"a bracket entrant's passives leaked into the base .tres (%d -> %d)" % [base_passives, base.passives.size()])
	_expect(base.priority_rules.size() == base_rules,
		"a bracket entrant's priority_rules leaked into the base .tres (%d -> %d)" % [base_rules, base.priority_rules.size()])

	# The end-to-end symptom: a second run must hand out pristine entrants.
	var second: Bracket = Bracket.generate(roster, _rng(32))
	for bracket_match in second.rounds[0].matches:
		for entrant in [bracket_match.entrant_a, bracket_match.entrant_b]:
			if entrant.familiar_name == base_name:
				_expect(entrant.techniques.size() == base_techniques,
					"a second run's %s still carried the first run's upgrades" % base_name)
	_done("entrants_are_isolated_from_base_resources")

## Tool-only DirAccess scan -- fine here (this never runs from an exported
## .pck), same as balance_test.gd's own loader.
func _roster() -> Array[Familiar]:
	var familiars: Array[Familiar] = []
	var dir := DirAccess.open(FAMILIARS_DIR)
	if dir == null:
		_failures.append("could not open %s" % FAMILIARS_DIR)
		return familiars
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var familiar: Familiar = load(FAMILIARS_DIR + file_name)
			if familiar != null and not familiar.techniques.is_empty():
				familiars.append(familiar)
		file_name = dir.get_next()
	dir.list_dir_end()
	return familiars

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _done(check_name: String) -> void:
	_completed.append(check_name)

func _report() -> void:
	for check_name in EXPECTED_CHECKS:
		if check_name not in _completed:
			_failures.append("check '%s' never completed -- it crashed partway" % check_name)

	if _failures.is_empty():
		print("ALL CHECKS PASSED (%d/%d)" % [_completed.size(), EXPECTED_CHECKS.size()])
	else:
		print("FAILED (%d problem(s)):" % _failures.size())
		for failure in _failures:
			print("  - %s" % failure)
	quit()
