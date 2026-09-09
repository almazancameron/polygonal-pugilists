# Pixel Pugilists — Agent Handoff

This document is for a new engineer (human or AI) who has never seen this repository. It is not a
replacement for `.claude/GAME_DESIGN.md`, `.claude/DECISIONS.md`, `.claude/DEVLOG.md`, or
`.claude/BALANCE_PRIMITIVES.md` — it is a map of those documents plus everything a previous long
collaboration learned that isn't fully captured in them. Read this first, then go to the cited
source docs/files for depth.

**Repo root:** `c:\Users\zanka\OneDrive\Documents\Portals\Misc\GODOT\polygonal-pugilists`
**Engine:** Godot 4.7 (Forward+, Jolt Physics), GDScript only, no C#.
**Godot binary used for headless verification:** `c:\Users\zanka\OneDrive\Documents\Portals\Misc\GODOT\Godot_v4.7.1-stable_win64_console.exe` (one directory above the project).

---

## 0. Read these first, in this order

1. `.claude/GAME_DESIGN.md` — the actionable design doc for *this* project. Has a status
   vocabulary (LOCKED / CURRENT DIRECTION / OPEN-PLAYTEST / OUT OF SCOPE) that is load-bearing —
   see §1 below.
2. `.claude/DECISIONS.md` — durable architectural decisions and *why*, not a changelog. This is
   the single most information-dense file in the repo for understanding non-obvious code shapes.
3. This document.
4. `.claude/CLAUDE.md`'s "Known GDScript/Godot pitfalls hit so far" section — ~30 specific,
   empirically-confirmed engine gotchas (drag-and-drop coordinate spaces, `z_index` being
   canvas-global, `ScrollContainer` not stretching children, `Resource.duplicate()` sharing
   arrays, etc.). Skim it before touching UI or resource-duplication code; several of these will
   cost you a real debugging session if you don't know them going in.
5. `.claude/BALANCE_PRIMITIVES.md` — the numeric/design language content should stay inside
   (damage formula, stat bands, stacking rules, red-flag patterns). Currently **untracked in
   git** (new). Read before authoring or rebalancing any technique/passive/familiar.
6. `.claude/DEVLOG.md` — chronological session history. Long, but the "Where to continue" footer
   of each session entry is a fast way to see what was known-incomplete at each point in time.

Core combat/data files to read directly, in order of how central they are:
`scripts/combatant.gd`, `scripts/technique/technique.gd`, `scripts/status/status.gd`,
`scripts/passive/passive_effect.gd`, `scripts/battle_engine.gd`, `scripts/battle_controller.gd`,
`scripts/familiar.gd`, `scripts/priority_rule.gd`.

---

## 1. What Pixel Pugilists is, and what it's validating

Pixel Pugilists is a **standalone, deliberately small tournament-roguelike prototype**. It is not
"Milestone 1 of a bigger game" nested in shared documentation — it is a complete small game in its
own right, built to prove one specific thesis before a much larger, currently-unbuilt game
(**Familiar Fight Club**, "FFC") is attempted:

> Is constructing a build, defining simple autonomous priorities, and watching the familiar
> execute that build satisfying enough to justify the full game?

FFC's full vision — a multi-week career, a home base ("the Ranch"), multiple tournament circuits,
a narrative campaign, postgame content, grid-based/spatial movement combat, and cross-run
meta-progression — is preserved separately in `.claude/FAMILIAR_FIGHT_CLUB_VISION.md`. That
document is **reference/aspiration only**. Do not pull systems from it into this codebase without
an explicit scope-change conversation. `GAME_DESIGN.md` §0.3 lists what's deliberately excluded
from Pixel Pugilists specifically (no meta-progression across runs, no Ranch, no circuits/campaign,
no grid movement, no breeding/lineage) and why — several of these were tried in earlier
brainstorming and consciously cut back down, not merely "not yet built."

**Design-status vocabulary** (`GAME_DESIGN.md` §0.1) — treat this literally, it's used
throughout the doc:

| Status | Meaning |
|---|---|
| **LOCKED** | Foundational commitment. Don't casually contradict it. |
| **CURRENT DIRECTION** | Today's intended solution, subject to iteration. |
| **OPEN / PLAYTEST** | Deliberately unresolved — building/playing should answer it, not a doc edit. |
| **OUT OF SCOPE** | Deliberately excluded from *this* project; belongs to full FFC. |

As of this writing: combat timing (Speed-driven turn order) and the whole universal stat line
(HP/Power/Defense/Speed/Focus) are **OPEN/PLAYTEST** (`GAME_DESIGN.md` §5) — the current
implementation is a first experiment, not a locked answer, even though it's fully built and
shipped. Do not "fix" Speed's tie-breaking or Focus's threshold-not-scaling shape as if they were
bugs; they're deliberate experiments awaiting more playtesting.

**Answer to the thesis, as of the last playtest (session 12, `DEVLOG.md`):** yes — the developer
played a full run start-to-finish and confirmed it's fun, with the final boss specifically called
out as difficult-but-beatable. This is a real, playtested "yes," not just "the features all
exist."

---

## 2. Current playable loop and development state

**The loop** (`GAME_DESIGN.md` §9.2, fully implemented):

1. Character select doubles as the bracket screen: pick your entrant's seed out of a real,
   randomly-generated 16-entrant single-elimination bracket. All 8 round-1 matches are scouted
   (odds shown) before you pick.
2. Fight your round's match, fully autonomously — **zero manual clicks during combat, on either
   side**. Both sides pick their move every turn through the identical evaluator
   (`Combatant.choose_technique()`).
3. Choose that round's reward(s) — a stat upgrade every round, plus one rotating second choice
   (technique / passive / technique / passive-trade, in that order across rounds 1–4).
4. Arrange priority rules in the in-run priority editor (`PriorityBuilder`), reopened
   pre-populated with whatever you already have.
5. Inspect the surrounding bracket (other matches simulated off-screen, resolved with real upset
   chances, shown with coarse odds labels).
6. Repeat from step 2 for 4 rounds.
7. Face a fixed final boss ("Entropy," a themed Burn-gated kit) — no reward follows it either way,
   win or lose ends the run.
8. Game Over screen (win or loss) with a Restart button that re-rolls the entire run (new bracket,
   new draft, fresh reward-flow state) rather than quitting the application.

**Development state:** Milestone 1 (per `GAME_DESIGN.md` §10) is feature-complete and
playtested. All 16 starting familiars exist, are balance-tested (round-robin harness, every
familiar 40–60% win rate, none doomed), and the mockup-matching visual overhaul is done across
every screen (shared `Theme`/`Palette`/`FramedPanel` foundation). The tournament bracket, off-screen
simulation with real upset rolls, the reward system, and the priority editor are all built and
integrated.

**⚠️ Working tree currently has substantial uncommitted work** (see §14 for the full list) — the
final boss's *content* resources were committed (`110574a feat: final boss kit...`), but the
**bracket-tree visualization rebuild** (`scripts/bracket/bracket_tree.gd`, new/untracked), the
scene wiring for the boss and the bracket tree (`battle.tscn`, `bracket_screen.tscn`,
`reward_select_panel.tscn`, all modified-uncommitted), `BracketOdds.label_color()`, and the new
`.claude/BALANCE_PRIMITIVES.md` doc are all sitting as **uncommitted working-tree changes**, not
committed history. `DEVLOG.md` describes all of this as done, playtested, working code — this is
real, intentional, load-bearing work, not experimental cruft. Do not discard it. It should
probably be committed as a checkpoint before further work, but that's a call for the developer,
not something to do unilaterally.

**Next planned work** (`GAME_DESIGN.md` §10, developer's own 9-step roadmap, none of it started):
1. Shore up AI bracket-opponent drafting (§11) and finish authoring `tags`/`role_*` metadata.
2. Build `draft_balance_test.gd`, a full-run simulation harness sampling realistic *drafted*
   builds, not just default starting kits.
3. Engine scaffolding: persistent turn/battle-scoped state (hit-count-this-turn, etc.), a
   consistent hit-vs-status-damage rule, more passive trigger events, and turn-order modifiers
   (always-first/always-last) — explicitly framed as the answer to the still-open Speed-timing
   question (§12.1), not a separate bolt-on feature.
4. A larger technique/passive content pass beyond the 16 starting kits.
5. Use the round-robin/full-run sims to catch broken content as it's added, continuously.
6. Replace placeholder assets with custom art; add VFX/SFX/music/menus.
7. Final polish pass.
8. Release v0.1.
9. Post-release ideas (v0.2+, undesigned): more content, multiple Focus trees per species,
   Balatro-style random technique augments, a score-attack mode, achievements.

---

## 3. Repository architecture

```
.claude/                 Design docs, decisions log, devlog, learning roadmap, balance doc.
docs/superpowers/        Specs and plans for larger features (bracket, AI drafting), written
                          before implementation, kept as historical design record.
scenes/                  battle.tscn (main scene) + battle_panels/*.tscn (self-contained overlay
                          panel scenes) + priority_builder/*.tscn + ui/*.tscn.
scripts/                 GDScript, organized into per-category subfolders once a category grew
                          large enough (status/, technique/, condition/, numeric_bonus/, upgrade/,
                          passive/, reward/, bracket/, priority_builder/, battle_panels/, ui/,
                          tools/). Files not yet split into a subfolder (combatant.gd,
                          battle_controller.gd, battle_engine.gd, familiar.gd, priority_rule.gd,
                          combat_log.gd/combat_log_view.gd, hp_bar.gd, status_row.gd,
                          tooltip_layer.gd, tooltip_panel.gd) stay at scripts/ root — this is a
                          "folder per category once it's big enough" convention, not a rule that
                          every script needs a subfolder.
resources/               Authored .tres content: familiars/ (16 roster entries), bosses/
                          (the final boss, entropy.tres), techniques/ (+ passive_operations/
                          subfolder for internal-only technique payloads), passives/ (+
                          focus_passives/), conditions/, priority_rules/, priority_builds/
                          (dead/retired — see §12), upgrades/, focus_tables/, priority_builder/
                          (block palette descriptors).
assets/                  Sprites, fonts (yoster.ttf — see §12 for its glyph quirks), ui_mockup/
                          (the reference PNGs every screen's visual pass was built against).
balance_reports/         CSV output from balance_test.gd runs (untracked, gitignore candidate).
build/                   Exported Windows binaries — see §12 for the two-confusingly-named-preset
                          gotcha.
```

**No autoloads exist in this project, deliberately** (`DECISIONS.md`) — nothing currently needs to
survive a scene change (single scene family). Introduce one only when a real cross-scene need
appears, not preemptively.

### Type conventions (load-bearing, from `CLAUDE.md`)

- **`Resource`** — data authored ahead of time, editable in the Inspector, worth saving to disk
  (`Familiar`, `Technique`, `Condition`, `PriorityRule`, `PassiveEffect`, `UpgradeOption`,
  `Bracket`/`BracketRound`/`BracketMatch`). A build/template, not runtime state. The deciding
  property is "can this be authored in the Inspector or saved to disk," not "is it reused" — see
  `LEARNING.md`'s entry on this (a `Familiar`'s move list isn't shared with anything else and is
  still correctly a `Resource`).
- **`RefCounted`** — runtime-only objects needing automatic cleanup but no scene-tree presence:
  no `_process`, no children, never Inspector-edited (`Combatant`, `Status` and its subclasses,
  `BattleEngine`, `BracketSimulator`, `BracketResolver`, `AIDrafter`, `RewardSelector`). Prefer
  this over `Node` for per-battle objects.
- **`Node`** — only when something actually needs scene-tree membership (all UI/screen scripts).

New per-combatant runtime state belongs on `Combatant`, never a side-specific global —
`Familiar`/`Combatant` are deliberately symmetric between player and enemy. This was a fix for a
real bug class in the reference tutorial project this was bootstrapped from (player stats in a
global singleton, enemy stats on a Resource — asymmetric, neither wrote HP back to source).

---

## 4. Combat simulation architecture and execution flow

### `BattleEngine` (`scripts/battle_engine.gd`, `RefCounted`)

The scene-independent, headless-capable sequencer for one 1v1 fight. Extracted specifically so the
same rules drive both the live scene and headless tools (`balance_test.gd`,
`diagnose_matchup.gd`, `bracket_test.gd`, and the priority builder's mock-state panel). Contains
**zero** UI/pacing concerns — no `CombatLog`, no `await get_tree().create_timer(...)`.

Key state: `player`/`enemy: Combatant`, `current_first_actor: Combatant` (who opens the
*in-progress exchange*, re-decided every time an exchange completes — see below), `winner`,
`last_skip_reasons: Array[String]`.

Key methods:
- `determine_first_actor(a, b) -> Combatant` — checks `has_first_act_override()` first (an
  asymmetric override always wins); otherwise compares `effective_stat(SPEED)`; **ties go to `a`**
  (the first argument) — deliberately generic on argument order so a harness can test both sides
  of a tie by swapping arguments.
- `begin_battle()` — fires `BATTLE_START` passives on both sides, sets
  `current_first_actor = determine_first_actor(player, enemy)`.
- `run_upkeep(combatant) -> Array[String]` — ticks every active status once (`on_tick()` →
  `_notify_stack_change()`), erases expired ones, breaks early if the combatant dies mid-loop.
- `take_turn(actor, target) -> Array[Dictionary]` — the turn itself: `TURN_START` passives → stun
  check (early-return if stunned, never calls `choose_technique`) → `choose_technique()` →
  `TECHNIQUE_USED` passives → `technique.execute()`'s steps, each called and collected → `TURN_END`
  passives. Returns `{"message": String, "paced": bool}` dicts — `paced` marks only the
  technique-execution steps (the ones that get a UI pause between them).
- `advance_turn(actor) -> Combatant` — **this is the Speed-driven turn-order mechanism**: if
  `actor == current_first_actor`, the exchange isn't over yet (hand off to the other side). If
  `actor` was the *second* actor, the exchange just completed, so `current_first_actor` is
  **re-derived** via `determine_first_actor()` — this is what lets a mid-fight Speed swing hand
  one side two turns in a row (they close the current exchange as second actor, then open the
  next one too).
- `check_victory() -> bool` — fires `BATTLE_END` passives and sets `winner` on defeat. **Not
  idempotent** — calling it twice on an already-decided pair double-fires BATTLE_END. Every caller
  must stop driving the battle the moment this returns true.
- `run_to_completion(max_turns=1000, track_history=false) -> Dictionary` — the headless-harness
  convenience driver (balance_test.gd, bracket_simulator.gd use this; the live scene does not).

### `Combatant` (`scripts/combatant.gd`, `RefCounted`) — the most important file in the codebase

Per-battle runtime state wrapping a `Familiar`. Key mechanics, in rough order of subtlety:

- **`opponent: Combatant`** — a stored reference to the other side, set once per battle by the
  caller. Exists specifically so `STATUS_REDUCED`/`STATUS_REMOVED` passives can be checked from
  any of the ~6 places stacks can decrease, without threading an `opponent` parameter through
  every one of them.
- **`effective_stat(stat)`** — base `familiar.get_stat(stat)`, run through every active status's
  `modify_stat()`, then every matching `ModifyStatPassiveEffect.flat_bonus` from
  `familiar.passives` + `familiar.focus_table.effects`. `effective_defense()`/`effective_power()`
  are thin wrappers.
- **`choose_technique(target) -> Dictionary`** — walks `familiar.priority_rules` in order; first
  rule whose every condition holds wins (first-match, not best-match). Returns
  `{"technique": Technique, "skip_reasons": Array[String]}`. **Expects the rule list to end with
  an unconditional catch-all** (empty `conditions` array is vacuously true) — a `null` technique
  in the result means the authored list is missing that fallback, not a defensive case the engine
  invents itself.
- **`add_status(new_status, is_self_applied=false) -> Dictionary`** (`{"message", "created"}`) —
  the most complex method in the file:
  1. **Ward interception**: if a `WARD` status exists, `not is_self_applied`, and the new status
     isn't itself Ward, absorb `min(ward.stacks, new_status.stacks)` from both.
  2. If fully absorbed, return early.
  3. **Merge path** (status of same id already exists): `apply_passive_field_bonuses()` →
     `existing.on_reapply()` → `existing.stack_with(new_status)` → settle → notify.
     `created = false`.
  4. **Fresh-creation path**: notifies every *existing* status of the new arrival **before**
     appending `new_status` to `statuses` — deliberately, so the new status doesn't react to its
     own birth (this exact ordering bug once made Hex self-consume to 0 stacks the instant it was
     applied, everywhere in the game, until fixed in session 12). `created = true`.
- **`take_damage(amount) -> int`** — runs `amount` through every status's
  `modify_incoming_damage()` (Ruin), then an `ABSORPTION` interception (soaks up to its stack
  count before HP), then floors `current_hp` at 0 (never negative). Returns the *actual* amount
  subtracted post-modification, so callers log the real number, not their raw input.
  **`is_defeated()` is not checked inside `take_damage()` itself** — callers must check
  afterward.
- **`check_passives(trigger, affected, relevant_status=null)`** — records the fire
  (`_record_passive_fire`) **before** running the effect, not after. This ordering is deliberate:
  an `OperationPassiveEffect` with `triggers_hooks=true` can cascade back into checking the same
  trigger, and recording after would leave a re-entrancy window causing unbounded recursion
  (a real, previously-crashing bug).
- **`reset_turn_passive_limits()`** — clears `ONCE_PER_TURN`/`ONCE_PER_TECHNIQUE` limiter state
  and `stasis_redirect_used_this_turn`. Called once per actor, **right before that actor's own
  upkeep begins** — not at the top of `take_turn()` — because "one turn" for limiter purposes is
  that actor's upkeep *and* technique execution together, not just the technique part. (This
  exact boundary was misdiagnosed twice by Claude before the developer correctly identified it
  from a real bug report — see `DECISIONS.md`.)
- **`pre_application_snapshot`** — populated by `Technique.apply_status()` immediately *before*
  `add_status()` runs, so a passive can distinguish "already had this status" from "just gained it
  via this exact application." Only valid the instant right after being set.

### `battle_controller.gd` (`Control`, the live scene driver)

Wraps `BattleEngine` with real pacing (0.6s auto-timer or manual "advance" gate per paced step),
owns the whole run's meta-progression (bracket build/select, reward sequence hand-off,
game-over/restart), and is the **only** place player-visible timing/log/HUD concerns live.

- **`Phase` enum exists but appears to be presentation-only bookkeeping** — set at transition
  points, never read/branched-on anywhere in the file as of this research pass. Worth confirming
  before assuming it drives anything.
- `take_turn(actor, target, source)` is the **single shared path for both sides** — there is no
  player-specific vs. enemy-specific turn logic left anywhere in the game.
- The reward hand-off: `check_victory()` → (win, not final round) `start_next_round()` → ... →
  `begin_reward_sequence()` → `begin_phase_b()` (3-card reward or sacrifice screen or skip-to-stat)
  → confirm → `populate_stat_upgrade_rows()` (Phase A, always runs after Phase B) → confirm →
  `advance_to_priority_editor()` (opens `PriorityBuilder`, loops until the player begins combat) →
  `begin_fight()`.
- **The non-bracket "random gauntlet" flow is fully gone.** `battle_controller.gd`'s own header
  comment still narrates the *transition away from* a `_randomize_matchup()` random-opponent
  gauntlet, but that method no longer exists — the bracket (`Bracket`/`BracketMatch`/
  `BracketResolver`/`BracketScreen`) is the *only* matchmaking path today. Don't go looking for a
  non-bracket fallback mode; it was retired.

---

## 5. Technique / StepGroup / Action / Condition / NumericBonus / Passive / Status / PriorityRule / AI

This is the content-authoring core. The load-bearing rule that explains almost every shape below
(`DECISIONS.md`, re-derived independently multiple times across the project): **subclass when the
*logic* differs; use exported fields when only the *numbers* (or choices, like SELF/TARGET) differ.**

### `Technique` (`scripts/technique/technique.gd`, `Resource`)

A familiar's authored move. `step_groups: Array[TechniqueStepGroup]` is the whole content;
`execute(user, target, trigger_hooks=true) -> Array[Callable]` **does not run the technique** — it
builds and returns one closure per action, which the caller invokes one at a time
(`battle_controller.gd`'s `take_turn()` logs/paces each; `BattleEngine.take_turn()` just runs them
in sequence for headless use). This is why a multi-hit technique reads as several distinct log
lines instead of one batched summary — a deliberate presentation choice pushed down into the
caller, not baked into `Technique` (`DECISIONS.md`).

**Damage formula** (`apply_hit()`, confirmed from code, also the anchor fact in
`BALANCE_PRIMITIVES.md`):
```
raw_technique_damage = int(user_power * power_multiplier)
raw_damage           = raw_technique_damage + numeric_bonuses_total
post_mitigation       = raw_damage² / (raw_damage + target_defense)      # integer division, floors
damage                = max(post_mitigation, 1)                          # hard floor of 1
```
Defense == raw damage → ≈50% mitigation. Defense is **better against fewer/larger hits, worse
against many small hits** — a structural property, not something to "fix." A
`HitAction.ignore_power_and_defense = true` hit instead reads `power_multiplier` as a literal flat
int and skips the whole formula (`damage = max(int(power_multiplier) + bonuses, 1)`).

**Heal formula** (`apply_heal()`): the base "damage" figure is computed *as if it were a hit
against the healer's own Defense* (`max(int(power * multiplier) - own_defense, 1)`), then
`heal_amount = int(that * heal_percent) + heal_flat + bonuses`. Heal output is implicitly gated by
the healer's own Defense stat, not just Power — a real, slightly-surprising consequence worth
knowing before assuming heal scaling is independent of the damage formula.

`TechniqueStepGroup`: `actions: Array[TechniqueAction]`, `repeat_count` (the whole action list
re-runs this many times — **each repetition independently fires its own HIT/ATTACK/STATUS_APPLIED
events**, confirmed in `BALANCE_PRIMITIVES.md`), `conditions` (ANDed, empty = unconditional),
`numeric_bonuses` (shared pool across every action in the group, filtered by
`NumericBonus.applies_to`/`ActionType` per-action — **a self-targeted and a target-targeted action
sharing one group would incorrectly share the same bonus pool**; split them into separate groups).

**Actions** (`scripts/technique/`): `HitAction` (SELF/TARGET, `ignore_power_and_defense`),
`HealAction` (always targets user, no SELF/TARGET choice), `StatusApplicationAction`
(SELF/TARGET — **defaults to SELF**, unlike most other actions which default to TARGET; a genuine
inconsistency worth double-checking when authoring), `ModifyStatusAction` (MULTIPLY/SUBTRACT/
DIVIDE/**SET** — SET is an absolute overwrite, not additive; there is no ADD operator on this
class), `RandomStatusApplicationAction` (rolls a genuinely random status *at execution time*,
never cached on the shared resource — this is the one documented source of cross-run
non-determinism besides Cleanse), `HalveAllStatusesAction` (integer-divides every active status by
2, a 1-stack status is fully wiped).

**Conditions** (`scripts/condition/`, one subclass per kind — genuinely different battle-state
facts, contrast with `Technique`'s data-driven shape): `HpComparisonCondition`,
`StatComparisonCondition`, `StatusComparisonCondition` (also handles "sum all statuses" via
`check_all`), `StatusPresentBeforeApplicationCondition` (reads `pre_application_snapshot`, only
valid inside a STATUS_APPLIED/CREATED passive), `FocusBreakpointCondition` (checks
`tier * familiar.focus_step_size`, never a hardcoded Focus value), `NotCondition` (wraps and
inverts one other condition). All comparator-rendering `describe()` methods use fullwidth/
mathematical Unicode (`＜ ＞ ≤ ≥`) instead of plain ASCII — see §12, this is a font quirk, not
decoration.

**NumericBonus** (`scripts/numeric_bonus/`): `ValueSource { STAT, STATUS_STACKS, STATUS_COUNT,
HP }` — what the percent term is a percentage *of*. `base_amount()` = `flat_bonus +
percent_bonus * resolved_value`; every subclass overrides `compute()` to add its own twist:
`StackCountNumericBonus`/`StatusCountNumericBonus` *multiply* the base by a stack/status count
(0 if the status is absent — the whole bonus zeroes out, not just the multiplier);
`StatComparisonNumericBonus`/`StackComparisonNumericBonus` add/multiply by an *unclamped
difference* between two stats or two statuses' stacks — being behind the comparison is a real
penalty, not just "contributes nothing"; `ConditionalNumericBonus` gates the whole base amount on
an arbitrary `Condition`; `TotalStatusCountNumericBonus` sums distinct statuses across **both**
sides (built specifically for the final boss's Reap technique).

### `Status` (`scripts/status/status.gd`, `RefCounted`, 24 concrete subclasses)

Base hooks: `on_applied`, `on_reapply`, `on_tick`, `on_hit`, `on_attack`, `on_status_applied`
(reacts to *any other* status landing — only Hex overrides this), `is_expired`, `stack_with`,
`max_stacks` (**consulted only by `modify_status_stacks()`, not by the merge path in
`add_status()`** — overriding `max_stacks()` alone does nothing; a real cap needs an override of
both `max_stacks()` *and* `stack_with()`), `modify_stat`, `modify_incoming_damage`,
`grants_first_act_override` (hook exists, **currently unused by any subclass**),
`next_tick_damage` (a UI-preview hook, doesn't actually tick anything).

**Standardized field-naming convention** (retrofitted so `ModifyStatusPassiveEffect`'s reflection
has something to target): `stack_value` (per-stack buff magnitude), `stacks_lost_per_tick`/
`_per_hit` (decay rate), `<effect>_per_tick`/`_per_hit`/`_per_stack` (damage/heal magnitude),
percent-shaped fields keep their own category (`percent_increase`). All plain `var`, never
`@export` — a `Status` is only ever built via `Status.create()`, never authored as its own `.tres`.

**Two mechanics deliberately live *outside* the hook system entirely**, because every hook fires
*after* its event already happened and these two need to preempt it:
- **Ward** and **Absorption** — hardcoded `get_status(WARD)`/`get_status(ABSORPTION)` checks
  inside `Combatant.add_status()`/`take_damage()`.
- **Stasis** — implemented inside the *base* `Status.stacks` setter itself: any other status's
  attempted stack *reduction* gets redirected into consuming a Stasis stack instead, guarded by
  `stasis_redirect_used_this_turn` (per-status, per-turn) to prevent infinite redirect loops.

A new engineer searching `status.gd`'s subclasses for "how does Ward/Absorption/Stasis actually
work" will find almost nothing there — go to `Combatant.add_status()`/`take_damage()` and the base
`Status.stacks` setter instead.

Compact reference table (mechanic + key fields), for orientation:

| Status | Mechanic | Notable fields |
|---|---|---|
| Poison | Stacking DoT, `damage_per_stack * stacks`, decays | `damage_per_stack`, `stacks_lost_per_tick` |
| Burn | Fixed-duration DoT; reapply while active triggers a "Flare" burst instead of stacking | `max_stack_count=5`, `damage_per_tick`, `flare_damage` |
| Acid | Infinite-duration, capped Defense-reduction debuff | `max_stack_count=5`, `defense_reduction_per_stack=0.1` |
| Bleed | On-hit consumer: bonus damage per stack, then decays | `damage_per_stack`, `stacks_lost_per_hit` |
| Stagger | Capped counter; at cap, resets and self-applies Stun | `max_stack_count=5` |
| Stun | Skips the target's next turn, self-clears | — |
| Foretell | Countdown (tick or reapply); bursts at 0 instead of quietly expiring | `burst_damage` |
| Defending | Doubles Defense for N hits, consumed on hit | `defense_multiplier=2` |
| Fortify | Flat Defense bonus, decays per turn | `stack_value`, `stacks_lost_per_tick` |
| Hone | Flat Power bonus, decays per hit | `stack_value`, `stacks_lost_per_hit` |
| Enlarge | Power multiplier, decays per turn | `stack_value` (float) |
| Recharge | Pure downtick counter, no effect of its own — content must check for it | `stacks_lost_per_tick` |
| Thorns | On-hit retaliation, decays per hit | `damage_per_stack` |
| Ward | Absorbs one incoming status app 1:1 | (interception, no exposed fields) |
| Hex | Reacts to *any* status landing on owner, loses stacks, deals damage | `damage_per_stack` |
| Absorption | Soaks incoming damage 1:1, **capped at 20 stacks** | `max_stack_count=20` |
| Ruin | Increases incoming damage %, decays | `percent_increase`, `stacks_lost_per_tick` |
| Retaliation | One-shot counterattack, chains into the attacker's own on-hit reactions | `damage_per_stack` |
| Stasis | Redirects other statuses' reductions to itself | (mechanism lives in base class) |
| Renewal | Stacking HoT, decays | `heal_per_stack`, `stacks_lost_per_tick` |
| Lifesteal | On-attack self-heal % of Power, decays per hit | `heal_percent_of_power` |
| Regeneration | Flat heal on hit (no decay) **plus** flat heal on tick (decays) | `heal_per_hit`, `heal_per_tick` |
| Cleanse | On tick, strips one random other status (routes through `_settle_status`), decays | `statuses_stripped_per_tick` |

### `PassiveEffect` (`scripts/passive/passive_effect.gd`, `Resource`, 5 concrete subclasses)

Shared shape: `Trigger` enum (12 real values — `STATUS_APPLIED`/`STATUS_CREATED` (exclusive
subset)/`STATUS_REDUCED`/`STATUS_REMOVED` (exclusive subset)/`BATTLE_START`/`BATTLE_END`/
`TURN_START`/`TURN_END`/`HIT`/`ATTACK`/`TECHNIQUE_USED`/`DAMAGE_DEALT`/`DAMAGE_TAKEN`/`HEALED`,
plus a retired dead `HEAL_CAST` value kept only because the enum is append-only), `trigger_target`
(`SELF`/`TARGET`, default `TARGET` = "my opponent" — **`HIT` fires on the defender's own passives,
`ATTACK` fires on the attacker's own passives**, same physical moment, two different trigger
points; a passive reacting to its own owner's attack needs `trigger = ATTACK`, `trigger_target =
SELF` explicitly, or it silently never fires), `status_effect_filter`, `conditions:
Array[Condition]`, `Limiter { NONE, ONCE_PER_TURN, ONCE_PER_BATTLE, ONCE_PER_TECHNIQUE }` (tracked
per-`Combatant`, since one `.tres` `PassiveEffect` resource can be shared by many familiars).

Four payload subclasses (a wide survey of "when X, do Y" passive ideas turned out to already be
expressible with exactly these four, per `DECISIONS.md`):
- **`OperationPassiveEffect`** — `operation: Technique` (a full Technique, reused as the reactive
  consequence — "deal 3 damage," "apply Ward to self"), `triggers_hooks: bool` (default false;
  whether running it also cascades into action-level ambient triggers for other reactive
  content).
- **`ModifyStatusPassiveEffect`** — `stack_bonus` (consulted *before* `Status.create()` runs, so
  it's baked into the initial application) **and/or** `field_name`/`field_bonus` (reflection-based
  bonus to any standardized numeric field, e.g. Burn's `flare_damage`, applied *after* the
  merge-vs-fresh decision inside `add_status()`, targeting whichever instance survives).
- **`ModifyHealPassiveEffect`** — `heal_bonus`, consulted by `apply_heal()` before finalizing.
- **`PermanentStatPassiveEffect`** — `stat_change: ModifyStatUpgrade` (reused resource type),
  fires once at a trigger and mutates the persistent `Familiar` directly — permanent, like a
  picked stat upgrade.
- **`ModifyStatPassiveEffect`** — a flat, always-active stat bonus with **no trigger involved at
  all**; consulted directly by `Combatant.effective_stat()`, not the trigger/limiter system. This
  is what backs the shared `FocusTable`'s tiered bonuses.

`FocusTable` (`resources/focus_tables/focus_table.tres`) is one shared resource referenced by
every familiar's `focus_table` field — a breakpoint means "everyone gets the same bonus at the
same tier," not per-species tuning. Its 4 entries gate on Focus tiers 1–4 (steps of 5); tier 4
(Focus ≥ 20) is currently **inert content** — no familiar's Focus reaches 20 yet. Not a bug.

### `PriorityRule` (`scripts/priority_rule.gd`, `Resource`)

`{conditions: Array[Condition], technique: Technique}`. `Familiar.priority_rules` is an ordered
list; first rule whose conditions all hold wins. An empty `conditions` array is vacuously true and
is the standard unconditional catch-all — no dedicated "AlwaysCondition" class exists. Every
familiar's list is expected to end with one.

### AI opponent and AI drafter — **current state is a deliberate, temporary placeholder**

`AIDrafter` (`scripts/bracket/ai_drafter.gd`, `RefCounted`, all-static) is what makes the 15 AI
bracket entrants grow between rounds today. It is explicitly documented (in its own header
comment, and repeated across `DEVLOG.md` sessions 9/11/12) as deliberately naive:
`apply_round_reward(familiar, round_completed, technique_pool, passive_pool, rng)` always:
1. Applies one stat point to whichever stat sits at the **lowest fraction of its own authored
   range** (`STAT_RANGES`, hand-tuned bounds since stats live on different scales — MAX_HP
   35–85 vs. everything else 2–20).
2. Follows the **exact same reward cadence** as the player (`RewardProgression.CADENCE`), always
   drafting from the `RUN` slot of `RewardSelector` (the only slot scored against what the build
   already owns — "the closest thing to a judgment call an AI can make without a real personality
   system," per the code comment).
3. On a passive-trade round, **always sacrifices `familiar.passives[0]`** — the oldest-held
   passive, no judgment beyond insertion order.

There is **no drafting personality, no priority-rule optimization** yet. The real, designed
(but unimplemented) system is `docs/superpowers/specs/2026-09-06-ai-drafting-design.md` (status:
"approved, not yet implemented"): a small set of data-driven `DrafterPersonality` resources
(Greedy / Synergy Master / Random to start — not subclasses, since only weights differ, same
"data vs. subclass" rule as everything else), a shared priority-rule optimizer that generates a
bounded set of plausible orderings from technique-authored `priority_hints` metadata (reusing
existing `Condition` subclasses, not a new predicate language), and a two-layer reward evaluator
(fast heuristic reusing `RewardSelector`'s own relevance terms, with combat-lookahead only when
candidates are close). This swaps in at exactly one call site
(`AIDrafter.apply_round_reward()`) with **no bracket-side changes required** — the bracket's own
architecture was deliberately built to not care which AI-progression rule is behind that call.
This is explicitly the developer's own next planned step (§2 above, roadmap item 1).

---

## 6. Important data models and how they relate

```
Species (planned, not built)         — base stats + one bound-in passive, shared by every
   │                                    member of that species. Today's Familiar holds what
   │                                    Species will eventually own instead.
   ▼
Familiar (Resource)                  — one fighter's current run-build: stats, techniques,
   │  familiar_name, sprite,           priority_rules, passives, focus_table, species_affinities.
   │  max_hp/power/defense/speed/      Same class for player and every opponent — no asymmetry.
   │  focus, focus_step_size,          duplicate_for_run() is the ONLY safe way to copy one for
   │  techniques[], priority_rules[],  a new run/bracket entrant — see §12.
   │  passives[], focus_table,
   │  species_affinities[]
   ▼
Combatant (RefCounted)                — one fighter's LIVE state for the battle in progress:
      familiar, current_hp, statuses[], current_hp, is_stunned, opponent (back-ref),
      opponent, is_stunned,            pre_application_snapshot, per-passive fire counts. Built
      statuses[]                       fresh every battle; thrown away after.
```

Content composition:
```
Familiar.techniques      : Array[Technique]
Familiar.priority_rules  : Array[PriorityRule]  { conditions: Array[Condition], technique: Technique }
Familiar.passives        : Array[PassiveEffect]  (individually tradeable — see FocusTable split below)
Familiar.focus_table     : FocusTable  { effects: Array[PassiveEffect] }  (swapped as one shared unit)
Familiar.species_affinities : Array[TagAffinity]  { tag: RewardTag.Tag, weight: int }

Technique.step_groups    : Array[TechniqueStepGroup]
TechniqueStepGroup       : { actions: Array[TechniqueAction], repeat_count, conditions: Array[Condition],
                             numeric_bonuses: Array[NumericBonus] }
TechniqueAction subtypes : HitAction, HealAction, StatusApplicationAction, ModifyStatusAction,
                             RandomStatusApplicationAction, HalveAllStatusesAction
```

`Familiar.passives` vs. `Familiar.focus_table` deliberately stay two separate arrays of the same
`PassiveEffect` type — not about different runtime behavior today, but about which future
operations are allowed to touch each container (a passive-trade event operates on `passives`
individually; a `FocusTable` is meant to be swapped wholesale as a named, shareable-across-familiars
unit).

Bracket data model:
```
Bracket (Resource)          : rounds: Array[BracketRound] (sizes 8/4/2/1), boss_familiar: Familiar
BracketRound (Resource)     : matches: Array[BracketMatch]
BracketMatch (Resource)     : entrant_a, entrant_b, winner: Familiar, odds_label: String,
                               revealed: bool, is_player_match: bool  (deliberately NOT @export)
```

Reward data model:
```
RewardTag.Tag (enum, ~39 values, append-only)  — closed vocabulary read by RewardSelector only,
                                                   never by combat logic.
TagAffinity (Resource)      : { tag, weight }   — Familiar.species_affinities' element type.
BuildSnapshot (RefCounted)  : owned_tag_counts (Dictionary), owned_role_totals (4 keys) — computed
                               fresh on demand from a familiar's currently-equipped techniques +
                               passives, never cached.
RewardSelector (static)     : pick_candidate(slot, familiar, snapshot, pool, excluded_content, rng)
                               — pure function, no Combatant/UI/scene-tree dependency at all.
RewardProgression (static)  : kind_for_round(round_completed) — the CADENCE array, the single
                               source of truth for round->reward-kind mapping.
RewardFlowController (RefCounted) — owns ALL session state for one reward-screen pass: RNG,
                               reroll charges, staged stat allocation, sacrifice sub-state.
UpgradeOption (Resource)    : base for ModifyStatUpgrade / AddTechniqueUpgrade / AddPassiveUpgrade /
                               TradePassiveUpgrade / GiveUpPassiveOption (display-only) /
                               SkipSacrificeOption (display-only).
```

---

## 7. UI architecture and major screens

**Foundation:** `Palette` (`scripts/ui/palette.gd`, `const Color`s, manually kept in sync with the
`Theme` resource — no code enforces this) and `FramedPanel` (`scripts/ui/framed_panel.gd`, a
`@tool` procedurally-drawn notched-corner border widget used as the `Background` child of nearly
every panel scene, so no image assets need re-exporting when a color changes). `TooltipLayer`
(`scripts/tooltip_layer.gd`) replaces Godot's built-in tooltip system entirely with three tracked
states (active/shift-pinned/alt-pinned-as-persistent-panel) and two fallback checks for detecting
hover-exit on a nested `RichTextLabel` whose own `meta_hover_ended` isn't trusted to fire reliably
(see §12).

**Major screens**, each a self-contained `scenes/battle_panels/*.tscn` + `scripts/battle_panels/*.gd`
pair (session 11 refactor split these out of one monolithic `battle.tscn`, each owning its own
nodes and exposing `show_for()`-style methods + signals instead of `battle_controller.gd` reaching
into deep node paths):

- **`BeginCombatPanel`** — pre-fight screen: both fighters side by side, round label, "Open
  Priority Builder" / "Begin Combat".
- **`BracketScreen`** — hosts `BracketTree` (see §8); three modes (selectable character-select,
  read-only round scouting, read-only popup with a close button instead of Continue).
- **`RewardSelectPanel`** — the whole reward flow: winner card, next-opponent preview,
  bracket-summary card, 3 named reward-slot cards (Species/Run/Wildcard), the round-4
  sacrifice/trade flow with its own big Skip card.
- **`StatUpgradePanel`** — Phase A (stat allocation): a `StatUpgradeRow` per stat, +/- staged
  allocation, Confirm commits everything at once.
- **`BuildViewPanel`** — read-only "inspect my current build" popup.
- **`GameOverPanel`** — win/loss message + Restart.

**Priority Builder** (`scenes/priority_builder/priority_builder.tscn` +
`scripts/priority_builder/*.gd`) — the in-run rule editor, embedded as a **permanent hidden
sibling** in `battle.tscn` and **re-`setup()`'d every round** (not instantiated fresh each time),
matching the same "always present, toggle visibility" convention as the other panels above.

- **Descriptor-driven condition authoring**: `ConditionBlockDefinition` (`Resource`) is **one
  descriptor per sentence shape, not per `Condition` subclass** — `compare_mode` deciding whether
  `right_value` or `right_target` is live means a single descriptor covering both would need
  hide/show slots, so "target's Acid stacks < 5" and "my Poison vs their Poison" are two separate
  `.tres` palette entries even though both instantiate `StatusComparisonCondition`. A single
  generic `ConditionBlock` script renders any descriptor. `ConditionBlockDefinition.find_matching()`
  keys an already-built `Condition` back to its palette entry via `(condition.get_script(),
  fixed_values)` — proven unambiguous because "one descriptor per shape" guarantees this pair is
  unique within a palette.
- **Nesting = AND, flattened depth-first pre-order** into `PriorityRule.conditions` — presentation
  only, since an ANDed array already means that. `NotCondition` is the one wrapper exception (its
  single body child is assigned directly, not recursed into, to avoid ANDing a condition alongside
  its own negation).
- **`SegmentList`/`RuleSegment`** — the reorderable priority-rule slot list. The historical
  `Node.move_child()` off-by-one reorder bug (remove-then-insert semantics — target index must be
  computed against the *destination sibling's own* `get_index()`, decremented by 1 if the moved
  node currently sits before it) is fixed in current code; re-read `SegmentList.insert_index_for_y()`
  before touching drag-reorder logic again, the comment there explains the exact math.
- **`StateProbe`** — the mock-state panel: drives a **real** player/dummy `Combatant` pair through
  actual `BattleEngine` calls (Step/Play/Reset/Previous/Next), so Ward, Absorption, Retaliation,
  DoT all behave exactly as in a genuine fight (this is what caught the Stasis/passive-notification
  engine bug in session 8). The dummy **never takes its own turn by design** — a real, accepted
  limitation for testing reactive/defensive kits. Its FIRES/skipped/unreached/incomplete verdict
  badging is **restated independently**, not read from `choose_technique()`'s flat `skip_reasons`
  array (to avoid coupling to that loop's append order), and cross-checked every evaluation against
  a real `choose_technique()` call on a shadow Combatant, surfacing any mismatch as
  "EVALUATOR MISMATCH" text in the UI.

---

## 8. Tournament/bracket architecture

`Bracket.generate(roster, rng, boss)` requires exactly 16 familiars; copies every entrant via
`Familiar.duplicate_for_run()` (never plain `.duplicate()` — see §12); shuffles with a manual
Fisher-Yates against an **injected** RNG (not `Array.shuffle()`, which reads the unseedable global
RNG) so a seeded run reproduces the same bracket. Only round 1 starts populated; later rounds are
empty placeholders sized 4/2/1. `advance_round(i)` writes round `i`'s winners forward into round
`i+1` (match `2k` → next round's `entrant_a` at index `k`, `2k+1` → `entrant_b`) — expressed from
the source side specifically so the caller never needs to know the pairing rule.

`BracketResolver` splits **scouting** (`scout_round()`, before the player's own fight — simulates
every *other* match, sets `odds_label` only, never `winner`) from **resolving**
(`resolve_round()`, after the player's own fight — re-simulates from scratch, deterministic, cheap
enough not to cache; rolls `rng.randf() > probability` for an upset, then calls
`AIDrafter.apply_round_reward()` on every resolved match's winner).

`BracketSimulator.simulate(a, b)` runs the **real** `BattleEngine` (not an approximation — a whole
run needs at most 11 off-screen matches at ~7.5ms each, cheaper than maintaining a second, cruder
combat model per `GAME_DESIGN.md` §9.3), reduces the result to `margin = winner_hp_pct -
loser_hp_pct` via `BracketOdds.margin()`. A stalemate (turn cap reached) nominates whichever side
holds more HP rather than returning no winner — margin naturally lands near 0, near-coin-flip.

**`BracketOdds`'s formula and thresholds are explicitly, permanently flagged as unvalidated** —
its own doc comment says so directly, and `DEVLOG.md` repeats "every `BracketOdds` constant is
still an untested guess" across sessions 9, 11, and 12 without ever being addressed. Treat
`advance_probability = clamp(0.5 + 0.5*margin, 0.5, 1.0)` and the 0.70/0.90 label-tier thresholds
as placeholders, not tuned values, if asked to touch difficulty/pacing.

**`BracketTree`** (`scripts/bracket/bracket_tree.gd`, currently **untracked in git**) is the
custom-drawn, complex tournament-tree widget — 604 lines, no scene file, entirely `_draw()`-based.
Central model: every still-alive entrant has exactly **one live position** (their full interactive
card), which promotes one tier inward every time they win, while every earlier tier they've passed
through downgrades to a small sprite-only box (X'd only where they actually lost). This went
through three real rounds of screenshot-driven layout-math bugs in one session (a squeezed card,
an overflow from gap-redistribution not shrinking whole columns, a scale-calibration
double-count of the shared Final box's width) — **any future change to `_compute_layout()` or the
column-width math should be re-verified with a headless pixel-math script across at least three
states (fresh/mid-tournament/champion-crowned), not a single screenshot**, since that's literally
how the last three bugs were actually caught. `_reference_total_width()`'s own doc comment
documents one small, deliberately-accepted imprecision at the champion-crowned stage — read it
before assuming a small width mismatch there is a new bug.

`bracket_test.gd` (`scripts/tools/`, committed, re-runnable — 12 checks) is the only automated
regression coverage for this subsystem, and it does **not** cover `BracketTree`/`BracketScreen`
(pure UI, no headless test coverage) — layout changes still rely on manual/screenshot
verification.

The final boss ("Entropy") is a **fixed encounter outside the 4-round bracket tree entirely** —
`resources/bosses/entropy.tres` lives outside `resources/familiars/` deliberately (that folder is
directory-scanned by `balance_test.gd`/`bracket_test.gd`; a boss inside it would become an
unwanted 17th roster entrant). No scouting, no off-screen resolution, no reward follows it either
way.

---

## 9. Reward / drafting / stat-upgrade systems

Full flow: `battle_controller.begin_phase_b()` → `RewardFlowController.begin_reward_screen()` →
`RewardProgression.kind_for_round()` picks the cadence (TECHNIQUE/PASSIVE/TECHNIQUE/PASSIVE_TRADE
for rounds 1–4, `NONE` beyond) → dispatch to the sacrifice screen, straight to reward cards, or
straight to a 1-point stat pass.

**`RewardSelector.pick_candidate(slot, familiar, snapshot, pool, excluded_content, rng)`** is a
pure, stateless function — confirmed to take no `Combatant`, no UI, no scene-tree reference, so
it's directly reusable by the future AI-drafting system. Three slots, each with `weight = max(0.1,
BASE_WEIGHT[slot] + bonus)` — **no candidate is ever truly unreachable**, since `BASE_WEIGHT` (5.0)
is a real floor, not an epsilon:
- **Species**: sums `TagAffinity.weight` for every affinity tag the candidate also carries.
- **Run**: tag-repeat term (`owned_tag_counts` sum over the candidate's tags) + role-deficiency
  term (`candidate.role_X * 1/(1+current_role_total)` per role — smooth, never a hard exclusion).
- **Pivot** ("Wildcard" in the UI): an inverted-U over *combined* Species+Run overlap — near-zero
  and heavy overlap both fall back toward baseline; peak bonus sits at moderate overlap ("a little
  relevant, a little strange" — deliberately not "maximum dissimilarity," which would just be
  random).

Reward-screen mechanics worth knowing: **skipping any screen (a normal reward's Skip button, or
the sacrifice screen's big Skip card) grants 2 stat points instead of 1** (never strictly less
than picking something); stat allocation is **allocate-then-confirm**, never immediate-apply-per-
click (per explicit developer correction after reviewing the mockup — a misclick must never
permanently commit the wrong one-way stat change); a passive-trade round scores its 3 replacement
candidates against a `BuildSnapshot` computed **as if the sacrificed passive were already gone**
(`BuildSnapshot.compute(familiar, [sacrificed])`), so it doesn't recommend "more of what you just
gave up."

`resources/techniques/passive_operations/` holds internal-only `Technique` payloads consumed
purely by `OperationPassiveEffect.operation` — confirmed these never appear in
`technique_reward_pool`/`passive_reward_pool` (the player-learnable/draftable content pools,
manually curated in the Inspector on `battle_controller.gd`). Don't offer these as rewards; don't
be confused when a familiar's passive references a `Technique` that isn't in any reward pool.

---

## 10. Architectural conventions to preserve

- **Subclass for different logic, exported fields for different numbers/choices.** Re-derived
  independently multiple times in this project's history (`Technique` collapsed from
  per-move subclasses into one data-driven class; `Condition` stayed subclassed because each kind
  reads a genuinely different fact; `DrafterPersonality`'s design spec explicitly cites this rule
  by name to justify its own shape). Don't propose a new subclass without first asking whether the
  cases are actually different *logic* or just different *numbers*.
- **`Familiar`/`Combatant` symmetry between player and enemy, no side-specific globals.** Any new
  per-combatant runtime state goes on `Combatant`.
- **Passive limiter recording happens *before* the effect runs, not after** — protects against
  cascading self-re-trigger. Don't "simplify" this ordering.
- **Interception (Ward/Absorption/Stasis) is a hardcoded check at the one relevant call site, not
  a new `Status` hook** — every hook fires *after* its event; only add a new hardcoded
  interception point when something genuinely needs to preempt the base flow.
- **A resource shared by more than one owner (a `.tres` referenced from two places) must never be
  edited to fit one consumer** — give the new need its own dedicated resource. A real incident
  (`fallback_attack.tres` shared between a familiar's own fallback and a player build) silently
  broke the other owner.
- **`Familiar.duplicate_for_run()`, not `Resource.duplicate()`, for any new-run/new-entrant copy.**
- **Stack-reduction code paths must route through `Combatant._settle_status()`**, the shared
  choke point that fires `STATUS_REDUCED`/`STATUS_REMOVED` — never mutate `.stacks` and erase
  directly.
- **New `PassiveEffect.Trigger` values must be appended at the end of the enum, never inserted** —
  an authored `.tres` stores the raw integer index.
- **Prefer the smallest reversible experiment for anything marked OPEN/PLAYTEST** in
  `GAME_DESIGN.md` — don't silently promote an experiment (Speed timing, the stat line, `BracketOdds`
  constants) to permanent canon by building heavily on top of an unstated assumption about it.

---

## 11. Intentional weirdness / non-obvious implementation choices

Do not "fix" any of these without first checking whether it's deliberate:

- **`StatusApplicationAction`/`RandomStatusApplicationAction` default `target` to SELF**, while
  almost every other action (`HitAction`, `ModifyStatusAction`, `HalveAllStatusesAction`) defaults
  to TARGET. This is a real inconsistency in the codebase, not a bug per se, but worth
  double-checking when authoring new content with these actions.
- **`Technique.step_groups`'s `numeric_bonuses` are shared per group, not per action** — a
  self-targeted and target-targeted action in the same group will incorrectly pool bonuses;
  authors must split them into separate groups. This is a real footgun, not obviously so from
  reading `TechniqueStepGroup` alone.
- **`RandomStatusApplicationAction` deliberately never caches its rolled effect on the shared
  resource** — it constructs a throwaway `StatusApplicationAction` fresh inside the execution
  closure every time, specifically to avoid the `fallback_attack.tres`-style shared-mutation
  incident.
- **Retaliation deliberately chains into `attacker.trigger_on_hit(target)`** so the counterattack
  itself triggers the attacker's own on-hit reactions — this is intentional (the "counterattacks
  should feel like real hits" design goal), not a bug, even though it's the exact mechanism that
  produced a real stack-overflow crash on a self-hit before a guard was added.
- **`Familiar.passives` and `Familiar.focus_table` are deliberately two separate arrays holding
  the identical `PassiveEffect` type** — not a behavioral difference today, a *future*
  tradeability-model difference (see §6).
- **`BracketMatch.is_player_match` is deliberately not `@export`ed**, unlike every other field on
  the class — it's runtime-decided and would be meaningless/misleading if ever saved into a
  `.tres`.
- **`AIDrafter` is intentionally dumb** (§5) — do not read its simplicity as an oversight; it's a
  documented placeholder with a specific, already-designed replacement waiting to swap in at one
  function.
- **The final boss lives outside `resources/familiars/` on purpose** — moving it in would make it
  an unwanted 17th roster entrant for both balance and bracket-generation harnesses.
- **`Combatant.check_passives()` records a passive's fire before running its effect** — looks
  backwards on first read, is the actual anti-recursion fix.
- **`Combatant.reset_turn_passive_limits()` runs before upkeep, not at the top of the turn** — "a
  turn" for limiter purposes spans upkeep + technique execution together; this was non-obvious
  enough that Claude misdiagnosed the actual bug behind it twice before the developer identified
  the real mechanism.
- **Ward only screens externally-inflicted statuses** (`is_self_applied` flag, computed once as
  `user == status_target` in `Technique.apply_status()`). Stagger's own self-inflicted Stun
  deliberately keeps the default `false` for this flag even though it targets its own owner — the
  reasoning is that Stagger's Stun is an externally-imposed *consequence* of accumulated Stagger,
  not a voluntary self-buff, so the owner's own active Ward should still be allowed to screen it
  out, same as it would screen an opponent's debuff.
- **A killing blow short-circuits before the target's own reactive on-hit statuses get a chance to
  run** — `Technique.apply_hit()` checks `target.is_defeated()` right after `take_damage()`,
  before `trigger_on_hit()`'s cascade. Without this, Regeneration made any holder unconditionally
  immune to death by direct hit (an actual former bug, now the deliberate rule).

---

## 12. Known technical debt, hacks, unfinished systems, bugs, placeholders, TODOs

- **`battle_controller.gd`'s `Phase` enum looks vestigial** — set at transition points but never
  read/branched on anywhere in the file as of this research pass. Worth confirming with a grep
  across the rest of the codebase before assuming it's dead, but don't be surprised if removing
  it turns out to be a safe no-op.
- **`scripts/priority_build.gd` (`PriorityBuild`) is confirmed dead code**, unreferenced by any
  script (only the `.tres` files under `resources/priority_builds/` self-reference it, and those
  are themselves orphaned). This is the retired pre-fight build-picker stopgap, superseded by the
  real reward loop. **Do not confuse `PriorityBuild` (dead) with `PriorityBuilder` (the live,
  actively-used in-run rule editor)** — the near-identical names are a genuine trap for a fresh
  read of the codebase.
- **`TechniqueAction`'s `#maybe additional vars like tick_magnitude...` comment** on
  `status_application_action.gd` is an explicit unimplemented placeholder note.
- **`_stat_search.gd` (the automated stat-balancing tool)** was a throwaway script that has since
  been deleted — `AIDrafter.STAT_RANGES`' bounds have no re-derivable source in the repo today
  beyond the comment noting they match what that deleted tool used.
- **`resources/priority_rules/use_venom_strike_if_missing.tres`** was flagged as an orphaned,
  unreferenced resource back in session 2's devlog notes — harmless, never cleaned up, may still be
  present.
- **Thymoxen's passive-operation technique is still named the generic default `"Technique"`**,
  and **Ironcap's Fungal Fortification technically applies "+1 Absorption" phrased oddly when it
  would apply 0** — two known, low-priority content quirks noted during a kit audit, never fixed
  (`DEVLOG.md` session 7).
- **Pebbloq needs a real rebalance pass** — its Ancient Sentinel passive silently never fired
  through the entire session-7 balance pass (an engine bug, since fixed), so the roster's balance
  numbers were tuned around a Pebbloq whose kit didn't actually work. Flagged since session 8,
  never rebalanced.
- **Cleanse (`Array.pick_random()`) and `RandomStatusApplicationAction` are the two documented
  sources of genuine cross-run non-determinism** in an otherwise fully-deterministic combat sim —
  `balance_test.gd`'s "run each pair twice is enough" assumption silently doesn't hold for any
  matchup involving either. No trial-averaging exists yet for this.
- **No stack cap exists on most statuses** — only Acid/Stagger/Absorption clamp via `stack_with()`
  overrides; everything else is uncapped by the engine (see `BALANCE_PRIMITIVES.md`'s
  frequency-vs-magnitude framework for how to reason about whether a specific uncapped case is
  actually a balance risk).
- **No global healing cap exists in code** — `BALANCE_PRIMITIVES.md` states this is a *content
  authoring* constraint, not an engine-enforced one.
- **No combat-history/turn-scoped state exists yet** ("did I hit twice this turn," "how many
  turns has this fight lasted") — explicitly planned (roadmap step 3) but not built; don't assume
  a technique or passive can read this.
- **The exported build `build/FamiliarRPG0.exe` is stale relative to several sessions of fixes** —
  last confirmed re-exported before the Game Over/Restart feature and the `full_roster` export
  fix landed. Re-export before handing a build to anyone, and use preset **"Windows Desktop 2"**
  (see below), not "Windows Desktop."
- **Two confusingly-named, wrongly-mapped Windows export presets exist in `export_presets.cfg`**:
  "Windows Desktop" → `build/FamiliarRPG_0.exe` (underscore, NOT the distributed build) vs.
  "Windows Desktop 2" → `build/FamiliarRPG0.exe` (no underscore, **this is the real one**), with
  `[runnable_presets]` mapping the *name* "Windows Desktop" to preset "Windows Desktop 2" for the
  editor's own Play-as-preset UI. `godot --export-release "Windows Desktop"` silently exports the
  wrong one.
- **Substantial uncommitted working-tree changes exist right now** (see §2 and §14) — the
  bracket-tree rebuild, boss scene wiring, and a new balance-doc are all real, working,
  documented-in-DEVLOG functionality sitting uncommitted.
- **`BracketOdds`'s formula/thresholds are explicitly untested** (repeated across three DEVLOG
  sessions without being addressed).
- **`AIDrafter` and the whole AI-drafting/priority-optimizer spec are unimplemented** — the single
  biggest planned-but-not-started system in the project right now.
- **No automated test coverage exists for `BracketTree`/`BracketScreen`** (pure UI/Control code) —
  `bracket_test.gd`'s 12 checks cover the data-model/simulation layer only.
- **`TooltipLayer`'s `LINK_DRIFT_TOLERANCE` (40px) is a tuned heuristic, not a permanent fix** —
  revisit if a future reward-card description packs status links close enough together that 40px
  isn't enough separation.
- **`Familiar.duplicate_for_run()` deep-copy scope is exactly right for today's needs but is a
  hand-maintained list** (re-duplicates `techniques`/`priority_rules`/`passives`/
  `species_affinities` specifically) — a new mutable-array field added to `Familiar` in the
  future must be added to this method too, or it will silently leak across runs the same way the
  original bug did.

---

## 13. Features currently being worked on or planned next

See §2's numbered roadmap for the full ordered list (AI drafting personalities → full-run
simulation harness → engine scaffolding for turn/battle-scoped state and a consistent
hit-vs-status-damage rule and turn-order modifiers → larger content pass → continuous balance-sim
validation → real art/VFX/SFX/music → final polish → v0.1 → v0.2+ ideas). Nothing on this list has
been started as of the last recorded session. The uncommitted working-tree state (§2, §14) is the
*previous* item's tail end (final boss + bracket-tree visualization), not part of this list.

---

## 14. Uncommitted working-tree state (confirmed via `git status`, current branch `master`)

```
 M .claude/DEVLOG.md, FAMILIAR_FIGHT_CLUB_VISION.md, GAME_DESIGN.md, LEARNING_ROADMAP.md
 M docs/superpowers/specs/2026-09-06-ai-drafting-design.md
 D resources/bosses/final_boss_stub.tres                       (superseded, deletion intentional)
 M resources/passives/refute_death.tres
 M resources/priority_rules/champion_calamity_rule.tres, champion_reap_rule.tres, champion_taste_rule.tres
 M resources/techniques/calamity_manipulation.tres, reap.tres, taste_of_immortality.tres
 M resources/techniques/passive_operations/refute_death.tres
 M scenes/battle.tscn, battle_panels/bracket_screen.tscn, battle_panels/reward_select_panel.tscn
 M scripts/bracket/bracket_odds.gd, bracket_screen.gd
 M scripts/ui/palette.gd
?? .claude/BALANCE_PRIMITIVES.md                                (new design doc)
?? assets/ui_mockup/prefight_mockup.png(.import)
?? balance_reports/*.csv                                        (harness output, gitignore candidate)
?? resources/bosses/entropy.tres                                (the real boss content, replacing the stub)
?? scripts/bracket/bracket_tree.gd(.uid)                         (the tournament-tree widget, new)
```

Last commit: `110574a feat: final boss kit (Calamity Manipulation / Taste of Immortality / Reap /
Refute Death)`. That commit captured an earlier draft of the boss's content resources; the working
tree now has further refinements to those same resources **plus** the entire `BracketTree`
visualization rebuild and its scene wiring, none of which is committed. Per `CLAUDE.md`'s git
safety rules, this should be surfaced to the developer for a checkpoint commit rather than
silently built on top of or discarded.

---

## 15. Major design decisions considered and explicitly rejected

Knowing these prevents re-proposing them:

- **Approximating off-screen bracket matches with a stat-comparison formula instead of running the
  real engine.** The original bracket design spec assumed real simulation would be too expensive;
  measurement showed it's cheaper (≤11 matches/run at ~7.5ms each) than maintaining and balancing
  a second, cruder combat model. **Don't propose a lightweight stat-comparison approximation for
  anything this project can afford to simulate for real.**
- **One `Technique` subclass per move/status-applier.** Tried first, explicitly identified as
  over-engineering once three "different" moves turned out to be the same formula with different
  constants. `Condition` is the deliberate counter-example — genuinely different logic per kind,
  correctly subclassed.
- **A generalized event-bus/service-layer/dependency-injection architecture, or a large generic
  ability framework.** Explicitly rejected per `CLAUDE.md`'s "avoid premature architecture"
  section — the `PassiveEffect` Trigger/Conditions/Limiter shape with 5 payload subclasses is the
  actual answer that emerged from a wide survey of desired passive behaviors, not a
  general-purpose framework built ahead of need.
- **Letting the priority editor's mock-state panel declare arbitrary HP/status state directly**
  (an earlier design). Replaced because it bypassed `add_status()` entirely (so Ward/Absorption/
  passives never actually engaged), making the panel unable to show what a build's passives
  actually do — the real engine bug this masked (Stasis never notifying the passive system) only
  surfaced once the panel was rebuilt to drive real `BattleEngine` calls.
- **A single mutually-exclusive-field `PassiveEffect` class** (one class, several dead fields per
  instance depending on payload type) instead of subclassing. Tried first, abandoned once a third
  payload type made "several dead fields" clearly the wrong shape.
- **Threading an `opponent` parameter through every stack-reduction call site** instead of adding
  `Combatant.opponent` as a stored field. Rejected as a much larger blast radius (would have
  touched `Status.on_applied()` and every subclass override) for the same result.
- **A new dedicated `Condition` subclass for "check my own status" instead of a `Target` enum
  field on the existing classes.** The developer specifically chose to add `Target{SELF,TARGET}`
  to `TargetMissingStatusCondition`/`TargetStatusStacksBelowXCondition` rather than accept Claude's
  suggested new subclass, reusing an enum shape already established elsewhere.
- **`STATUS_REMOVED` as mutually exclusive with `STATUS_REDUCED`** (fires only on full depletion,
  never on a partial reduction). Reversed once a passive watching "any decrease" via REDUCED alone
  missed exactly the depletions it most wanted to react to (Absorption being fully consumed by one
  big hit) — REDUCED is now inclusive, REMOVED fires additionally as the exclusive subset.
- **A new hardcoded `Combatant` bool (`is_defending`) staying a plain bool forever.** Converted to
  a real `Status` (`DefendingStatus`) once `Status` grew hooks (`on_hit`, `on_applied`) that made
  the original "doesn't fit Status's shape" reasoning stop applying.
- **A parallel predicate/condition language for the AI-drafting `priority_hints` system.**
  Explicitly rejected in favor of reusing the exact three existing `Condition` subclasses the
  priority builder's own palette already covers — "the same evaluator `Combatant.choose_technique()`
  uses, not a second one the optimizer would need its own confidence in."
- **A per-personality `DrafterPersonality` subclass** (one class per Greedy/Synergy
  Master/Random). Rejected for the same data-vs-subclass reason as `Technique` — every personality
  runs an identical formula, differing only in weights.

---

## 16. Balance/design constants code should not casually change

Full detail lives in `.claude/BALANCE_PRIMITIVES.md` — treat the following as **Balance Primitives
(stable language)** vs. **Content-Specific Values (expected to move)**. Do not conflate the two.

**Stable (don't change without ecosystem-wide evidence + explicit revision note):**
- The damage formula itself: `raw² / (raw + defense)`, floored at 1, integer division.
- `power_multiplier` band: **0.1** (chip) / **0.333** (small) / **0.667** (medium) / **1.0**
  (strong standard) / **1.5+** (uncapped burst territory) — an authoring convention, not
  engine-enforced, but a deliberate shared vocabulary. A technique landing on an arbitrary decimal
  (0.74, 0.82) should be a stated, deliberate exception, not a rounding choice.
- `ignore_power_and_defense` hits use small whole-number flat amounts (1–5ish), a different
  sub-language from the fractional band above.
- Stat band for Power/Defense/Speed/Focus: roughly **2–20** (observed roster property, not
  enforced). Max HP is a **separate scale**, roughly **40–75** — do not treat HP as part of the
  same 2–20 language.
- Focus is a **threshold stat** (fixed breakpoints unlock fixed bonuses), never a linear-scaling
  stat like Power.
- Absorption's **20-stack cap** — a deliberate anti-stalemate fix, verified against real matchup
  outcomes (Carapax/Ironcap win rates moved measurably when it landed).
- The **200-turn stalemate threshold** in `balance_test.gd` — an operational definition of
  "stalled," not to be casually changed without evidence a different cap serves testing better.
- The frequency-vs-magnitude test for self-contained "engine" kits (a fixed-size repeated payout is
  a legitimate build-around reward; a payout whose own *size* grows from repeated self-use with no
  external check is the real red flag) — see `BALANCE_PRIMITIVES.md`'s worked Pebbloq/Guubal/
  Mystbud examples before flagging new content as broken.

**Expected to move freely, never a target to preserve:** exact familiar win rates, exact
technique/passive numeric tuning (including Pebbloq's, used only as a *qualitative* interaction-
design example, not a numeric one), the current 32-technique/~16-passive content pool size, current
reward-pool rarity weighting, `BracketOdds`'s specific constants (explicitly unvalidated, see §12).

---

## 17. Where code disagrees with documentation, and which is authoritative

- **`battle_controller.gd`'s own header comment still narrates a `_randomize_matchup()` /
  `full_roster`-gauntlet flow that no longer exists as live code** — the bracket is the only
  matchmaking path today. **Code (current bracket-only reality) is authoritative**; the comment is
  stale documentation, not a live alternate mode.
- **`GAME_DESIGN.md` §10's roadmap narrative and `DEVLOG.md`'s session log describe the
  bracket-tree rebuild and final boss kit as fully "Done"** — true in terms of *implemented and
  playtested behavior*, but as of this writing that work is **partially uncommitted** (§14). Both
  docs are accurate about functional completeness; git history alone would understate what's
  actually built. **Trust the working tree + DEVLOG over `git log` for "what currently works."**
- **`Familiar.passives` currently has no `tags` field of its own that the earlier design
  conversations sometimes implied** — the actual tag vocabulary lives on `Technique.tags` /
  `PassiveEffect.tags` / `TagAffinity.tag` (inside `species_affinities`), not a bare `Familiar.tags`
  array. If older notes or a stale mental model reference "a familiar's tags," they mean
  `species_affinities`.
- **`.claude/BALANCE_PRIMITIVES.md` is new and currently untracked in git** — it is a real,
  intentional design document (not a draft to discard), written specifically to separate "stable
  numeric language" from "current content numbers" going forward. Treat it as authoritative for
  balance philosophy even though it postdates and isn't cross-linked from `GAME_DESIGN.md` §5.2's
  older prose.

---

## 18. Things I know that are not adequately documented anywhere in the repo

These come from the accumulated development conversations and cannot be reliably reconstructed
from the code or existing markdown alone:

- **The collaboration mode shifted explicitly, twice, and this affects how to read the codebase's
  authorship signal.** Sessions 1–6 were "developer designs and implements, Claude reviews" for
  most content (statuses, the technique-composability rework). Starting session 7, the developer
  explicitly handed the 16-familiar content pass and its engine bugs to Claude
  ("`pixel_pugilists_balance_tuning_workflow`" pattern: developer describes a kit in plain
  language, Claude picks concrete numbers/triggers and iterates against the balance harness).
  Session 12 made this durable and general ("I want to take the reins more as system design and
  production while you implement things") — this **formally supersedes** `CLAUDE.md`'s original
  "Claude implements → developer extends → Claude reviews" teaching progression for the areas it
  covers. **Do not assume the codebase reflects the developer's own unaided GDScript** for
  anything built from session 7 onward — most of it (the roster, the bracket, the visual overhaul,
  the final boss, `BracketTree`) was Claude-implemented from a developer-authored design brief,
  with the developer's actual hands-on contribution concentrated in design direction, review, and
  live playtesting bug reports. This matters if you're asked to calibrate explanations to "what
  the developer already understands" — check `LEARNING_ROADMAP.md` §2's demonstrated-knowledge
  table for what's actually been hands-on-verified versus what's Claude-authored code the
  developer has reviewed but not typed.
- **A recurring, load-bearing process lesson that isn't captured as a rule anywhere except buried
  in DEVLOG prose**: for any screen tied to a mockup image, study the mockup fully and compare it
  against a plan task's *literal stated scope* before writing code, and ask 1–2 concrete scope
  questions up front rather than shipping the minimal literal reading. This came from two screens
  in a row (prefight, stat-upgrade) needing multiple rounds of post-hoc correction in session 10;
  the very next screen done this way (asking scope questions first) landed in one round. This is
  now in `CLAUDE.md`'s "Current development priority" section as a standing instruction, but the
  *reason* it exists — the actual before/after contrast — lives only in `DEVLOG.md` session 10's
  prose.
- **The MCP Godot-editor toolkit (`godot-mcp-toolkit`) is unreliable across sessions in specific,
  recurring ways not written into any single "known issues" list**: it can silently break from
  stale registries when multiple Godot processes are running concurrently (needs an editor
  restart, not a toolkit fix); its `input_simulate`/`click_node` fires a button's `pressed` signal
  directly, bypassing visibility entirely — this produced two separate false-alarm "bugs" in one
  session (clicking a hidden Restart button mid-fight, clicking a hidden BeginCombat button
  mid-character-select) that looked exactly like real game bugs. **Screenshot first and confirm a
  target is actually visible before using `click_node`**, or use a coordinate-based click, which
  does route through real hit-testing.
- **A live editor connection and direct `.tres`/`.tscn` file edits can race each other** — if the
  editor has a scene open, its in-memory state can silently overwrite a disk edit on its next
  autosave, and the reverse race (a live editor edit losing to a stale disk write) is equally
  possible. When the MCP toolkit is connected and the affected scene is open, prefer making changes
  through it (`node_manage`/`node_set_property`, then an explicit `editor_save_scene`) rather than
  editing the file directly.
- **Switching git branches while the Godot editor is running silently corrupts
  `.godot/global_script_class_cache.cfg`** (gitignored, not versioned) — a checkout that
  temporarily removes `class_name` scripts makes the running editor drop those registrations, and
  checking back out restores the files but not the cache, producing a pile of misleading "not
  declared in the current scope" parse errors that look exactly like broken code. Fix: force a full
  rescan with `godot --headless --editor --quit-after 300` (not `--quit`, which exits before the
  deferred filesystem scan completes).
- **The `RewardSelector`'s whole weighted-tagging system silently ran as uniform-random for an
  entire session (session 8) before anyone noticed**, because none of the 66 techniques/passives/
  familiars had ever had `tags`/`role_*`/`species_affinities` actually authored — "tailored" and
  "random" look identical until you compare the actual draw distributions. This is exactly the
  kind of silent-degradation risk to watch for with any future tag-driven system (the AI-drafting
  spec depends on the same tag data being genuinely populated, not just declared as a field).
- **A round-robin balance harness's win rates are zero-sum-ish** — nerfing/buffing several
  familiars in one batch can shift *other*, untouched familiars' numbers, sometimes in the
  opposite direction from what was intended for the familiar actually being changed. Always rerun
  the full round-robin after a batch change; don't reason about one matchup's numbers in isolation.
- **The developer's own priority order, stated explicitly and worth remembering when calibrating
  how much to explain vs. just build**: "#1 learn the engine, #2 build Pixel Pugilists, #3 have
  fun" (`LEARNING_ROADMAP.md` header) — though session 12's collaboration-mode shift (above)
  changed *where* that learning time goes, not whether it matters. It is not "learning is over,"
  it's "the developer chose to spend remaining learning time on system design/architecture rather
  than on typing ordinary GDScript syntax personally."
- **`resources/priority_rules/*.tres` files experienced two entirely separate, unrelated waves of
  file churn that could be mistaken for meaningful diffs**: (1) a batch `ResourceSaver.save()`
  re-save of 66 resources during the tagging pass dropped their inline UIDs, causing the editor to
  mint fresh ones and rewrite ~32 unrelated priority-rule files over the following hours — harmless,
  self-resolving, not another session's edits; (2) stale-UID warnings on newly-created scripts
  clear up the next time the actual editor opens and rescans. Neither indicates a real content
  change if seen in a diff.

---

## 19. Common misinterpretations a new agent might make

- **"There's a non-bracket fallback/gauntlet mode I could use for quick testing."** No — it was
  fully retired. `battle_controller.gd`'s own header comment is stale and still describes the
  transition away from it, which is genuinely confusing on a first read. The bracket
  (`Bracket.generate()` + `full_roster`, which must be exactly 16 entries) is the only path to a
  playable fight.
- **"`PriorityBuild` is the priority-rule editor."** It is not — it's dead, retired code (the old
  pre-fight build-picker). The live editor is `PriorityBuilder` (no trailing article, different
  file, `scripts/priority_builder/`). The names are dangerously similar for a fresh read.
  Double-check which one a search result actually points at.
- **"Overriding `Status.max_stacks()` caps that status's stacking."** It doesn't, by itself —
  `max_stacks()` is only consulted by `Combatant.modify_status_stacks()` (the direct-manipulation
  path), never by `add_status()`'s normal merge path (`stack_with()`). A real cap requires
  overriding `stack_with()` too, with an explicit `min()` clamp (the Acid/Stagger/Absorption
  convention).
- **"Ward/Absorption/Stasis must be somewhere in `status.gd`'s subclasses since they're
  statuses."** Ward and Absorption's actual mechanics live in `Combatant.add_status()`/
  `take_damage()` as hardcoded interception checks; Stasis's redirect mechanism lives inside the
  *base* `Status.stacks` setter. Their subclass files (`ward_status.gd`, `absorption_status.gd`,
  `stasis_status.gd`) are near-empty shells (id/icon/describe only).
- **"`trigger_target = SELF` is redundant/wrong for a passive that only ever fires on its own
  owner's action."** It's required, not redundant — the default is `TARGET` ("my opponent"), and a
  mismatched `trigger_target` fails **completely silently** (the passive just never fires, no
  error, no warning). This has been a real, repeated bug source.
- **"`HIT` and `ATTACK` are the same trigger, just named differently."** They fire at the *same
  physical moment* but check *different sides'* passives — `HIT` fires on the defender,
  `ATTACK` fires on the attacker. A passive reacting to its own owner's attack needs `ATTACK`, not
  `HIT` — a very natural but wrong assumption from the name alone.
- **"The AI opponents in the bracket have a real drafting strategy."** They follow one fixed,
  non-adaptive rule (`AIDrafter`, §5) that's explicitly a placeholder awaiting a fully-designed but
  unimplemented replacement. Don't infer intentional personality/strategy from watching AI
  opponents' builds develop over a run.
- **"`git log` on this branch shows the current state of the bracket/boss work."** It doesn't
  fully — see §14. Substantial, working, DEVLOG-documented functionality is sitting uncommitted in
  the working tree right now. Diff against the working tree, not just `HEAD`, before concluding
  something is unbuilt.
- **"Speed-driven turn order and the whole stat line are settled, locked design."** They're
  explicitly `OPEN / PLAYTEST` in `GAME_DESIGN.md` §5, despite being fully implemented and shipped
  for many sessions. Fully-built does not mean locked in this project's vocabulary.
  `GAME_DESIGN.md`'s own status tags (§1 above) are the authority on this, not "how long has it
  existed."
- **"Since Focus is a stat like the other four, higher Focus should scale a technique's effect
  proportionally."** Focus is explicitly a **threshold** stat (fixed breakpoints, fixed bonuses) —
  the design intent is parity checks and range checks, not linear scaling. Don't design new
  Focus-based content that treats it like Power.
- **"A `Technique`'s `numeric_bonuses` array applies per-action."** It's shared across every
  action in the same `TechniqueStepGroup`, filtered only by `ActionType` (HIT/STATUS/HEAL), not by
  which specific action it's attached to. Two actions of the same type in one group share the same
  bonus pool.
- **"`Familiar.duplicate_for_run()` and a plain `.duplicate()` are interchangeable for a
  `Familiar`."** They are not — plain `.duplicate()` shares `Array` properties with the original
  (a documented, previously-real, long-latent bug: appending to a "copy's" techniques mutated the
  cached base `.tres` for the rest of the process). Always use `duplicate_for_run()` for a new
  run/bracket-entrant copy, and remember to extend it if a new mutable array field is ever added to
  `Familiar`.
- **"The mock-state panel's dummy opponent fights back, so a build's full reactive kit can be
  verified there."** The dummy deliberately never takes its own turn — any mechanic depending on
  the *opponent acting* (Defending's on-hit decay, Ward's absorb-then-decay) simply cannot progress
  in this simulator. This is a documented, accepted limitation, not a bug to chase if a
  defensive/reactive build "doesn't seem to do anything" in the probe.
