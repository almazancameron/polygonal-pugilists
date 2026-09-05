# Balance-test harness for the 16-familiar content pass

## Context

The content pass in progress will eventually give Pixel Pugilists its full 16-entrant
bracket roster (`GAME_DESIGN.md` §8.5: each entrant gets one species, one conditioned
priority rule, one unconditioned fallback technique). Right now 3 of the 16 are
actually complete (`resources/familiars/guubal.tres`, `twerpent.tres`, `ashwing.tres`);
13 more don't exist yet. Before the bracket structure gets built on top of this roster,
the developer wants a way to catch obvious balance outliers — a familiar that wins or
loses an overwhelming share of its fights — by simulating every familiar against every
other one.

This is good timing for it mechanically: combat in this game has **zero randomness**.
Damage (`raw_damage² / (raw_damage + defense)`, technique.gd:88), technique choice
(`Combatant.choose_technique()`, combatant.gd:231), and passive/status resolution are
all deterministic given fixed Familiar data. That means a full round-robin needs no
repeated random trials — only two determinism-relevant variables exist per pair: which
familiar is A vs B, and who wins the opening speed tie (Speed comparison, with a
first-act-override status able to break ties). So the entire sample space is small and
exhaustive: **every unordered pair of familiars, run twice (each side going first
once)**. At 16 familiars that's C(16,2) × 2 = 240 battles, done instantly headless.

As of the current commit (`b896760`, "passives, ashwing familiar, rebalance/refactor"),
all three existing familiars are fully built, and the developer has hand-tuned a
rock-paper-scissors triangle they're happy with: **Ashwing beats Twerpent** (offensive
burst beats offensive scaling), **Twerpent beats Guubal** (offensive scaling beats
defensive scaling), **Guubal beats Ashwing** (defensive scaling beats burst). This is
the concrete shape of the ship-time design goal for the full 16-familiar roster: since
the bracket is a character-select, every familiar should have *some* matchup(s) it's
favored in and some it's unfavored in by the time all 16 exist — some can run stronger
or weaker at the start of a bracket run than others, that's fine, but no single pick
should be doomed from round 1 with zero winning matchups anywhere in the field. That
reframes what the harness needs to flag: an aggregate win rate on its own (Part 2's
`win_rate >= 0.75`/`<= 0.25` threshold) doesn't distinguish "weak overall but has a
niche it wins in" from "loses to literally everyone" — only the second is the real
problem this triangle is meant to avoid. Part 2 adds a dedicated check for that: any
familiar with zero matchups won (in either turn order) against the whole field gets
flagged as doomed, independent of its aggregate win-rate number.

The developer has already observed in manual testing that a small stat nudge — +10 HP,
+2 Power — can flip a fight's outcome outright. That's expected given the deterministic
formula above: HP and post-mitigation damage both round to integers, so a stat change
that shifts "dies in 5 hits" to "dies in 4 hits" (or wins a damage race by one turn)
doesn't gently shift a win probability, it flips a hard boolean. Because of that,
per `GAME_DESIGN.md` §5.2's stat line still being **OPEN/PLAYTEST**, the plan adds a
second kind of experiment on top of the fixed-stat round-robin: a per-stat sensitivity
sweep, plus a stat-neutral baseline comparison, so the harness can show not just *who*
wins too often but *how fragile* that result is to the stat values currently OPEN for
iteration.

The one real obstacle: `scripts/battle_controller.gd` (`extends Control`) is the only
thing that currently knows how to run a full battle from start to victory, and it's
wired directly into `scenes/battle.tscn` — ~14 `@onready` node paths plus `await
get_tree().create_timer(...)` calls for log/HP-bar pacing. It cannot be instantiated
or driven outside that scene, so it can't be reused as-is for a headless batch of 240
fights. The actual game *rules*, though, already live entirely on scene-independent
`RefCounted` objects (`Combatant`, `Technique`, `PriorityRule`, `Condition`,
`PassiveEffect`) — `battle_controller.gd` itself only contributes turn *sequencing*
(whose turn is next, when upkeep ticks, when the fight ends) plus UI/pacing. Per the
user's decision, that sequencing gets pulled out into a shared, scene-independent
`BattleEngine` that both the live UI and the new headless harness drive — avoiding two
copies of turn-order logic silently drifting apart as combat rules keep evolving.

## Part 1 — Extract `BattleEngine` (scripts/battle_engine.gd)

A new `class_name BattleEngine extends RefCounted` that owns exactly the sequencing
logic currently inlined in `battle_controller.gd`, with all UI/log/pacing stripped out
and no `await get_tree().create_timer(...)` calls anywhere in it:

- `determine_first_actor(player, enemy) -> Combatant` — ports `_determine_first_actor()`
  (battle_controller.gd:127-139) verbatim; still checks `has_first_act_override()` before
  falling back to `effective_stat(Familiar.Stat.SPEED)`.
- `begin_battle() -> Array[String]` — ports `begin_fight()`'s non-UI half: fires
  `BATTLE_START` passives on both sides via `check_passives()`, sets
  `current_first_actor`, returns any passive messages as plain strings instead of
  pushing them to a `CombatLog`.
- `take_turn(actor, target) -> Array[String]` — ports `take_turn()`
  (battle_controller.gd:258-305): passive-limit reset, stun check, `choose_technique()`,
  `technique.execute()` step callables, `TURN_START`/`TURN_END` passives — same
  ordering, just returning message strings instead of calling `combat_log.add_entry()`
  and awaiting a timer between steps.
- `run_upkeep(combatant) -> Array[String]` — ports `run_upkeep()`
  (battle_controller.gd:230-253) minus the `await get_tree().create_timer(0.6)` between
  status ticks.
- `advance_turn(actor) -> Combatant` — ports the exchange-completion logic from
  `advance_turn()` (battle_controller.gd:205-224): same actor keeps going until the
  exchange completes, then `determine_first_actor()` re-runs.
- `check_victory() -> bool` / `winner: Combatant` (null until decided) — ports
  `check_victory()`'s defeat-detection and `BATTLE_END` passive firing
  (battle_controller.gd:326-350), without the bracket-round-advance and
  `get_tree().quit()` branches (those stay meta-progression concerns in
  `battle_controller.gd`, since `BattleEngine` only ever resolves one fight).
- `run_to_completion(max_turns: int = 1000) -> Dictionary` — new convenience method,
  used by the harness (not by the live UI, which needs per-step pacing): drives
  `begin_battle` → loop of `run_upkeep`/`take_turn`/`advance_turn` until
  `check_victory()` or `max_turns` is exceeded. Returns
  `{winner: Combatant, turns: int, stalemate: bool}`. The turn cap is new behavior —
  today's game has no such guard — but it's cheap insurance for the harness against a
  content-pass familiar whose priority rules have no true damaging fallback.

`battle_controller.gd` then calls into `BattleEngine` for every one of these steps
instead of inlining them, keeping only what's actually its job: UI updates
(`update_hp_display`, `combat_log.add_entry`), pacing (`await
get_tree().create_timer(...)`), and bracket/meta concerns (`start_next_round`,
upgrade-select). This should be a behavior-preserving refactor — the live game should
look and log identically before and after.

**Verification for Part 1:**
- `godot --headless --check-only --quit` for parse errors.
- A throwaway `scripts/_verify_battle_engine.gd` (`extends SceneTree`, deleted after
  use, per the project's established convention) that runs a fixed Guubal-vs-Twerpent
  battle through `BattleEngine.run_to_completion()` and asserts a sane result (winner
  decided, turn count > 0, no stalemate).
- An actual interactive playtest: launch `scenes/battle.tscn` and play a fight to
  confirm log pacing, HP bars, and passive messages are unchanged from before the
  refactor.

## Part 2 — Headless round-robin harness (scripts/tools/balance_test.gd)

A new `extends SceneTree` script, **not** a throwaway (kept in the repo, named outside
the `_verify_*` glob so it's clearly meant to be re-run after every content update):

1. Load every `.tres` under `resources/familiars/` via `ResourceLoader`/`DirAccess`.
   Skip anything missing a `familiar_name` or with an empty `techniques`/
   `priority_rules` array (catches an in-progress stub familiar that hasn't been fully
   authored yet) and print a warning naming the skipped file, rather than crashing.
2. Structure the pairing/aggregation logic as a reusable
   `run_round_robin(familiars: Array[Familiar]) -> Dictionary` function — Part 3 below
   calls this same function repeatedly with substituted stat values, rather than
   duplicating the pairing loop. For every unordered pair in the given list, build two
   fresh `Combatant`s (mirroring `battle_controller._ready()`'s `Combatant.new(...)` +
   opponent-linking) and run `BattleEngine.run_to_completion(200)` twice — once with
   each side as `current_first_actor`'s tiebreak winner by construction order, so both
   "A acts on ties" and "B acts on ties" get covered.
3. Record each result: winner, loser, turn count, stalemate flag.
4. **Flag order-sensitive matchups.** Step 2's "run twice, swap who wins the
   construction-order tiebreak" already covers every pair; for most of them the two runs
   are guaranteed to agree, but not for the reason originally assumed here — a genuine
   Speed tie (`effective_stat(Familiar.Stat.SPEED)` equal on both sides, and neither
   holding a `has_first_act_override()` at battle start) is the most common cause, but
   not the only one. A real found case: `check_victory()` favors whichever side is
   "player" on a genuine **mutual KO** (both sides reach 0 HP within the same step —
   concretely, a lethal hit whose target has a retaliate-on-hit status like Thorns,
   which fires unconditionally with no `is_defeated()` guard, killing the attacker right
   back before `check_victory()` is ever polled) — that's an intentional rule for the
   live game (the player should win a mutual KO), but it's a second, independent source
   of the exact same symptom the round-robin sees: swapping which side is "player" flips
   the recorded winner. So this check flags **any** disagreement between the two runs
   regardless of cause, and separately notes whether it was a genuine Speed tie (the
   known, understood case) or not (worth tracing by hand the way the actual Carapax vs.
   Twerpent case was — see `DEVLOG.md`). Distinct from the win-rate outlier and
   hard-counter/doomed checks below — a pair can be perfectly "fair" on aggregate (each
   side wins one of the two runs) while still being real information: that specific
   matchup's outcome is currently decided by an artifact of the harness's own construction
   order, not by either kit or stat line, worth knowing before the bracket (§9) puts real
   stakes on a single simulated fight between two such familiars.
5. Aggregate per familiar: wins, losses, stalemates, `win_rate = wins / (wins +
   losses)`. Flag as an outlier when `win_rate >= 0.75` or `<= 0.25` (a named constant
   at the top of the script — easy to retune once real data exists).
6. Build the full win/loss matrix (who-beats-whom for every pair) and separately flag
   any single matchup that's a clean sweep in both orderings — a "hard counter" that
   can hide inside an otherwise-average aggregate win rate. From that same matrix, also
   flag any familiar with **zero** matchups won anywhere in the field (in either turn
   order) as "doomed" — a distinct, higher-priority flag from the aggregate-win-rate
   outlier check, since it's the specific failure mode the current
   Ashwing/Twerpent/Guubal triangle is meant to avoid: a familiar can run a low overall
   win rate without being doomed, as long as it has at least one matchup it reliably
   wins.
7. Print a summary table (Familiar | W | L | Stalemates | Win% | Flag) and the matrix
   to stdout, plus a separate list of order-sensitive pairs from step 4. Also write
   a CSV to a new `balance_reports/<timestamp>.csv` via `FileAccess.open(path,
   FileAccess.WRITE)` — this project has no existing `FileAccess` usage, so this
   introduces that pattern for the first time.

**Verification for Part 2:** run it now, against the 3 currently-complete familiars
(Guubal, Twerpent, Ashwing) as an end-to-end smoke test — this is a real, useful check
since the expected result is already known (the hand-tuned triangle), not just "does it
run without crashing." Also confirms the stub-skipping logic works by pointing it at a
deliberately incomplete/malformed familiar resource once, before there's a full
16-familiar roster to run it against for real.

Step 4's order-sensitivity flagging has a real, already-authored case to check it
against: Ashwing and Mallegrav currently share `speed = 9` (a genuine Speed tie).
Confirmed as of the 7-familiar roster (`DEVLOG.md`): Ashwing-vs-Mallegrav flags as
expected (`speed_tie: true`), and a second, real, *non*-Speed-tie case was found the same
way — Carapax vs. Twerpent (`speed_tie: false`), caused by a mutual KO (Twerpent's lethal
hit into Carapax's Thorns retaliating right back before `check_victory()` is ever
polled), not by anything wrong with the check itself. Both are correct, intentional
findings, not false positives — this is exactly the kind of case this step exists to
surface.

## Part 3 — Stat-sensitivity experiments (same script, built on `run_round_robin`)

Both experiments produce variant `Familiar` data purely in memory
(`familiar.duplicate()` then overwrite the relevant `@export` stat field) — nothing on
disk is touched, and each variant is fed straight into the same `run_round_robin()`
from Part 2.

**3a. Stat-neutral baseline.** One extra full round-robin pass where every loaded
familiar's stats are overwritten to one shared line (`Familiar.gd`'s own schema
defaults: `max_hp=50, power=10, defense=5, speed=10, focus=10`) while each familiar
keeps its own techniques/priority_rules/passives untouched. Comparing a familiar's
win rate here against its win rate in Part 2's real-stat run separates two different
kinds of outlier: a big gap means the stat line is doing the work (kit is fine, numbers
are off); a small gap means the technique/passive kit itself is over- or under-tuned
regardless of stats.

**3b. Per-stat sweep.** For each familiar and each of `power`, `defense`, `speed`,
`max_hp` in turn: hold every other familiar (the "field") at its authored baseline,
generate a small run of variants of just that one familiar by stepping the chosen stat
through a fixed range of small absolute deltas around its authored value — not
percentages, since (per the developer's own testing) the outcome-flipping threshold can
sit inside a range a percentage-based sweep would step right over. Default step sizes
(named constants, easy to retune): Power ±1/±2/±3, Max HP ±5/±10/±15, Defense
±1/±2/±3, Speed ±1/±2/±3. Run `run_round_robin()` once per delta with that one variant
substituted in for the familiar under test, and record its win rate against the
unchanged field at each step.

Report one table per stat: rows are familiars, columns are the deltas tested, cells are
win rate at that delta, plus a trailing "swing" column (`max - min` win rate across the
row) with the table sorted by swing descending — this puts the most stat-fragile
familiar/stat combinations at the top, directly surfacing the knife-edge behavior
already seen in manual testing rather than requiring it to be spotted by eye. Flag any
row whose swing exceeds a threshold (e.g. 30 percentage points, another named constant)
as high-sensitivity, separately from Part 2's win-rate outlier flag — a familiar can be
perfectly balanced on average at its authored stats and still be flagged here for
sitting right next to a cliff.

Per `CLAUDE.md`'s guidance for OPEN/PLAYTEST work, these sweep results are meant to
feed a playtest note (or `GAME_DESIGN.md` §11) about where the stat line is fragile —
not to get hardcoded into any kind of auto-tuning logic.

**Verification for Part 3:** smoke-test the same way as Part 2 — with only Guubal and
Twerpent loaded, run the stat-neutral baseline and a sweep of Guubal's Power across a
couple of steps, and confirm the win rate actually changes at the step where manual
testing already showed a flip. That's a concrete, checkable success condition for this
part before trusting it against the full 16-familiar roster later.

## Running the harness

Run with `godot --headless --script res://scripts/tools/balance_test.gd` from the
project directory (same binary as the existing `--check-only`/`_verify_*` workflow).
Note: `.claude/settings.json`'s current allowlist only covers `--check-only --quit` and
`--script res://scripts/_verify_*`, so the first run of this differently-named,
differently-located script will need a one-time manual approval (or the allowlist can
be extended afterward if this becomes a routine command). Because Part 3 multiplies
the number of battles run (one round-robin per stat-delta per familiar, on top of
Parts 2 and 3a's single passes), consider a flag or commented-out toggle to skip the
Part 3b sweep on quick runs and only run it deliberately.

## Deferred / explicitly out of scope

- Multiple builds per familiar — not needed since §8.5 gives each of the 16 starting
  entrants exactly one fixed priority-rule set, not a build choice.
- §9.3's "simulated off-screen fights" (a win-probability roll derived from stats, used
  for in-run bracket matches the player doesn't watch) — a different, lighter-weight
  mechanism for a different purpose; this harness runs the real combat engine instead.
- Any automatic rebalancing/suggestion logic — the harness surfaces data; judging
  whether an outlier is a bug or intended (e.g., a glass cannon meant to run hot) stays
  a human call.
- The actual full 240-battle run and its analysis — that happens once the content pass
  produces all 16 familiars; this plan only covers building and smoke-testing the
  harness now.
