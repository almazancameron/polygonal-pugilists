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
]

var _failures: Array[String] = []
var _completed: Array[String] = []

func _init() -> void:
	_check_generate_shape()
	_check_generate_entrants_distinct()
	_check_generate_is_deterministic_per_seed()
	_check_generate_rejects_wrong_roster_size()
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
