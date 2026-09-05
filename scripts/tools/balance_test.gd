extends SceneTree

## Headless round-robin balance harness -- see .claude/BALANCE_TEST_PLAN.md (Part
## 2). Not a throwaway: kept in the repo, named outside the _verify_* glob so it's
## clearly meant to be re-run after every content-pass update, not deleted after
## one use. Run with:
##   godot --headless --script res://scripts/tools/balance_test.gd
##
## Combat has zero randomness, so a full round-robin needs no repeated trials --
## the only thing that can change a pair's outcome is which side wins the
## construction-order Speed tiebreak (see BattleEngine.determine_first_actor()),
## which is exactly why every pair is run twice, once with each side in the
## tiebreak-winning slot.

const MAX_TURNS := 200
const WIN_RATE_OUTLIER_HIGH := 0.75
const WIN_RATE_OUTLIER_LOW := 0.25
const FAMILIARS_DIR := "res://resources/familiars/"

func _init() -> void:
	var familiars: Array[Familiar] = _load_familiars()

	var names: Array[String] = []
	for familiar in familiars:
		names.append(familiar.familiar_name)
	print("Loaded %d familiar(s): %s" % [familiars.size(), ", ".join(names)])

	var results: Dictionary = run_round_robin(familiars)
	_print_report(familiars, results)
	_write_csv(results)

	quit()

## Loads every .tres under resources/familiars/, skipping (with a warning, not a
## crash) anything that still looks like an in-progress stub -- familiar_name
## left at Familiar.gd's own default, or no techniques/priority_rules authored
## yet. Exactly the shape Battabat and Mallegrav were both in mid-content-pass;
## this is what stops a stub from producing a null-technique crash partway
## through a 200+-battle run instead of a clean, named warning up front.
func _load_familiars() -> Array[Familiar]:
	var familiars: Array[Familiar] = []

	var dir := DirAccess.open(FAMILIARS_DIR)
	if dir == null:
		push_error("Could not open %s" % FAMILIARS_DIR)
		return familiars

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path: String = FAMILIARS_DIR + file_name
			var familiar: Familiar = load(path)

			if familiar == null:
				print("WARNING: skipping %s -- failed to load" % path)
			elif familiar.familiar_name == "" or familiar.familiar_name == "Familiar":
				print("WARNING: skipping %s -- no familiar_name authored yet" % path)
			elif familiar.techniques.is_empty():
				print("WARNING: skipping %s -- no techniques authored yet" % path)
			elif familiar.priority_rules.is_empty():
				print("WARNING: skipping %s -- no priority_rules authored yet" % path)
			else:
				familiars.append(familiar)

		file_name = dir.get_next()
	dir.list_dir_end()

	return familiars

## Runs every unordered pair in familiars twice -- once with each side occupying
## the tiebreak-winning "player" slot -- and aggregates the results. Takes a
## plain Array[Familiar] (rather than reaching for _load_familiars() itself) so
## Part 3's stat-sensitivity sweep can call this again with substituted stat
## values without duplicating the pairing loop.
func run_round_robin(familiars: Array[Familiar]) -> Dictionary:
	var matches: Array[Dictionary] = []

	for i in range(familiars.size()):
		for j in range(i + 1, familiars.size()):
			var a: Familiar = familiars[i]
			var b: Familiar = familiars[j]

			matches.append({
				"a": a,
				"b": b,
				"a_as_player": _run_one_battle(a, b),
				"b_as_player": _run_one_battle(b, a),
			})

	return _aggregate(familiars, matches)

## Builds two fresh Combatants (mirroring battle_controller._ready()'s
## Combatant.new() + opponent-linking) and runs them through BattleEngine to
## completion. player_familiar occupies the tiebreak-winning slot in a Speed tie
## (see BattleEngine.determine_first_actor()) -- everything else about the two
## sides is symmetric.
func _run_one_battle(player_familiar: Familiar, enemy_familiar: Familiar) -> Dictionary:
	var player := Combatant.new(player_familiar)
	var enemy := Combatant.new(enemy_familiar)
	player.opponent = enemy
	enemy.opponent = player

	var engine := BattleEngine.new(player, enemy)
	var result: Dictionary = engine.run_to_completion(MAX_TURNS)

	var winner_name: String = ""
	if result.winner == player:
		winner_name = player_familiar.familiar_name
	elif result.winner == enemy:
		winner_name = enemy_familiar.familiar_name

	return {"winner_name": winner_name, "turns": result.turns, "stalemate": result.stalemate}

## Turns the raw per-pair match list into: per-familiar win/loss/stalemate
## tallies and outlier flags, a win/loss matrix, hard-counter pairs (a clean
## sweep in both orderings), doomed familiars (zero wins anywhere in the
## field), and tie-order-sensitive pairs (a genuine Speed tie whose two runs
## disagreed on the winner).
func _aggregate(familiars: Array[Familiar], matches: Array[Dictionary]) -> Dictionary:
	var wins: Dictionary[String, int] = {}
	var losses: Dictionary[String, int] = {}
	var stalemates: Dictionary[String, int] = {}
	for familiar in familiars:
		wins[familiar.familiar_name] = 0
		losses[familiar.familiar_name] = 0
		stalemates[familiar.familiar_name] = 0

	# matrix[row][col] -- "row"'s result against "col" from the run where row
	# occupied the tiebreak-winning player slot. On any pair that isn't a genuine
	# Speed tie this is representative of both runs (see the tie-sensitive check
	# below for why); on a tied pair it's specifically the "row wins ties" run.
	var matrix: Dictionary = {}
	var hard_counters: Array[Dictionary] = []
	var tie_sensitive: Array[Dictionary] = []

	for match in matches:
		var a: Familiar = match.a
		var b: Familiar = match.b
		var a_name: String = a.familiar_name
		var b_name: String = b.familiar_name

		var run_a_player: Dictionary = match.a_as_player  # a is player, b is enemy
		var run_b_player: Dictionary = match.b_as_player  # b is player, a is enemy

		_tally(a_name, b_name, run_a_player, wins, losses, stalemates)
		_tally(b_name, a_name, run_b_player, wins, losses, stalemates)

		if not matrix.has(a_name):
			matrix[a_name] = {}
		if not matrix.has(b_name):
			matrix[b_name] = {}
		matrix[a_name][b_name] = _matrix_cell(a_name, run_a_player.winner_name)
		matrix[b_name][a_name] = _matrix_cell(b_name, run_b_player.winner_name)

		if run_a_player.winner_name != "" and run_a_player.winner_name == run_b_player.winner_name:
			var loser_name: String = b_name if run_a_player.winner_name == a_name else a_name
			hard_counters.append({"winner": run_a_player.winner_name, "loser": loser_name})

		# A genuine Speed tie is the most common cause (see determine_first_actor()),
		# but not the only one: a mutual KO -- both sides reaching 0 HP within the
		# same step, e.g. a lethal hit's retaliation-on-hit status killing the
		# attacker right back -- also makes check_victory() favor whichever side
		# happens to be "player" for that run. Flag any disagreement regardless of
		# cause; speed_tie says whether the known cause applies here, so a
		# non-tied flag is a signal to go look for the other kind (a real find,
		# not a false positive) rather than something to write off as a bug in
		# this check.
		if run_a_player.winner_name != run_b_player.winner_name:
			tie_sensitive.append({
				"a": a_name,
				"b": b_name,
				"winner_when_a_acts_first_on_tie": run_a_player.winner_name,
				"winner_when_b_acts_first_on_tie": run_b_player.winner_name,
				"speed_tie": a.speed == b.speed,
			})

	var per_familiar: Array[Dictionary] = []
	var doomed: Array[String] = []
	for familiar in familiars:
		var name: String = familiar.familiar_name
		var w: int = wins[name]
		var l: int = losses[name]
		var s: int = stalemates[name]
		var win_rate: float = (float(w) / (w + l)) if (w + l) > 0 else 0.0

		var flag: String = ""
		if w == 0:
			flag = "DOOMED"
			doomed.append(name)
		elif win_rate >= WIN_RATE_OUTLIER_HIGH:
			flag = "outlier (high)"
		elif win_rate <= WIN_RATE_OUTLIER_LOW:
			flag = "outlier (low)"

		per_familiar.append({
			"name": name, "wins": w, "losses": l, "stalemates": s,
			"win_rate": win_rate, "flag": flag,
		})

	return {
		"per_familiar": per_familiar,
		"matrix": matrix,
		"hard_counters": hard_counters,
		"tie_sensitive": tie_sensitive,
		"doomed": doomed,
	}

func _matrix_cell(row_name: String, winner_name: String) -> String:
	if winner_name == "":
		return "stalemate"
	return "W" if winner_name == row_name else "L"

func _tally(name: String, opponent_name: String, run: Dictionary, wins: Dictionary, losses: Dictionary, stalemates: Dictionary) -> void:
	if run.stalemate or run.winner_name == "":
		stalemates[name] += 1
		return

	if run.winner_name == name:
		wins[name] += 1
		losses[opponent_name] += 1
	else:
		wins[opponent_name] += 1
		losses[name] += 1

func _print_report(familiars: Array[Familiar], results: Dictionary) -> void:
	print("\n=== Summary ===")
	print("%-16s %4s %4s %6s %8s  %s" % ["Familiar", "W", "L", "Stale", "Win%", "Flag"])
	for row in results.per_familiar:
		print("%-16s %4d %4d %6d %7.1f%%  %s" % [
			row.name, row.wins, row.losses, row.stalemates, row.win_rate * 100.0, row.flag
		])

	print("\n=== Matrix (row's result against col, row acting first on any tie) ===")
	var names: Array[String] = []
	for familiar in familiars:
		names.append(familiar.familiar_name)

	var header: String = "%-16s" % ""
	for name in names:
		header += " %-10s" % name.left(10)
	print(header)

	for row_name in names:
		var line: String = "%-16s" % row_name
		for col_name in names:
			if row_name == col_name:
				line += " %-10s" % "--"
			else:
				line += " %-10s" % matrix_lookup(results.matrix, row_name, col_name)
		print(line)

	if results.hard_counters.is_empty():
		print("\nNo hard counters (a matchup that's a clean sweep in both orderings).")
	else:
		print("\n=== Hard counters (clean sweep in both orderings) ===")
		for hard_counter in results.hard_counters:
			print("%s beats %s regardless of who acts first" % [hard_counter.winner, hard_counter.loser])

	if results.doomed.is_empty():
		print("\nNo doomed familiars (every familiar has at least one win somewhere in the field).")
	else:
		print("\n=== DOOMED (zero wins anywhere in the field) ===")
		for name in results.doomed:
			print(name)

	if results.tie_sensitive.is_empty():
		print("\nNo order-sensitive matchups (no pair's winner changed based on who acted first).")
	else:
		print("\n=== Order-sensitive matchups (the winner changes based on who acts first) ===")
		for tie in results.tie_sensitive:
			var cause: String = "Speed tie" if tie.speed_tie else "NOT a Speed tie -- likely a mutual KO or other order-dependent interaction, worth tracing"
			print("%s vs %s (%s): %s wins if %s acts first, %s wins if %s does" % [
				tie.a, tie.b, cause,
				tie.winner_when_a_acts_first_on_tie, tie.a,
				tie.winner_when_b_acts_first_on_tie, tie.b,
			])

func matrix_lookup(matrix: Dictionary, row_name: String, col_name: String) -> String:
	if not matrix.has(row_name) or not matrix[row_name].has(col_name):
		return "?"
	return matrix[row_name][col_name]

func _write_csv(results: Dictionary) -> void:
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("balance_reports"):
		dir.make_dir("balance_reports")

	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var path: String = "res://balance_reports/%s.csv" % timestamp

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s (error %d)" % [path, FileAccess.get_open_error()])
		return

	file.store_line("Familiar,Wins,Losses,Stalemates,WinRate,Flag")
	for row in results.per_familiar:
		file.store_line("%s,%d,%d,%d,%.3f,%s" % [
			row.name, row.wins, row.losses, row.stalemates, row.win_rate, row.flag
		])
	file.close()

	print("\nWrote %s" % path)
