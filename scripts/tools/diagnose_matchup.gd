extends SceneTree

## Turn-by-turn diagnostic for one specific matchup -- damage dealt per round,
## HP remaining for both sides each round, and total turns elapsed -- so a
## kit's actual problem (not enough damage vs. not enough survivability vs.
## dying to attrition before its own gimmick comes online) is visible directly
## instead of re-derived by hand from a one-off trace script every time.
## Not a throwaway: kept in the repo, meant to be re-run against any pair.
##
## Run with:
##   godot --headless --script res://scripts/tools/diagnose_matchup.gd -- FamiliarA FamiliarB
## Falls back to the two names below if no arguments are given.

const DEFAULT_FAMILIAR_A := "Ironcap"
const DEFAULT_FAMILIAR_B := "Twerpent"
const MAX_TURNS := 300
const FAMILIARS_DIR := "res://resources/familiars/"

func _find_familiar(name: String) -> Familiar:
	var dir := DirAccess.open(FAMILIARS_DIR)
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var familiar: Familiar = load(FAMILIARS_DIR + file_name)
			if familiar != null and familiar.familiar_name == name:
				dir.list_dir_end()
				return familiar
		file_name = dir.get_next()
	dir.list_dir_end()
	return null

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var name_a: String = args[0] if args.size() > 0 else DEFAULT_FAMILIAR_A
	var name_b: String = args[1] if args.size() > 1 else DEFAULT_FAMILIAR_B

	var familiar_a: Familiar = _find_familiar(name_a)
	var familiar_b: Familiar = _find_familiar(name_b)

	if familiar_a == null or familiar_b == null:
		push_error("Could not find familiar(s): %s" % [name_a if familiar_a == null else name_b])
		quit()
		return

	var player := Combatant.new(familiar_a)
	var enemy := Combatant.new(familiar_b)
	player.opponent = enemy
	enemy.opponent = player

	var engine := BattleEngine.new(player, enemy)
	var result: Dictionary = engine.run_to_completion(MAX_TURNS, true)

	print("=== %s vs %s ===" % [name_a, name_b])
	print("%-5s %-12s %-12s %8s %12s %12s" % ["Turn", "Acted", "Hit", "Damage", "%s HP" % name_a, "%s HP" % name_b])

	# Kept separate from turn damage, not merged into it: an upkeep entry is
	# self-damage from the acting familiar's own statuses (Poison/Burn/
	# Foretell/...), not something it did to its opponent. Folding the two
	# together would hide exactly the thing this split is meant to show --
	# whether a kit is losing the visible technique-damage race or actually
	# winning it and dying to unanswered DoT instead.
	var turn_damage_by: Dictionary[String, int] = {name_a: 0, name_b: 0}
	var upkeep_damage_by: Dictionary[String, int] = {name_a: 0, name_b: 0}
	var turn_count_by: Dictionary[String, int] = {name_a: 0, name_b: 0}

	for entry in result.history:
		# player/enemy are fixed to familiar_a/familiar_b for the whole battle
		# (set once at construction above), regardless of who acts on any given
		# turn -- so entry.player_hp/enemy_hp already line up with the name_a/
		# name_b columns in the header.
		var hit_column: String = entry.target_familiar if entry.phase == "turn" else "[upkeep]"
		print("%-5d %-12s %-12s %8d %12d %12d" % [
			entry.turn, entry.acting_familiar, hit_column, entry.damage_dealt,
			entry.player_hp, entry.enemy_hp,
		])
		# Real combat-log text for the entry -- damage_dealt alone can't tell
		# "the fallback technique fired" apart from "the real technique fired
		# but did nothing after Absorption/Ward," since both read as 0.
		for message in entry.messages:
			print("      %s" % message)

		if entry.phase == "turn":
			if turn_damage_by.has(entry.acting_familiar):
				turn_damage_by[entry.acting_familiar] += entry.damage_dealt
			if turn_count_by.has(entry.acting_familiar):
				turn_count_by[entry.acting_familiar] += 1
		elif upkeep_damage_by.has(entry.acting_familiar):
			upkeep_damage_by[entry.acting_familiar] += entry.damage_dealt

	print("")
	if result.stalemate:
		print("Result: STALEMATE after %d turns" % result.turns)
	else:
		print("Result: %s wins after %d turns" % [result.winner.familiar.familiar_name, result.turns])

	print("Technique damage dealt -- %s: %d, %s: %d" % [
		name_a, turn_damage_by[name_a], name_b, turn_damage_by[name_b]
	])
	print("Upkeep (status tick) damage taken -- %s: %d, %s: %d" % [
		name_a, upkeep_damage_by[name_a], name_b, upkeep_damage_by[name_b]
	])
	print("Total damage taken (technique + upkeep) -- %s: %d, %s: %d" % [
		name_a, turn_damage_by[name_b] + upkeep_damage_by[name_a],
		name_b, turn_damage_by[name_a] + upkeep_damage_by[name_b],
	])

	if turn_count_by[name_a] > 0:
		print("Average technique damage per round -- %s: %.1f (over %d rounds)" % [
			name_a, float(turn_damage_by[name_a]) / turn_count_by[name_a], turn_count_by[name_a]
		])
	if turn_count_by[name_b] > 0:
		print("Average technique damage per round -- %s: %.1f (over %d rounds)" % [
			name_b, float(turn_damage_by[name_b]) / turn_count_by[name_b], turn_count_by[name_b]
		])

	quit()
