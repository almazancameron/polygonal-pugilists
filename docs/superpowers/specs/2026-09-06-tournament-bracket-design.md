# Tournament Bracket — Design

**Date:** 2026-09-06
**Status:** approved, not yet implemented
**Scope:** Pixel Pugilists

## 1. Goal

`GAME_DESIGN.md` §9 (Tournament structure) is the last unbuilt piece of
Milestone 1: a single-elimination bracket of 16 entrants that doubles as the
character-select screen, with matches the player doesn't play resolved
off-screen and scouted before their own fight. It replaces
`battle_controller.gd`'s current `full_roster`/`_randomize_matchup()` random
gauntlet, which was always a deliberate throwaway stand-in
(`DECISIONS.md`).

The question this design settles: **how is the bracket represented, how do
off-screen matches get resolved and scouted, and how does that connect to
the round loop that already exists** (reward screen → priority editor →
pre-fight screen → fight, all built and working).

## 2. Scope

**In scope**

- `Bracket`/`BracketRound`/`BracketMatch` data model and generation from
  `full_roster` (16 entries required).
- Character-select screen: browse the generated round-1 bracket, hover for a
  tooltip (odds + species tags), click to pin a detail panel, select an
  entrant to start the run as.
- Off-screen match resolution: real `BattleEngine` simulation for margin,
  mapped to a 5-bucket odds label, then a dice roll (using the same margin,
  continuously) for the true winner — allowing upsets.
- Scouting screen: same hover/click component as character-select, reused
  every round, minus the select button, for that round's non-player matches.
- Reveal step after the player's own match: roll every other match in the
  round, apply the real reward system automatically to each AI winner,
  advance winners into next round's matches.
- Final boss: a real fixed encounter slot in the flow (state machine, win/
  loss handling) with a placeholder `Familiar` — no scouting/off-screen sim,
  since it's the player's own match only.
- Retiring `full_roster`'s randomize-and-pick-five role; `full_roster` stays
  as the 16-entrant pool `Bracket.generate()` draws from.

**Out of scope**

- Authoring the final boss's real kit — placeholder stats/techniques now,
  real content is its own later pass (same status as traits/augments).
- A visual style pass matching `assets/ui_mockup/` — deprioritized behind
  the bracket per `GAME_DESIGN.md` §10, same as before.
- Any change to the reward system, priority editor, or per-fight combat flow
  themselves — all three are complete and this design integrates with them
  as-is.
- Scouting/odds costing a resource, or being hideable — settled as free and
  always visible (no economy exists in this project, §0.3).
- Persisting a bracket across app restarts — a run's bracket lives in memory
  for that run only, same as everything else `_start_new_run()` resets.

**Deferred with a reason**

- Exact HP-margin-to-probability formula and the 5-bucket thresholds (§4.3)
  are OPEN/PLAYTEST, same as every other numeric-feel question in this
  project (`CLAUDE.md`) — implemented as a small, isolated, easily-retuned
  function rather than scattered through the flow, and flagged for revisit
  once real games are played against a real bracket.
- Coaching/intervention (`LEARNING_ROADMAP.md` §6) stays out of scope; the
  bracket gives it something to happen *between*, but building it is a
  separate future decision, not implied by this design.

## 3. Approach

Three decisions were weighed and settled across the brainstorm that
produced this spec (see conversation for the alternatives considered):

1. **Bracket data model**: small purpose-built Resources
   (`Bracket`/`BracketRound`/`BracketMatch`), not a flat array with index
   math. Matches this project's existing convention (`Technique`,
   `Condition`, `PriorityRule`, `RewardTag` are all small, single-purpose
   Resource/RefCounted classes) — "who do I face next" and "what were the
   other results" become field lookups on real objects, not derived
   arithmetic scattered through `battle_controller.gd`.
2. **Off-screen resolution**: a hybrid of real simulation and a probability
   roll, not stat-comparison odds alone and not a full simulation taken as
   final. `BattleEngine.run_to_completion()` is cheap enough to run for
   every off-screen match (≤11 per run, ~7.5ms each per
   `scripts/tools/balance_test.gd`'s measured cost) that there's no reason
   to fall back to a cruder stat formula — but taking the sim result as
   final would remove the "occasional unclear outcomes and upsets" §9.3
   explicitly wants, so its margin becomes odds instead of a verdict.
3. **Scouting UI**: reuse the existing `TooltipLayer`/`TooltipPanel`
   hover system rather than inventing a new always-visible label UI —
   consistent with how every other piece of at-a-glance info in this
   project (status icons, reward card details) already works, and matches
   the developer's own mockup (`assets/ui_mockup/bracket_mockup.png`): a
   list you browse, hover for a quick read, click to pin a detail panel.

## 4. Data model

### 4.1 `BracketMatch` (new `Resource`, `scripts/bracket/bracket_match.gd`)

```gdscript
@export var entrant_a: Familiar       # null until a previous round resolves into it
@export var entrant_b: Familiar       # null until a previous round resolves into it
@export var winner: Familiar          # null until this match resolves
@export var odds_label: String        # "" until scouted; one of ODDS_LABELS (§4.3)
@export var revealed: bool = false    # true once the true winner is known
var is_player_match: bool = false     # not exported -- decided at runtime by character select, never authored
```

`revealed` is the one field that distinguishes "scouted" from "resolved":
`odds_label` can be set (scouted) while `winner` is still null and
`revealed` is still false. The player's own round-1 match does get an
`odds_label` set briefly during character select (§5 scouts all 8 matches
before anyone's picked a side) — it's just never read again once that
match becomes `is_player_match`, since there's nothing to scout about a
fight you're playing.

### 4.2 `BracketRound` / `Bracket` (new `Resource`s)

```gdscript
# bracket_round.gd
@export var matches: Array[BracketMatch] = []

# bracket.gd
@export var rounds: Array[BracketRound] = []   # always 4: 8, 4, 2, 1 matches
@export var boss_familiar: Familiar             # the fixed final-boss encounter
```

`Bracket.generate(roster: Array[Familiar]) -> Bracket` (static):
requires exactly 16 distinct entries (matches `_randomize_matchup()`'s old
`push_error` convention if not), shuffles them, and builds round 1's 8
matches from adjacent pairs. Rounds 2–4 start with empty
(`entrant_a`/`entrant_b` both null) matches — they're populated as earlier
rounds resolve.

### 4.3 Margin, odds, and the roll

All of this lives in `scripts/bracket/bracket_odds.gd` as four small
static functions — `margin()`, `advance_probability()`, `winner_label()`,
`loser_label()` — rather than one combined call. Each is a pure function
of numbers only, which is what makes §10's "assert the exact label at
each bucket edge" validation possible without constructing a match first.

**Margin**: `winner_final_hp_pct - loser_final_hp_pct` from the simulated
`BattleEngine.run_to_completion()` result (0.0 for a razor-thin finish, 1.0
for the winner walking away unscathed). On a stalemate (`result.stalemate`
true, engine hit `MAX_TURNS`), use each side's HP% *at the cutoff* instead
of at a real defeat — same formula, no special case, and naturally lands
near 0 (a stalemate is by definition close).

**Advance probability** (used for the actual roll): `clamp(0.5 + 0.5 *
margin, 0.5, 1.0)` for the simulated winner. Linear and symmetric by
construction — a margin of 0 is a coin flip, a margin of 1 is a lock. This
constant (`0.5`) is the OPEN/PLAYTEST tunable (§2) if odds ever feel too
swingy or too flat once real brackets are played.

**Display bucket** (5 values, from the simulated winner's own
`advance_probability`, `p`):

| `p` range | Winner's label | Loser's label |
|---|---|---|
| p ≥ 0.90 | Heavy Favorite | Heavy Underdog |
| 0.70 ≤ p < 0.90 | Favorite | Underdog |
| p < 0.70 | Toss-up | Toss-up |

Scouting stores only the label on the match. The reveal step re-derives
the probability by re-simulating: the sim is deterministic for a given
pair of builds, and nothing about those builds changes between scouting
and revealing, so this reproduces the same number without `BracketMatch`
needing a field to cache it in.

## 5. Character select

Replaces `_randomize_matchup()` as the run's opening screen. On `_start_new_run()`:

1. `var bracket := Bracket.generate(full_roster)`.
2. For every round-1 match, run the real sim and derive its odds label
   — **all 8**, not "all but the player's," since nobody's picked a side
   yet. Store each match's `odds_label`.
3. Show the character-select screen: a browsable list of all 16 entrants
   (mirrors `bracket_mockup.png`'s left-hand list). Hovering one shows a
   `TooltipLayer` tooltip: its `odds_label` (from whichever round-1 match
   it's in) plus its `species_affinities` tags. Clicking pins a detail
   panel (portrait, stats, starting techniques, species tags as pills, the
   odds label) with a **Select Fighter** button.
4. Selecting an entrant sets `player_familiar_data` to it (`.duplicate()`d,
   same reasoning as the old `_randomize_matchup()` — the object gets
   mutated in place over the run) and marks its round-1 `BracketMatch` as
   `is_player_match = true`. That match's pre-scouted `odds_label` and
   `winner` are simply never used again — it becomes a real played fight.
   The other 7 round-1 matches' scouted odds carry forward unchanged into
   round 1's normal flow (§6).

## 6. Round flow

Replaces `start_next_round()`'s "pull `opponent_lineup[current_round]`"
with bracket-aware lookups. Below, "this round" is whichever
`BracketRound` is currently active (`rounds[current_round_index]`,
0-indexed) and "next round" is `rounds[current_round_index + 1]`. Round 1
is the one exception — its scouting already happened during character
select (§5), so this flow starts from round 2 onward:

1. For every match in *this round* except the player's, run the sim +
   `BracketOdds`' label functions, store `odds_label`. (Each entrant's build
   already reflects every prior round's auto-applied rewards — see §7 —
   so later rounds' sims are just as meaningful as round 1's.)
2. Show the scouting screen: same hover/click component as character
   select, no Select button, for that round's non-player matches.
3. Existing, unchanged flow: pre-fight screen → priority editor loop →
   fight → reward screen (player only).
4. **Reveal**, once the player's match resolves:
   - For every other match in *this round*, roll against its stored
     `advance_probability` to get the *true* `winner` (which can differ
     from the sim's naive pick — the upset). Set `revealed = true`.
   - Auto-apply the real reward system (§7) to each true AI winner.
   - Write each winner into the correct `entrant_a`/`entrant_b` slot of a
     *next-round* match: match `k` of the next round takes its
     `entrant_a` from match `2k` of this round's winner, and `entrant_b`
     from this round's match `2k+1`'s winner — standard single-elimination
     pairing.
   - Show a reveal summary (which upsets happened, if any) before
     advancing.
5. If the player loses their own match, the run ends immediately (§9.5) —
   no reveal, no further resolution; nothing else in that round matters
   once the run is over.

## 7. AI progression

15 AI entrants need to grow "also accumulating power" (`GAME_DESIGN.md`
§0.2) without a UI. After a `BracketMatch` reveals its true winner (§6
step 4), that `Familiar` gets the exact same reward mechanism the player
uses, auto-resolved:

- `RewardProgression` decides this round's reward kind (technique/passive/
  trade, same cadence as the player).
- `RewardSelector.pick_candidate()` picks a Species/Run/Pivot slot
  candidate (auto-select Run, since there's no player judgment call to
  make — Run is the slot actually informed by what the build already has).
- The stat-upgrade point auto-applies to whichever of the five stats
  (`max_hp`/`power`/`defense`/`speed`/`focus`) is currently *lowest as a
  fraction of its own typical range* — not lowest in absolute terms, which
  would never pick `max_hp` at all (it runs ~40-90 while the other four
  run ~2-20, per the bounds the session-7 stat-search pass used (recorded
  in `DECISIONS.md`; that script was a throwaway and is deleted), so it would
  always look "highest" regardless of how undernourished it actually is).
  Each stat's fraction is `(current - typical_min) / (typical_max -
  typical_min)`, using those same bounds (`max_hp`: 35-85; the other four:
  2-20); the lowest fraction gets the point. Still a deliberately simple,
  build-unaware rule (no read of techniques/passives/playstyle) — see §11.

This is exactly why the reward-tagging pass (species_affinities, tags,
role_\*) had to be finished before this design could be written — every AI
pick reads that same data the player's reward screen does.

## 8. Final boss

After round 4 resolves (bracket champion decided — always the player, since
the run already ended if they lost any earlier round), a distinct flow:
the same pre-fight-screen infrastructure, `boss_familiar` as the opponent,
no scouting step (nothing off-screen to resolve — it's the player's match
only). No reward follows; the run ends either way (§9.1/§9.2/§9.4,
unchanged). `boss_familiar` is a placeholder `Familiar` for this pass —
real "absurd showdown" content is its own later effort.

## 9. Files (expected)

- `scripts/bracket/bracket_match.gd`, `bracket_round.gd`, `bracket.gd`,
  `bracket_odds.gd` (new).
- `scenes/bracket_select.tscn` + `scripts/bracket/bracket_select.gd` (new)
  — character-select screen.
- `scenes/bracket_scout.tscn` (or a shared scene with `bracket_select.tscn`
  — implementation plan decides) + supporting script — scouting screen,
  reused every round.
- `resources/familiars/final_boss_stub.tres` (new, placeholder content).
- `scripts/battle_controller.gd` — `_randomize_matchup()`/`full_roster`'s
  random-five-pick role removed; `bracket: Bracket` field added;
  `start_next_round()` rewritten around bracket lookups instead of
  `opponent_lineup[current_round]`.

## 10. Validation

Headless `_verify_*.gd` scripts (this project's established, throwaway-
after-use pattern):

- `Bracket.generate()`: 16 distinct entrants required (error on fewer/more/
  duplicates), round 1 has exactly 8 matches with no shared entrant across
  matches, rounds 2–4 start empty.
- Round-to-round pairing math: a hand-traced bracket confirms round *N*
  match *k* correctly draws from round *N-1* matches `2k`/`2k+1`.
- `BracketOdds`: boundary values (margin 0.0, 0.5, 1.0) produce
  the expected probability and label at each bucket edge.
- A full multi-round run-through built directly from `Combatant`/
  `BattleEngine` (mirroring the existing stack-overflow repro pattern) —
  confirms advancement, reveal, and AI auto-reward application work
  end-to-end without any UI, before wiring the UI on top.

## 11. Open questions

Carried forward from §2/§4.3, not resolved by this design on purpose:

- The margin→probability constant (`0.5 + 0.5 * margin`) and the two
  bucket-boundary probabilities (0.70, 0.90) are a first, reversible guess
  — revisit once a real bracket has actually been played a few times.
- Whether `bracket_select.tscn` and the later-round scouting screen end up
  as one shared scene or two similar ones is an implementation-plan
  decision, not a design one — both use the identical hover/click
  component either way.
- AI buildcrafting sophistication (§7) is intentionally minimal for this
  pass — deterministic stat-fraction picking, an auto-selected Run-slot
  reward, no awareness of synergy or playstyle. This is a deliberate "V1,
  tune later" choice, same as the odds formula: expected to get smarter
  once there's a real bracket to observe AI builds in, not a gap to close
  before this ships.
