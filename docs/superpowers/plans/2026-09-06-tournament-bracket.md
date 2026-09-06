# Tournament Bracket Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `battle_controller.gd`'s random-gauntlet stand-in with a real 16-entrant single-elimination bracket that doubles as character select, resolves off-screen matches by simulation-plus-dice-roll, and lets the player scout upcoming results.

**Architecture:** Three small `Resource` classes (`Bracket`/`BracketRound`/`BracketMatch`) hold the tree; pure static helpers (`BracketOdds`, `BracketSimulator`, `AIDrafter`) handle math, off-screen fights, and AI build growth with no scene-tree dependency. `battle_controller.gd` swaps `opponent_lineup[current_round]` lookups for bracket lookups. UI comes last, on top of a loop that already works headlessly.

**Tech Stack:** Godot 4.7.1, GDScript. No test framework exists — testing is a committed, re-runnable headless harness (`scripts/tools/bracket_test.gd`) plus live verification through the `godot-mcp-toolkit` MCP tools.

**Spec:** `docs/superpowers/specs/2026-09-06-tournament-bracket-design.md`

## Global Constraints

- **Godot binary** (run from the project directory): `"../Godot_v4.7.1-stable_win64_console.exe"`
- **Parse check after every code change:** `"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit 2>&1 | grep -i "error" | grep -v "RID allocations\|ObjectDB instances\|resources still in use\|at: clear\|at: cleanup"` — empty output means clean.
- **A GDScript runtime error aborts only the function it occurs in**, so a harness that merely collects failures will report success for a check that crashed. Every check registers a completion marker, and the report fails if any expected check never completed. Also treat any `SCRIPT ERROR` in shell output as failure — GDScript cannot see its own runtime errors.
- **Integer division truncates.** Always `float(a) / float(b)` for percentages (this bit a real condition bug already — see `LEARNING.md`).
- **Never use `DirAccess` directory scans in game code** — they return nothing from an exported `.pck`. Tool scripts under `scripts/tools/` may use them (they only ever run against the loose project).
- **`.tres` serializer omits properties equal to their declared default** — a missing field in a saved file is not necessarily lost data.
- **`match` is a GDScript keyword.** Name `BracketMatch` locals `bracket_match`, never `match`.
- **Every `Familiar` in a bracket must be `.duplicate()`d** before use — builds mutate in place over a run, and `load()` caches `.tres` by path, so a shared object would corrupt the base resource (same reasoning as the existing `_randomize_matchup()`).
- **Commit after every task.** Do not push.
- **Forcing a win in the running game** (several tasks need this — natural combat is slow and matchup-dependent). With the game running via MCP `game_start` and a fight actually in progress, run `execute_code` (channel `runtime`) twice:
  1. `get_node('/root/Battle').enemy.set('current_hp', 0)`
  2. `get_node('/root/Battle').call('check_victory')`

  Set HP **after** the fight has started — `begin_fight()` resets it, so a value set earlier is silently overwritten. Do this once per intended win; calling `check_victory()` repeatedly while the real turn loop is also running produces interleaved state.
- **`click_node` fires a button's `pressed` signal regardless of visibility.** Never click a hidden button (e.g. `GameOverPanel/RestartButton` mid-fight) — that starts a second run while the first one's coroutine is still alive, and the resulting interleaved state looks like a bug in the code under test.

---

## Phase A — Data model and logic (headless, no UI)

### Task 1: Test harness, bracket resources, and generation

**Files:**
- Create: `scripts/bracket/bracket_match.gd`
- Create: `scripts/bracket/bracket_round.gd`
- Create: `scripts/bracket/bracket.gd`
- Test: `scripts/tools/bracket_test.gd` (create — committed and re-runnable, *not* a throwaway `_verify_*.gd`; `DEVLOG.md` session 5 explicitly calls out the lack of re-runnable coverage as a regret)

**Interfaces:**
- Consumes: `Familiar` (existing: `familiar_name`, `max_hp`, `power`, `defense`, `speed`, `focus`, `techniques`, `priority_rules`, `passives`, `sprite`, `species_affinities`).
- Produces: `BracketMatch` (fields `entrant_a`/`entrant_b`/`winner`/`odds_label`/`revealed`/`is_player_match`; methods `is_ready() -> bool`, `has_entrant(Familiar) -> bool`, `other_entrant(Familiar) -> Familiar`), `BracketRound` (`matches: Array[BracketMatch]`, `player_match() -> BracketMatch`, `other_matches() -> Array[BracketMatch]`), `Bracket` (`rounds: Array[BracketRound]`, `boss_familiar: Familiar`, `const ENTRANT_COUNT := 16`, `static generate(roster: Array[Familiar], rng: RandomNumberGenerator, boss: Familiar = null) -> Bracket`).

- [ ] **Step 1: Write the failing test harness**

Create `scripts/tools/bracket_test.gd`:

```gdscript
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
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/bracket_test.gd 2>&1 | grep -E "PASSED|FAILED|SCRIPT ERROR|  - "
```

Expected: `SCRIPT ERROR` lines about `Bracket` being an unknown identifier. The classes don't exist yet.

- [ ] **Step 3: Create `scripts/bracket/bracket_match.gd`**

```gdscript
class_name BracketMatch
extends Resource

## One pairing in the bracket tree. entrant_a/entrant_b are null until the
## previous round resolves into them (only round 1 starts populated).
##
## odds_label being set while winner is still null and revealed is still
## false is the normal "scouted but not resolved" state -- the player sees
## the odds before their own fight, and the true winner is rolled only
## afterward (see the design spec, §6).

@export var entrant_a: Familiar
@export var entrant_b: Familiar
@export var winner: Familiar
@export var odds_label: String = ""
@export var revealed: bool = false

## Decided at runtime by character select, never authored -- deliberately
## not @export so it can't be saved into a .tres by accident.
var is_player_match: bool = false

func is_ready() -> bool:
	return entrant_a != null and entrant_b != null

func has_entrant(familiar: Familiar) -> bool:
	return entrant_a == familiar or entrant_b == familiar

func other_entrant(familiar: Familiar) -> Familiar:
	if entrant_a == familiar:
		return entrant_b
	if entrant_b == familiar:
		return entrant_a
	return null
```

- [ ] **Step 4: Create `scripts/bracket/bracket_round.gd`**

```gdscript
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
```

- [ ] **Step 5: Create `scripts/bracket/bracket.gd`**

```gdscript
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
```

- [ ] **Step 6: Run the harness to verify it passes**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/bracket_test.gd 2>&1 | grep -E "PASSED|FAILED|SCRIPT ERROR|  - "
```

Expected: `ALL CHECKS PASSED (4/4)` and no `SCRIPT ERROR` line. The `generate_rejects_wrong_roster_size` check intentionally triggers a `push_error`, which prints an `ERROR:` line (not `SCRIPT ERROR:`) — that is expected and fine.

- [ ] **Step 7: Parse check**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit 2>&1 | grep -i "error" | grep -v "RID allocations\|ObjectDB instances\|resources still in use\|at: clear\|at: cleanup"
```

Expected: empty output.

- [ ] **Step 8: Commit**

```bash
git add scripts/bracket/ scripts/tools/bracket_test.gd
git commit -m "feat: bracket data model and generation"
```

---

### Task 2: Round-to-round advancement

**Files:**
- Modify: `scripts/bracket/bracket.gd` (add `advance_round()`)
- Test: `scripts/tools/bracket_test.gd` (add two checks)

**Interfaces:**
- Consumes: `Bracket.generate()`, `BracketMatch.winner` from Task 1.
- Produces: `Bracket.advance_round(round_index: int) -> void` (writes this round's winners into next round's `entrant_a`/`entrant_b` slots).

- [ ] **Step 1: Add the failing checks to the harness**

In `scripts/tools/bracket_test.gd`, append to `EXPECTED_CHECKS`:

```gdscript
	"advance_round_pairs_winners",
	"advance_through_all_rounds",
```

Add both calls in `_init()` before `_report()`:

```gdscript
	_check_advance_round_pairs_winners()
	_check_advance_through_all_rounds()
```

Add the two check functions:

```gdscript
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
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/bracket_test.gd 2>&1 | grep -E "PASSED|FAILED|SCRIPT ERROR|  - "
```

Expected: `SCRIPT ERROR` about a nonexistent `advance_round` method, and the report flagging both new checks as never completed.

- [ ] **Step 3: Implement both methods**

Append to `scripts/bracket/bracket.gd`:

```gdscript
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
```

- [ ] **Step 4: Run the harness to verify it passes**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/bracket_test.gd 2>&1 | grep -E "PASSED|FAILED|SCRIPT ERROR|  - "
```

Expected: `ALL CHECKS PASSED (6/6)`.

- [ ] **Step 5: Commit**

```bash
git add scripts/bracket/bracket.gd scripts/tools/bracket_test.gd
git commit -m "feat: bracket round-to-round advancement"
```

---

### Task 3: Odds math

**Files:**
- Create: `scripts/bracket/bracket_odds.gd`
- Test: `scripts/tools/bracket_test.gd` (add one check)

**Interfaces:**
- Consumes: nothing (pure math).
- Produces: `BracketOdds.margin(winner_hp_pct: float, loser_hp_pct: float) -> float`, `BracketOdds.advance_probability(margin_value: float) -> float`, `BracketOdds.winner_label(probability: float) -> String`, `BracketOdds.loser_label(probability: float) -> String`. Label strings are exactly `"Heavy Favorite"`, `"Favorite"`, `"Toss-up"`, `"Underdog"`, `"Heavy Underdog"`.

- [ ] **Step 1: Add the failing check**

Append `"odds_boundaries"` to `EXPECTED_CHECKS`, add `_check_odds_boundaries()` to `_init()`, and add:

```gdscript
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
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/bracket_test.gd 2>&1 | grep -E "PASSED|FAILED|SCRIPT ERROR|  - "
```

Expected: `SCRIPT ERROR` about unknown identifier `BracketOdds`.

- [ ] **Step 3: Implement `scripts/bracket/bracket_odds.gd`**

```gdscript
class_name BracketOdds
extends RefCounted

## Turns a simulated match's HP margin into the odds an off-screen match
## gets rolled against, plus the coarse label the player sees while
## scouting. All static -- no state, no scene tree.
##
## OPEN / PLAYTEST: every constant here is a first, reversible guess.
## Retune once real brackets have actually been played, not before.

const HEAVY_FAVORITE_THRESHOLD: float = 0.90
const FAVORITE_THRESHOLD: float = 0.70

const LABEL_HEAVY_FAVORITE: String = "Heavy Favorite"
const LABEL_FAVORITE: String = "Favorite"
const LABEL_TOSS_UP: String = "Toss-up"
const LABEL_UNDERDOG: String = "Underdog"
const LABEL_HEAVY_UNDERDOG: String = "Heavy Underdog"

## How decisively the winner won, as a 0..1 HP-fraction gap. A real
## defeat leaves the loser at 0.0, so this collapses to "how much HP did
## the winner keep"; a stalemate (both sides alive at the turn cap) has
## both fractions above zero and naturally lands near 0, which is exactly
## what a stalemate should mean.
static func margin(winner_hp_pct: float, loser_hp_pct: float) -> float:
	return clampf(winner_hp_pct - loser_hp_pct, 0.0, 1.0)

## The chance the simulated winner actually advances. Linear and
## symmetric: a dead-even fight is a coin flip, a flawless win is a lock,
## and everything between leaves room for an upset.
static func advance_probability(margin_value: float) -> float:
	return clampf(0.5 + 0.5 * margin_value, 0.5, 1.0)

static func winner_label(probability: float) -> String:
	if probability >= HEAVY_FAVORITE_THRESHOLD:
		return LABEL_HEAVY_FAVORITE
	if probability >= FAVORITE_THRESHOLD:
		return LABEL_FAVORITE
	return LABEL_TOSS_UP

static func loser_label(probability: float) -> String:
	if probability >= HEAVY_FAVORITE_THRESHOLD:
		return LABEL_HEAVY_UNDERDOG
	if probability >= FAVORITE_THRESHOLD:
		return LABEL_UNDERDOG
	return LABEL_TOSS_UP
```

- [ ] **Step 4: Run the harness to verify it passes**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/bracket_test.gd 2>&1 | grep -E "PASSED|FAILED|SCRIPT ERROR|  - "
```

Expected: `ALL CHECKS PASSED (7/7)`.

- [ ] **Step 5: Commit**

```bash
git add scripts/bracket/bracket_odds.gd scripts/tools/bracket_test.gd
git commit -m "feat: bracket odds margin/probability/label mapping"
```

---

### Task 4: Off-screen match simulation

**Files:**
- Create: `scripts/bracket/bracket_simulator.gd`
- Test: `scripts/tools/bracket_test.gd` (add one check)

**Interfaces:**
- Consumes: `BracketOdds.margin()` (Task 3); existing `Combatant.new(Familiar)`, `Combatant.opponent`, `BattleEngine.new(player, enemy)`, `BattleEngine.run_to_completion(max_turns) -> {winner, turns, stalemate, history}`.
- Produces: `BracketSimulator.simulate(entrant_a: Familiar, entrant_b: Familiar) -> Dictionary` returning `{"winner": Familiar, "loser": Familiar, "margin": float, "stalemate": bool}`. `winner`/`loser` are always non-null (a stalemate nominates the higher-HP side).

- [ ] **Step 1: Add the failing check**

Append `"simulate_produces_winner_and_margin"` to `EXPECTED_CHECKS`, add `_check_simulate_produces_winner_and_margin()` to `_init()`, and add:

```gdscript
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
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/bracket_test.gd 2>&1 | grep -E "PASSED|FAILED|SCRIPT ERROR|  - "
```

Expected: `SCRIPT ERROR` about unknown identifier `BracketSimulator`.

- [ ] **Step 3: Implement `scripts/bracket/bracket_simulator.gd`**

```gdscript
class_name BracketSimulator
extends RefCounted

## Plays an off-screen bracket match through the real combat engine, with
## no UI and no pacing, and reports how decisively it went.
##
## Using the real engine rather than a stat-comparison approximation is
## affordable here: a run needs at most 11 off-screen matches total
## (7 + 3 + 1 + 0 across the four rounds) and balance_test.gd measures a
## full battle at roughly 7.5ms. The result is deliberately treated as
## odds rather than a verdict -- see BracketOdds and the design spec.

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
```

- [ ] **Step 4: Run the harness to verify it passes**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/bracket_test.gd 2>&1 | grep -E "PASSED|FAILED|SCRIPT ERROR|  - "
```

Expected: `ALL CHECKS PASSED (8/8)`.

- [ ] **Step 5: Commit**

```bash
git add scripts/bracket/bracket_simulator.gd scripts/tools/bracket_test.gd
git commit -m "feat: off-screen bracket match simulation"
```

---

### Task 5: Placeholder AI build progression

**Files:**
- Create: `scripts/bracket/ai_drafter.gd`
- Test: `scripts/tools/bracket_test.gd` (add one check)

**Interfaces:**
- Consumes: existing `RewardProgression.kind_for_round(int) -> RewardKind`, `RewardProgression.RewardKind` enum (`TECHNIQUE`/`PASSIVE`/`PASSIVE_TRADE`/`NONE`), `BuildSnapshot.compute(familiar, excluding := []) -> BuildSnapshot`, `RewardSelector.pick_candidate(slot, familiar, snapshot, pool, excluded_content, rng) -> Variant`, `RewardSelector.RewardSlot.RUN`, `Familiar.Stat`.
- Produces: `AIDrafter.apply_round_reward(familiar: Familiar, round_completed: int, technique_pool: Array[Technique], passive_pool: Array[PassiveEffect], rng: RandomNumberGenerator) -> void`, `AIDrafter.lowest_stat(familiar: Familiar) -> Familiar.Stat`.

- [ ] **Step 1: Add the failing check**

Append `"ai_drafter_grows_a_build"` to `EXPECTED_CHECKS`, add `_check_ai_drafter_grows_a_build()` to `_init()`, and add:

```gdscript
func _check_ai_drafter_grows_a_build() -> void:
	var roster: Array[Familiar] = _roster()
	var familiar: Familiar = roster[0].duplicate()
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
	var hp_starved: Familiar = roster[0].duplicate()
	hp_starved.max_hp = 35
	hp_starved.power = 20
	hp_starved.defense = 20
	hp_starved.speed = 20
	hp_starved.focus = 20
	_expect(AIDrafter.lowest_stat(hp_starved) == Familiar.Stat.MAX_HP,
		"a familiar at the bottom of the HP range with everything else maxed should get HP")
	_done("ai_drafter_grows_a_build")
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/bracket_test.gd 2>&1 | grep -E "PASSED|FAILED|SCRIPT ERROR|  - "
```

Expected: `SCRIPT ERROR` about unknown identifier `AIDrafter`.

- [ ] **Step 3: Implement `scripts/bracket/ai_drafter.gd`**

```gdscript
class_name AIDrafter
extends RefCounted

## Placeholder build growth for the 15 AI bracket entrants, so opponents
## are "also accumulating power" (GAME_DESIGN.md §0.2) rather than frozen
## at their starting kit.
##
## Deliberately simple and build-unaware: it reuses the player's own
## reward machinery (RewardProgression's cadence, RewardSelector's Run
## slot) rather than inventing a parallel one, and picks stats by a fixed
## rule. The real system -- drafting personalities plus a shared priority
## optimizer -- is designed separately in
## docs/superpowers/specs/2026-09-06-ai-drafting-design.md and swaps in
## here later without the bracket needing to change.

## Each stat's typical authored range, matching the bounds the session-7
## stat-search pass used (recorded in DECISIONS.md's balance-testing
## entry; the search script itself was a throwaway and is long deleted).
## Needed because the stats are on wildly different scales: picking "the
## lowest stat" by raw value would never once choose max_hp.
const STAT_RANGES: Dictionary = {
	Familiar.Stat.MAX_HP: Vector2(35.0, 85.0),
	Familiar.Stat.POWER: Vector2(2.0, 20.0),
	Familiar.Stat.DEFENSE: Vector2(2.0, 20.0),
	Familiar.Stat.SPEED: Vector2(2.0, 20.0),
	Familiar.Stat.FOCUS: Vector2(2.0, 20.0),
}

## One round's worth of growth: always a stat point, plus whatever
## content this round's cadence calls for.
static func apply_round_reward(familiar: Familiar, round_completed: int,
		technique_pool: Array[Technique], passive_pool: Array[PassiveEffect],
		rng: RandomNumberGenerator) -> void:
	_apply_stat_point(familiar)

	var kind: RewardProgression.RewardKind = RewardProgression.kind_for_round(round_completed)
	match kind:
		RewardProgression.RewardKind.TECHNIQUE:
			_take_technique(familiar, technique_pool, rng)
		RewardProgression.RewardKind.PASSIVE:
			_take_passive(familiar, passive_pool, rng)
		RewardProgression.RewardKind.PASSIVE_TRADE:
			_trade_passive(familiar, passive_pool, rng)
		RewardProgression.RewardKind.NONE:
			pass

## Whichever stat sits lowest within its own typical range -- see
## STAT_RANGES for why this isn't a raw comparison.
static func lowest_stat(familiar: Familiar) -> Familiar.Stat:
	var best_stat: Familiar.Stat = Familiar.Stat.MAX_HP
	var best_fraction: float = 2.0

	for stat in STAT_RANGES:
		var bounds: Vector2 = STAT_RANGES[stat]
		var current: float = float(_stat_value(familiar, stat))
		var fraction: float = (current - bounds.x) / (bounds.y - bounds.x)
		if fraction < best_fraction:
			best_fraction = fraction
			best_stat = stat

	return best_stat

static func _apply_stat_point(familiar: Familiar) -> void:
	var upgrade := ModifyStatUpgrade.new()
	upgrade.stat = lowest_stat(familiar)
	upgrade.bonus = 1
	upgrade.apply(familiar)

## The Run slot specifically: it's the one scored against what the build
## already owns, which is the closest thing to a judgment call an AI can
## make without a real personality system.
static func _take_technique(familiar: Familiar, pool: Array[Technique], rng: RandomNumberGenerator) -> void:
	var snapshot: BuildSnapshot = BuildSnapshot.compute(familiar)
	var pick = RewardSelector.pick_candidate(
		RewardSelector.RewardSlot.RUN, familiar, snapshot, pool, familiar.techniques, rng)
	if pick == null:
		return

	var upgrade := AddTechniqueUpgrade.new()
	upgrade.technique = pick
	upgrade.apply(familiar)

static func _take_passive(familiar: Familiar, pool: Array[PassiveEffect], rng: RandomNumberGenerator) -> void:
	var snapshot: BuildSnapshot = BuildSnapshot.compute(familiar)
	var pick = RewardSelector.pick_candidate(
		RewardSelector.RewardSlot.RUN, familiar, snapshot, pool, familiar.passives, rng)
	if pick == null:
		return

	var upgrade := AddPassiveUpgrade.new()
	upgrade.passive = pick
	upgrade.apply(familiar)

## Sacrifice the oldest passive for a fresh pick -- the AI's stand-in for
## the player's trade screen. Scored against the build as it will be
## *after* the sacrifice, the same way RewardFlowController does it.
static func _trade_passive(familiar: Familiar, pool: Array[PassiveEffect], rng: RandomNumberGenerator) -> void:
	if familiar.passives.is_empty():
		_take_passive(familiar, pool, rng)
		return

	var sacrificed: PassiveEffect = familiar.passives[0]
	var snapshot: BuildSnapshot = BuildSnapshot.compute(familiar, [sacrificed])
	var pick = RewardSelector.pick_candidate(
		RewardSelector.RewardSlot.RUN, familiar, snapshot, pool, familiar.passives, rng)
	if pick == null:
		return

	familiar.passives.erase(sacrificed)
	var upgrade := AddPassiveUpgrade.new()
	upgrade.passive = pick
	upgrade.apply(familiar)

static func _stat_value(familiar: Familiar, stat: Familiar.Stat) -> int:
	match stat:
		Familiar.Stat.MAX_HP:
			return familiar.max_hp
		Familiar.Stat.POWER:
			return familiar.power
		Familiar.Stat.DEFENSE:
			return familiar.defense
		Familiar.Stat.SPEED:
			return familiar.speed
		Familiar.Stat.FOCUS:
			return familiar.focus
	return 0
```

- [ ] **Step 4: Run the harness to verify it passes**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/bracket_test.gd 2>&1 | grep -E "PASSED|FAILED|SCRIPT ERROR|  - "
```

Expected: `ALL CHECKS PASSED (9/9)`.

- [ ] **Step 5: Commit**

```bash
git add scripts/bracket/ai_drafter.gd scripts/tools/bracket_test.gd
git commit -m "feat: placeholder AI build progression for bracket entrants"
```

---

## Phase B — Loop integration (playable at every commit)

### Task 6: Run the game off a Bracket instead of `opponent_lineup`

Character select does not exist yet, so this task auto-picks the player's entrant. The game stays fully playable; Task 9 replaces the auto-pick with the real screen.

**Files:**
- Modify: `scripts/battle_controller.gd` (`_start_new_run()`, `_randomize_matchup()` removal, `start_next_round()`, `check_victory()`)
- Test: live, via the `godot-mcp-toolkit` MCP tools

**Interfaces:**
- Consumes: `Bracket.generate()`, `Bracket.advance_round()`, `BracketRound.player_match()`, `BracketMatch.other_entrant()` from Tasks 1–2.
- Produces: on `battle_controller.gd` — `var bracket: Bracket`, `var current_round: int` (now the 0-indexed round index into `bracket.rounds`), `func player_bracket_match() -> BracketMatch`.

- [ ] **Step 1: Replace `_randomize_matchup()` with bracket setup**

In `scripts/battle_controller.gd`, delete the whole `_randomize_matchup()` function and the `@export var opponent_lineup: Array[Familiar] = []` line.

`enemy_familiar_data` is currently declared as an `@onready` that reads `opponent_lineup`, so removing that export breaks it. Replace this line:

```gdscript
@onready var enemy_familiar_data: Familiar = opponent_lineup[0] if opponent_lineup.size() > 0 else null
```

with a plain field — the bracket now assigns it before anything reads it:

```gdscript
## Assigned by _build_bracket()/start_next_round() from the bracket's own
## pairings. No longer derived from a pre-authored lineup.
var enemy_familiar_data: Familiar
```

Then add near the other run-state fields:

```gdscript
## The run's whole tournament tree. Replaces the old opponent_lineup
## gauntlet -- see docs/superpowers/specs/2026-09-06-tournament-bracket-design.md.
var bracket: Bracket

## Round the player is currently in, as a 0-indexed index into
## bracket.rounds (was previously an index into opponent_lineup).
var current_round: int = 0
```

Add the setup function:

```gdscript
## Builds this run's bracket and puts the player in one of its round-1
## matches. The entrant choice is temporary: Task 9's character-select
## screen replaces _auto_pick_entrant() with a real player decision.
func _build_bracket() -> void:
	if full_roster.size() != Bracket.ENTRANT_COUNT:
		push_error("full_roster must hold exactly %d familiars, holds %d" % [Bracket.ENTRANT_COUNT, full_roster.size()])
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	bracket = Bracket.generate(full_roster, rng)
	_auto_pick_entrant(rng)

func _auto_pick_entrant(rng: RandomNumberGenerator) -> void:
	var first_round: BracketRound = bracket.rounds[0]
	var chosen: BracketMatch = first_round.matches[rng.randi_range(0, first_round.matches.size() - 1)]
	chosen.is_player_match = true

	player_familiar_data = chosen.entrant_a
	enemy_familiar_data = chosen.entrant_b

## The match the player is fighting this round.
func player_bracket_match() -> BracketMatch:
	return bracket.rounds[current_round].player_match()
```

- [ ] **Step 2: Point `_start_new_run()` at the bracket**

In `_start_new_run()`, replace the `_randomize_matchup()` call with `_build_bracket()`. Everything after it (building `player`/`enemy` `Combatant`s, labels, portraits, `reward_flow`, HUD visibility, `log_view.clear()`, the pre-fight screen, `begin_fight()`) stays exactly as it is — it already reads `player_familiar_data`/`enemy_familiar_data`, which `_build_bracket()` now sets.

- [ ] **Step 3: Rewrite `start_next_round()` to walk the bracket**

Replace the body of `start_next_round()` with:

```gdscript
func start_next_round() -> void:
	# Record the player's own win, then feed this round's winners forward.
	var finished_match: BracketMatch = player_bracket_match()
	if finished_match != null:
		finished_match.winner = player_familiar_data
		finished_match.revealed = true

	bracket.advance_round(current_round)
	current_round += 1

	var next_match: BracketMatch = bracket.rounds[current_round].player_match()
	enemy_familiar_data = next_match.other_entrant(player_familiar_data)

	begin_reward_sequence()

	player = Combatant.new(player_familiar_data)
	update_hp_display(player)

	enemy = Combatant.new(enemy_familiar_data)
	enemy_name_label.text = enemy.familiar.familiar_name
	enemy_portrait.texture = enemy.familiar.sprite
	update_hp_display(enemy)

	player.opponent = enemy
	enemy.opponent = player
	engine = BattleEngine.new(player, enemy)
```

The player's next-round match must already be marked before `player_match()` can find it, so add this to `advance_round`'s caller side — immediately after `bracket.advance_round(current_round)` and before `current_round += 1`, insert:

```gdscript
	# The player advances into whichever next-round match now holds them.
	for bracket_match in bracket.rounds[current_round + 1].matches:
		if bracket_match.has_entrant(player_familiar_data):
			bracket_match.is_player_match = true
			break
```

- [ ] **Step 4: Fix `check_victory()`'s "is this the last round" test**

`check_victory()` currently compares `current_round < opponent_lineup.size() - 1`. Replace that condition with:

```gdscript
		if current_round < bracket.rounds.size() - 1:
```

and, in the loss branch, record the elimination before showing the Game Over screen — insert immediately after `phase = Phase.BATTLE_OVER` in that branch:

```gdscript
	var lost_match: BracketMatch = player_bracket_match()
	if lost_match != null:
		lost_match.winner = enemy_familiar_data
		lost_match.revealed = true
```

- [ ] **Step 5: Parse check**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit 2>&1 | grep -i "error" | grep -v "RID allocations\|ObjectDB instances\|resources still in use\|at: clear\|at: cleanup"
```

Expected: empty output. If it reports `opponent_lineup` still referenced somewhere, remove those references — `grep -n "opponent_lineup" scripts/battle_controller.gd` finds them.

- [ ] **Step 6: Verify a real round transition in the running game**

Start the game with the MCP toolkit (`game_start` on `res://scenes/battle.tscn`), click through the pre-fight screen (`click_node` on `BeginCombatPanel/BeginButton`), then force a win using the recipe in Global Constraints.

Then confirm with `execute_code`:
- `get_node('/root/Battle').current_round` → `1`
- `get_node('/root/Battle').enemy_familiar_data.familiar_name` → a real name, and **not** the same as `get_node('/root/Battle').player_familiar_data.familiar_name`
- `get_node('/root/Battle').bracket.rounds[0].matches[0].entrant_a.familiar_name` → a real name

Take a `runtime_screenshot` at the reward screen to confirm the loop still reaches it. Then `game_stop`.

- [ ] **Step 7: Commit**

```bash
git add scripts/battle_controller.gd
git commit -m "feat: run the round loop off a real bracket"
```

---

### Task 7: Scout before, reveal after

**Files:**
- Modify: `scripts/battle_controller.gd`
- Test: `scripts/tools/bracket_test.gd` (add one check for the pure resolution logic)

**Interfaces:**
- Consumes: `BracketSimulator.simulate()` (Task 4), `BracketOdds` (Task 3), `AIDrafter.apply_round_reward()` (Task 5), `Bracket`/`BracketRound`/`BracketMatch` (Tasks 1–2).
- Produces: `BracketResolver.scout_round(bracket_round: BracketRound) -> void` and `BracketResolver.resolve_round(bracket_round: BracketRound, round_completed: int, technique_pool: Array[Technique], passive_pool: Array[PassiveEffect], rng: RandomNumberGenerator) -> Array[Dictionary]` (one entry per resolved match: `{"winner": Familiar, "loser": Familiar, "was_upset": bool}`), in a new `scripts/bracket/bracket_resolver.gd`.

- [ ] **Step 1: Add the failing check**

Append `"resolver_scouts_and_resolves"` to `EXPECTED_CHECKS`, add `_check_resolver_scouts_and_resolves()` to `_init()`, and add:

```gdscript
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
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/bracket_test.gd 2>&1 | grep -E "PASSED|FAILED|SCRIPT ERROR|  - "
```

Expected: `SCRIPT ERROR` about unknown identifier `BracketResolver`.

- [ ] **Step 3: Create `scripts/bracket/bracket_resolver.gd`**

```gdscript
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
```

- [ ] **Step 4: Run the harness to verify it passes**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/bracket_test.gd 2>&1 | grep -E "PASSED|FAILED|SCRIPT ERROR|  - "
```

Expected: `ALL CHECKS PASSED (10/10)`.

- [ ] **Step 5: Wire scouting and resolving into `battle_controller.gd`**

Add the two pools the resolver needs — they already exist as `technique_reward_pool`/`passive_reward_pool` exports, so no new wiring is required. Add a field near `bracket`:

```gdscript
## Seeded per run so a round's upsets are reproducible when reward_seed is set.
var _bracket_rng: RandomNumberGenerator = RandomNumberGenerator.new()
```

In `_build_bracket()`, seed it alongside the generation RNG:

```gdscript
	if reward_seed != 0:
		_bracket_rng.seed = reward_seed
	else:
		_bracket_rng.randomize()
```

Scout the opening round at the end of `_build_bracket()`:

```gdscript
	BracketResolver.scout_round(bracket.rounds[0])
```

In `start_next_round()`, resolve the round the player just won **before** `bracket.advance_round(current_round)` (the advance needs every winner set first), and scout the new round after the player's next match is marked. The relevant slice becomes:

```gdscript
	var finished_match: BracketMatch = player_bracket_match()
	if finished_match != null:
		finished_match.winner = player_familiar_data
		finished_match.revealed = true

	_last_round_results = BracketResolver.resolve_round(
		bracket.rounds[current_round], current_round + 1,
		technique_reward_pool, passive_reward_pool, _bracket_rng)

	bracket.advance_round(current_round)
	current_round += 1

	for bracket_match in bracket.rounds[current_round].matches:
		if bracket_match.has_entrant(player_familiar_data):
			bracket_match.is_player_match = true
			break

	BracketResolver.scout_round(bracket.rounds[current_round])
```

(Note the marking loop now reads `bracket.rounds[current_round]`, since `current_round` has already been incremented — this replaces Task 6 Step 3's version, which indexed `current_round + 1` before the increment.)

Add the field it stores into, near `bracket`:

```gdscript
## Last round's off-screen results, for the reveal step (Task 10).
var _last_round_results: Array[Dictionary] = []
```

Then log them. **This is the reveal summary the spec's §6 step 4 calls for** — deliberately combat-log lines rather than a dedicated reveal screen, since the visual pass that would style such a screen is explicitly deferred behind the bracket (`GAME_DESIGN.md` §10). The player still sees every off-screen result and every upset, in the surface this project already uses for fight narration. Add at the end of `begin_reward_sequence()`:

```gdscript
	for result in _last_round_results:
		var upset_note: String = " (UPSET)" if result.was_upset else ""
		combat_log.add_entry("%s defeats %s.%s" % [
			result.winner.familiar_name, result.loser.familiar_name, upset_note
		], CombatLog.Source.PLAYER)
```

- [ ] **Step 6: Parse check and live verification**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit 2>&1 | grep -i "error" | grep -v "RID allocations\|ObjectDB instances\|resources still in use\|at: clear\|at: cleanup"
```

Then start the game, force a win (Global Constraints recipe), and check with `execute_code`:
- `get_node('/root/Battle').bracket.rounds[0].matches[1].odds_label` → one of the five labels, non-empty
- `get_node('/root/Battle').bracket.rounds[0].matches[1].revealed` → `true` after the round resolved
- `get_node('/root/Battle').bracket.rounds[1].matches[0].entrant_a.familiar_name` → a real name

- [ ] **Step 7: Commit**

```bash
git add scripts/bracket/bracket_resolver.gd scripts/battle_controller.gd scripts/tools/bracket_test.gd
git commit -m "feat: scout off-screen matches before the fight, resolve them after"
```

---

## Phase C — Bracket UI

### Task 8: Bracket screen scene and entrant rows

**Files:**
- Create: `scenes/bracket_screen.tscn`
- Create: `scripts/bracket/bracket_screen.gd`
- Modify: `scenes/battle.tscn` (add the screen as a hidden sibling)

**Interfaces:**
- Consumes: `Bracket`, `BracketRound`, `BracketMatch`; existing `TooltipLayer` (`hover_started(source: Control, text: String)`, `hover_ended(source: Control)`), `Familiar.species_affinities` (`Array[TagAffinity]`, each with `tag: RewardTag.Tag` and `weight: int`).
- Produces: `BracketScreen.setup(bracket: Bracket, round_index: int, selectable: bool) -> void`, `signal entrant_selected(familiar: Familiar)`, `signal dismissed`.

- [ ] **Step 1: Build the scene through the MCP toolkit**

Open `res://scenes/battle.tscn` (`scene_open`), then create the node tree with `scene_create_node`. Match `GameOverPanel`'s anchoring exactly — a top-anchored fixed box, **not** a full-rect anchor (`anchor_bottom` is `0`, not `1`; getting this wrong pushes the panel off-screen):

- `BracketScreen` — `VBoxContainer`, parent `.`, properties: `anchor_left: 0, anchor_top: 0, anchor_right: 1, anchor_bottom: 0, offset_left: 16, offset_top: 40, offset_right: -16, offset_bottom: 620, alignment: 0, visible: false`
- `BracketScreen/TitleLabel` — `Label`, `horizontal_alignment: 1`, `text: "Choose your familiar"`
- `BracketScreen/Body` — `HBoxContainer`, `size_flags_vertical: 3`
- `BracketScreen/Body/EntrantScroll` — `ScrollContainer`, `size_flags_horizontal: 3`, `size_flags_vertical: 3`
- `BracketScreen/Body/EntrantScroll/EntrantList` — `VBoxContainer`, `size_flags_horizontal: 3`
- `BracketScreen/Body/DetailPanel` — `VBoxContainer`, `custom_minimum_size: {"type":"Vector2","x":320,"y":0}`
- `BracketScreen/Body/DetailPanel/DetailName` — `Label`
- `BracketScreen/Body/DetailPanel/DetailPortrait` — `TextureRect`, `custom_minimum_size: {"type":"Vector2","x":96,"y":96}`, `stretch_mode: 5`, `size_flags_horizontal: 4`
- `BracketScreen/Body/DetailPanel/DetailTags` — `Label`, `autowrap_mode: 2`
- `BracketScreen/Body/DetailPanel/DetailStats` — `Label`
- `BracketScreen/Body/DetailPanel/DetailTechniques` — `Label`, `autowrap_mode: 2`
- `BracketScreen/Body/DetailPanel/DetailOdds` — `Label`
- `BracketScreen/Body/DetailPanel/SelectButton` — `Button`, `text: "Select Fighter"`, `size_flags_horizontal: 4`
- `BracketScreen/ContinueButton` — `Button`, `text: "Continue"`, `size_flags_horizontal: 4`, `visible: false`

Then `editor_save_scene`.

- [ ] **Step 2: Write `scripts/bracket/bracket_screen.gd`**

```gdscript
class_name BracketScreen
extends VBoxContainer

## The bracket view, used in two modes:
##   selectable = true  -- round 1's character select, with a Select
##                         Fighter button that commits the player's draft
##   selectable = false -- every later round's scouting view, read-only
##
## Hovering an entrant shows its odds and species tags through the shared
## TooltipLayer; clicking one pins the full detail panel.

signal entrant_selected(familiar: Familiar)
signal dismissed

@onready var title_label: Label = $TitleLabel
@onready var entrant_list: VBoxContainer = $Body/EntrantScroll/EntrantList
@onready var detail_name: Label = $Body/DetailPanel/DetailName
@onready var detail_portrait: TextureRect = $Body/DetailPanel/DetailPortrait
@onready var detail_tags: Label = $Body/DetailPanel/DetailTags
@onready var detail_stats: Label = $Body/DetailPanel/DetailStats
@onready var detail_techniques: Label = $Body/DetailPanel/DetailTechniques
@onready var detail_odds: Label = $Body/DetailPanel/DetailOdds
@onready var select_button: Button = $Body/DetailPanel/SelectButton
@onready var continue_button: Button = $ContinueButton

var tooltip_layer: TooltipLayer

var _selected: Familiar
var _odds_by_name: Dictionary = {}   # familiar_name -> String

func _ready() -> void:
	select_button.pressed.connect(_on_select_pressed)
	continue_button.pressed.connect(func() -> void: dismissed.emit())

## Rebuilds the whole screen for one round. Everything is torn down and
## rebuilt rather than diffed, since each row closes over a specific
## Familiar instance -- the same reasoning PriorityBuilder.setup() uses.
func setup(bracket: Bracket, round_index: int, selectable: bool) -> void:
	_selected = null
	_odds_by_name.clear()

	title_label.text = "Choose your familiar" if selectable else "Round %d — scouting" % (round_index + 1)
	select_button.visible = selectable
	continue_button.visible = not selectable

	for child in entrant_list.get_children():
		entrant_list.remove_child(child)
		child.queue_free()

	for bracket_match in bracket.rounds[round_index].matches:
		if not bracket_match.is_ready():
			continue
		_record_odds(bracket_match)
		_add_row(bracket_match.entrant_a, bracket_match)
		_add_row(bracket_match.entrant_b, bracket_match)
		_add_separator()

	_clear_detail()

## Both entrants share the match's single label, mirrored: the label is
## stored from entrant_a's point of view, so entrant_b gets its opposite.
func _record_odds(bracket_match: BracketMatch) -> void:
	if bracket_match.odds_label == "":
		return
	_odds_by_name[bracket_match.entrant_a.familiar_name] = bracket_match.odds_label
	_odds_by_name[bracket_match.entrant_b.familiar_name] = _mirror_label(bracket_match.odds_label)

func _mirror_label(label: String) -> String:
	match label:
		BracketOdds.LABEL_HEAVY_FAVORITE:
			return BracketOdds.LABEL_HEAVY_UNDERDOG
		BracketOdds.LABEL_FAVORITE:
			return BracketOdds.LABEL_UNDERDOG
		BracketOdds.LABEL_UNDERDOG:
			return BracketOdds.LABEL_FAVORITE
		BracketOdds.LABEL_HEAVY_UNDERDOG:
			return BracketOdds.LABEL_HEAVY_FAVORITE
	return BracketOdds.LABEL_TOSS_UP

func _add_row(familiar: Familiar, bracket_match: BracketMatch) -> void:
	var row := Button.new()
	row.text = "%s   %s" % [familiar.familiar_name, _odds_for(familiar)]
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if bracket_match.revealed and bracket_match.winner == familiar:
		row.text += "   (won)"

	row.pressed.connect(_on_row_pressed.bind(familiar))
	if tooltip_layer != null:
		row.mouse_entered.connect(func() -> void: tooltip_layer.hover_started(row, _tooltip_text(familiar)))
		row.mouse_exited.connect(func() -> void: tooltip_layer.hover_ended(row))

	entrant_list.add_child(row)

func _add_separator() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	entrant_list.add_child(spacer)

func _odds_for(familiar: Familiar) -> String:
	return _odds_by_name.get(familiar.familiar_name, "")

func _tooltip_text(familiar: Familiar) -> String:
	var odds: String = _odds_for(familiar)
	var lines: Array[String] = [familiar.familiar_name]
	if odds != "":
		lines.append(odds)
	lines.append(_tag_text(familiar))
	return "\n".join(lines)

func _tag_text(familiar: Familiar) -> String:
	if familiar.species_affinities.is_empty():
		return "No known affinities"
	var names: Array[String] = []
	for affinity in familiar.species_affinities:
		names.append(RewardTag.Tag.keys()[affinity.tag].capitalize())
	return ", ".join(names)

func _on_row_pressed(familiar: Familiar) -> void:
	_selected = familiar
	detail_name.text = familiar.familiar_name
	detail_portrait.texture = familiar.sprite
	detail_tags.text = "Playstyle: %s" % _tag_text(familiar)
	detail_stats.text = "HP %d   Power %d   Defense %d   Speed %d   Focus %d" % [
		familiar.max_hp, familiar.power, familiar.defense, familiar.speed, familiar.focus
	]

	var technique_names: Array[String] = []
	for technique in familiar.techniques:
		technique_names.append(technique.technique_name)
	detail_techniques.text = "Techniques: %s" % ", ".join(technique_names)

	var odds: String = _odds_for(familiar)
	if odds == "":
		detail_odds.text = ""
	else:
		detail_odds.text = "Matchup: %s" % odds

	select_button.disabled = false

func _clear_detail() -> void:
	detail_name.text = ""
	detail_portrait.texture = null
	detail_tags.text = ""
	detail_stats.text = ""
	detail_techniques.text = ""
	detail_odds.text = ""
	select_button.disabled = true

func _on_select_pressed() -> void:
	if _selected == null:
		return
	entrant_selected.emit(_selected)
```

- [ ] **Step 3: Attach the script**

Use `node_set_script` on `BracketScreen` with `res://scripts/bracket/bracket_screen.gd`, then `editor_save_scene`.

- [ ] **Step 4: Parse check**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit 2>&1 | grep -i "error" | grep -v "RID allocations\|ObjectDB instances\|resources still in use\|at: clear\|at: cleanup"
```

Expected: empty output.

- [ ] **Step 5: Commit**

```bash
git add scenes/battle.tscn scripts/bracket/bracket_screen.gd
git commit -m "feat: bracket screen scene with entrant rows and detail panel"
```

---

### Task 9: Character select replaces the auto-pick

**Files:**
- Modify: `scripts/battle_controller.gd`

**Interfaces:**
- Consumes: `BracketScreen.setup()`, `BracketScreen.entrant_selected` (Task 8).
- Produces: `battle_controller.gd` no longer defines `_auto_pick_entrant()`.

- [ ] **Step 1: Add the screen reference**

Near the other `@onready` panel references in `scripts/battle_controller.gd`:

```gdscript
@onready var bracket_screen: BracketScreen = $BracketScreen
```

In `_ready()`, before `await _start_new_run()`:

```gdscript
	bracket_screen.tooltip_layer = tooltip_layer
```

- [ ] **Step 2: Replace the auto-pick with the real screen**

Delete `_auto_pick_entrant()` entirely. In `_build_bracket()`, replace the `_auto_pick_entrant(rng)` call with nothing (scouting still happens there), and add this coroutine:

```gdscript
## Round 1's character select. Every round-1 match is already scouted by
## the time this shows, so the player can see each pairing's odds while
## choosing -- the pick's own match then stops being scouted material and
## becomes a real fight.
func _select_entrant() -> void:
	panels.visible = false
	speed_toggle_button.visible = false
	log_scroll.visible = false

	bracket_screen.setup(bracket, 0, true)
	bracket_screen.visible = true

	var chosen: Familiar = await bracket_screen.entrant_selected

	bracket_screen.visible = false

	for bracket_match in bracket.rounds[0].matches:
		if bracket_match.has_entrant(chosen):
			bracket_match.is_player_match = true
			bracket_match.odds_label = ""
			player_familiar_data = chosen
			enemy_familiar_data = bracket_match.other_entrant(chosen)
			break
```

- [ ] **Step 3: Call it from `_start_new_run()`**

In `_start_new_run()`, immediately after `_build_bracket()`, add:

```gdscript
	await _select_entrant()
```

Everything after that already reads `player_familiar_data`/`enemy_familiar_data` and needs no change.

- [ ] **Step 4: Parse check and live verification**

Parse check as before, then start the game. Expected: the bracket screen appears first, listing 16 entrants with odds labels. Click a row (`input_simulate` with `click_node` on `BracketScreen/Body/EntrantScroll/EntrantList` is not addressable per-row, so use a coordinate `click` from a `runtime_screenshot`), confirm the detail panel fills in, then `click_node` on `BracketScreen/Body/DetailPanel/SelectButton`.

Confirm with `execute_code`:
- `get_node('/root/Battle').player_familiar_data.familiar_name` → the familiar you clicked
- `get_node('/root/Battle').enemy_familiar_data.familiar_name` → a different familiar
- `get_node('/root/Battle').bracket.rounds[0].player_match() != null` → `true`

Then screenshot to confirm the pre-fight screen follows, and `game_stop`.

- [ ] **Step 5: Commit**

```bash
git add scripts/battle_controller.gd
git commit -m "feat: bracket character select replaces the random draft"
```

---

### Task 10: Scouting screen between rounds

**Files:**
- Modify: `scripts/battle_controller.gd`

**Interfaces:**
- Consumes: `BracketScreen.setup(bracket, round_index, false)`, `BracketScreen.dismissed` (Task 8).
- Produces: nothing new.

- [ ] **Step 1: Add the scouting step**

In `scripts/battle_controller.gd`:

```gdscript
## Read-only view of the round the player is about to fight: every other
## match's odds and each entrant's species tags, free and always
## available (GAME_DESIGN.md §9.3).
func _show_scouting() -> void:
	panels.visible = false
	speed_toggle_button.visible = false
	log_scroll.visible = false

	bracket_screen.setup(bracket, current_round, false)
	bracket_screen.visible = true

	await bracket_screen.dismissed

	bracket_screen.visible = false
```

- [ ] **Step 2: Call it before the pre-fight screen**

In `advance_to_priority_editor()`, add as the very first line of the function, before `_priority_rules_edited_this_round = false`:

```gdscript
	await _show_scouting()
```

This puts scouting between the reward/stat screens and the pre-fight screen, matching the spec's step order (reward → scout → pre-fight → fight).

- [ ] **Step 3: Parse check and live verification**

Parse check, then force a round win (Global Constraints recipe) and click through the reward card and stat-upgrade confirm. Confirm the scouting screen then appears, shows the round's other matches with odds labels, and that `click_node` on `BracketScreen/ContinueButton` dismisses it into the "Ready to fight?" screen.

- [ ] **Step 4: Commit**

```bash
git add scripts/battle_controller.gd
git commit -m "feat: between-round scouting screen"
```

---

## Phase D — Final boss

### Task 11: Final boss encounter

**Files:**
- Create: `resources/familiars/final_boss_stub.tres`
- Modify: `scripts/battle_controller.gd`
- Modify: `scripts/bracket/bracket.gd` (nothing structural — `boss_familiar` already exists from Task 1)

**Interfaces:**
- Consumes: `Bracket.boss_familiar` (Task 1), `battle_controller.player_bracket_match()` (Task 6).
- Produces: `battle_controller.gd` — `@export var final_boss: Familiar`, `var facing_boss: bool`, `func start_boss_fight() -> void`.

- [ ] **Step 1: Author the placeholder boss**

Create `resources/familiars/final_boss_stub.tres` by duplicating an existing familiar in the Godot editor (Mallegrav is a reasonable base — high Power and Defense) and renaming it. Set `familiar_name` to `"The Champion"`, and raise its stats to roughly double a normal entrant's: `max_hp: 120`, `power: 18`, `defense: 18`, `speed: 12`, `focus: 15`. Keep its inherited techniques, priority rules, and passive as-is.

This is deliberately placeholder content — a real authored "absurd showdown" kit is its own later pass (spec §8). What matters here is that the encounter exists and resolves.

Assign it to `battle_controller.gd`'s new export in the Inspector after Step 2.

- [ ] **Step 2: Add the boss fields and wire generation**

In `scripts/battle_controller.gd`, next to `full_roster`:

```gdscript
## The fixed final encounter after the bracket's four rounds. Placeholder
## content for now -- see the design spec §8.
@export var final_boss: Familiar

## True once the bracket is won and the boss fight is the active match.
var facing_boss: bool = false
```

In `_build_bracket()`, pass it to generation and reset the flag:

```gdscript
	bracket = Bracket.generate(full_roster, rng, final_boss)
	facing_boss = false
```

- [ ] **Step 3: Route the final win into the boss fight**

In `check_victory()`, the branch that currently runs when `current_round` is the last round shows the Game Over screen. Replace that branch's body so it starts the boss fight instead — but only once. The win branch becomes:

```gdscript
	if engine.winner == player:
		if current_round < bracket.rounds.size() - 1:
			combat_log.add_entry("Victory! %s is defeated. Prepare for the next round!" % enemy.familiar.familiar_name, CombatLog.Source.PLAYER)

			await get_tree().create_timer(1.5).timeout
			start_next_round()
			return true

		if not facing_boss and bracket.boss_familiar != null:
			combat_log.add_entry("Victory! %s is defeated. The champion awaits." % enemy.familiar.familiar_name, CombatLog.Source.PLAYER)

			await get_tree().create_timer(1.5).timeout
			start_boss_fight()
			return true

		phase = Phase.BATTLE_OVER
		combat_log.add_entry("Victory! %s is defeated." % enemy.familiar.familiar_name, CombatLog.Source.PLAYER)
		await get_tree().create_timer(2.5).timeout
		show_game_over("You win! %s has been defeated." % enemy.familiar.familiar_name)
		return true
```

- [ ] **Step 4: Add `start_boss_fight()`**

```gdscript
## The fixed encounter after the bracket itself is won. No scouting and no
## off-screen resolution -- there is no rest of the round to resolve --
## and no reward follows it, win or lose (GAME_DESIGN.md §9.2 step 7).
func start_boss_fight() -> void:
	facing_boss = true

	var winning_match: BracketMatch = player_bracket_match()
	if winning_match != null:
		winning_match.winner = player_familiar_data
		winning_match.revealed = true

	enemy_familiar_data = bracket.boss_familiar.duplicate()

	begin_reward_sequence()

	player = Combatant.new(player_familiar_data)
	update_hp_display(player)

	enemy = Combatant.new(enemy_familiar_data)
	enemy_name_label.text = enemy.familiar.familiar_name
	enemy_portrait.texture = enemy.familiar.sprite
	update_hp_display(enemy)

	player.opponent = enemy
	enemy.opponent = player
	engine = BattleEngine.new(player, enemy)
```

- [ ] **Step 5: Skip scouting before the boss**

`advance_to_priority_editor()` now calls `_show_scouting()` unconditionally, but there is nothing to scout before the boss. Change that first line to:

```gdscript
	if not facing_boss:
		await _show_scouting()
```

- [ ] **Step 6: Assign the boss resource in the Inspector**

With `battle.tscn` open in the editor, select the `Battle` root node and set its new `Final Boss` export to `res://resources/familiars/final_boss_stub.tres`. Save the scene.

- [ ] **Step 7: Parse check and live verification**

Parse check as before. Then verify the boss path with `execute_code` rather than playing four full rounds: start the game, select an entrant, begin the fight, then force the player through the bracket by setting `current_round` to the last index and forcing a win:

```
get_node('/root/Battle').set('current_round', 3)
get_node('/root/Battle').enemy.set('current_hp', 0)
get_node('/root/Battle').call('check_victory')
```

Confirm `get_node('/root/Battle').facing_boss` → `true` and `get_node('/root/Battle').enemy_familiar_data.familiar_name` → `"The Champion"`. Then force one more win and confirm the Game Over screen appears (screenshot) rather than a fifth round starting.

- [ ] **Step 8: Commit**

```bash
git add resources/familiars/final_boss_stub.tres scenes/battle.tscn scripts/battle_controller.gd
git commit -m "feat: final boss encounter after the bracket"
```

---

### Task 12: Documentation pass

**Files:**
- Modify: `.claude/GAME_DESIGN.md` (§9, §10)
- Modify: `.claude/DEVLOG.md`
- Modify: `.claude/DECISIONS.md`
- Modify: `.claude/LEARNING_ROADMAP.md`

- [ ] **Step 1: Mark §9 implemented in `GAME_DESIGN.md`**

In §9.3, replace the "Open questions to settle before implementing" block with what was actually settled: real `BattleEngine` simulation for margin, `0.5 + 0.5 * margin` for advance probability, five coarse labels, free always-visible scouting. Mark §9.1/§9.2/§9.3 **Implemented**.

In §10, move the bracket out of "Next" into the Done list, and promote the visual style pass to next.

- [ ] **Step 2: Add a `DEVLOG.md` entry**

Add a session entry at the top covering: what the bracket replaced (`opponent_lineup`), the scout-then-reveal split and why odds are rolled rather than taken as verdicts, the placeholder AI progression and its deliberate simplicity, the placeholder boss, and anything that actually went wrong during implementation (record real bugs found, in the style of prior entries — these are the most valuable part of that file).

- [ ] **Step 3: Add `DECISIONS.md` entries**

Two durable ones: (1) the bracket is Resource-based (`Bracket`/`BracketRound`/`BracketMatch`) rather than flat-array-plus-index-math, and why; (2) off-screen matches are simulated for margin then rolled for outcome, so upsets stay possible — with the note that `BracketResolver.resolve_round()` re-simulates rather than caching the scouted probability, and why that's safe (deterministic sim, unchanged builds between scout and reveal).

- [ ] **Step 4: Update `LEARNING_ROADMAP.md`**

Mark Step 7 (bracket) done with a short summary; note that Step 9 (AI drafting) now has a concrete integration point (`AIDrafter.apply_round_reward()`) to replace.

- [ ] **Step 5: Run the full harness one final time**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/bracket_test.gd 2>&1 | grep -E "PASSED|FAILED|SCRIPT ERROR|  - "
```

Expected: `ALL CHECKS PASSED (10/10)`.

Also re-run the balance harness to confirm the bracket work didn't disturb combat:

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/tools/balance_test.gd 2>&1 | grep -A 20 "=== Summary ==="
```

Expected: win rates broadly in the 40–60% band with no `DOOMED` familiar, matching the last recorded pass.

- [ ] **Step 6: Commit**

```bash
git add .claude/
git commit -m "docs: bracket implementation notes and decisions"
```
