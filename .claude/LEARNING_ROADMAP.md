# Pixel Pugilists — Learning Roadmap

Living curriculum tying real Pixel Pugilists development to the developer's growing
Godot/GDScript fluency. Update this file whenever a concept's status changes, a step is
completed, or the architecture shifts — see `.claude/CLAUDE.md` for the teaching workflow
this file supports. Pixel Pugilists is a standalone prototype for the larger planned
*Familiar Fight Club* — see `GAME_DESIGN.md` and `FAMILIAR_FIGHT_CLUB_VISION.md`.

Developer's stated priority order: **#1 learn the engine, #2 build Pixel Pugilists, #3 have fun.**
Pacing favors depth over speed — slow down, ask for explanations back, and spend extra
exercises on shaky concepts rather than rushing toward a milestone.

## 1. Current project snapshot

Godot 4.7 (Forward Plus, Jolt Physics, d3d12 on Windows), `project.godot` already correctly
named "Pixel Pugilists" (renamed mid-project from "Polygonal Pugilists" once real sprite
art replaced placeholder shapes — see `DEVLOG.md`). The project was bootstrapped from
scratch — no code carried
over from the sibling `turn-based-combat-tutorial` reference project, though its
`CombatHistory`/`combat_log.gd` decoupled data/view pattern was deliberately reused under
new names.

Single scene family under `res://scenes/` and `res://scripts/`, wired together in
`battle.tscn` (the project's main scene):

- **`Familiar`** (`familiar.gd`, `Resource`) — a familiar's build: name, sprite, max_hp,
  power, defense, speed, focus. The *same type* for player and enemy — deliberately
  symmetric (see `DECISIONS.md`), unlike the old tutorial's split between a player
  autoload and an enemy-only Resource. Two content instances exist,
  `resources/twerpent.tres` (player) and `resources/guubal.tres` (enemy), both using real
  sprite art carved from sprite sheets via `AtlasTexture` sub-resources — a technique the
  developer found and applied independently, not something taught.
- **`Combatant`** (`combatant.gd`, `RefCounted`) — per-battle runtime state wrapping a
  `Familiar`: current_hp, is_defending, statuses. Built fresh each battle for both sides
  through the identical code path — no asymmetry is possible by construction.
- **`BattleController`** (`battle_controller.gd`, on `Battle`, the scene root) — drives a
  real `Phase` enum state machine (`PLAYER_TURN` / `ENEMY_UPKEEP` / `ENEMY_TURN` /
  `PLAYER_UPKEEP` / `BATTLE_OVER`), resolves Attack / Defend / Poison Strike ("Venom
  Strike") / Burn ("Searing Spit") / Acid ("Acid Bath"), and ends the battle on
  victory/defeat. **No autoloads exist in this project** — a deliberate choice, not an
  oversight.
- **`Status`** (`scripts/status/status.gd`, `RefCounted`) base class — now 24 concrete
  subclasses covering damage-over-time, stat buffs/debuffs (`modify_stat()`, generalized
  from an Acid-only `modify_defense()` once Fortify/Hone/Enlarge needed it too),
  interception (Ward, Absorption — see `DECISIONS.md`), and retaliation (Thorns,
  Retaliation). See `DECISIONS.md` and `LEARNING.md` for the mechanics and hook-ordering
  lessons this produced.
- **`PassiveEffect`** (`scripts/passive/passive_effect.gd`, `Resource`) base class — a
  species-bound passive as Trigger + Conditions + Limiter, four payload subclasses
  (`OperationPassiveEffect`, `ModifyStatusPassiveEffect`, `ModifyHealPassiveEffect`,
  `PermanentStatPassiveEffect`). `FocusBreakpointCondition` ties a passive's activation to
  a Focus tier rather than a hardcoded value. Full architecture and the reentrancy bugs it
  took to get right are in `DECISIONS.md`.
- **`Technique`** (`scripts/technique/technique.gd`, `Resource`) — a familiar's authored
  combat action, now built from composable steps rather than one hardcoded
  hit/heal/status sequence: `step_groups: Array[TechniqueStepGroup]`, each group gated by
  its own `conditions`, repeated `repeat_count` times, running a list of
  `TechniqueAction` subtypes (`HitAction`, `HealAction`, `StatusApplicationAction`,
  `ModifyStatusAction`) and optionally adding situational `NumericBonus`es
  (`ConditionalNumericBonus`, `StackCountNumericBonus`, `StatusCountNumericBonus`,
  each tagged via `applies_to` for which action kind sums it in). `execute()` returns
  `Array[Callable]` (one per action) rather than one combined message, so
  `battle_controller.gd` can log and pace each step individually. `Familiar.techniques:
  Array[Technique]` holds each familiar's moveset. See `DECISIONS.md`.
- **`Condition`** (`scripts/condition/condition.gd`, `Resource`) — one subclass per
  condition kind (`TargetMissingStatusCondition`, `SelfHPBelowXCondition`,
  `TargetStatusStacksBelowXCondition`, `NotCondition` for negation), since these read
  genuinely different battle-state facts, unlike `Technique`'s parameterized cases.
  `PriorityRule` pairs an ANDed `conditions: Array[Condition]` with a `technique`;
  `Familiar.priority_rules` is an ordered list of these, evaluated by
  `Combatant.choose_technique()`.
- **`UpgradeOption`** (`scripts/upgrade/upgrade_option.gd`, `Resource`) — a post-fight
  reward choice, subclassed (`AddTechniqueUpgrade`, `ModifyStatUpgrade`, `AddPassiveUpgrade`,
  `TradePassiveUpgrade`) since each kind changes a familiar's build differently.
- **Reward system** (`scripts/reward/`, session 8) — `RewardTag`/`TagAffinity` (a closed
  tag vocabulary plus weighted species affinities), `BuildSnapshot` (tag/role counts
  derived from a familiar's currently-equipped techniques/passives), `RewardSelector`
  (pure weighted-scoring functions across three named slots — Species/Run/Pivot — decoupled
  from `Combatant`/UI on purpose), `RewardProgression` (the round→reward-kind cadence, a
  real `RewardKind.NONE` once it runs out), and `RewardFlowController` (orchestrates one
  reward-screen session: RNG, snapshot, rerolls, staged stat allocation). Full architecture
  and reasoning in `DECISIONS.md`.
- **`PriorityBuild`** (`scripts/priority_build.gd`, `Resource`) — the old pre-fight
  build-picker's data shape. The picker itself is retired now that the reward system above
  exists (a drafted familiar just starts with its own authored default build); this script
  and its `.tres` content are currently unreferenced.
- **`CombatLog`** / `CombatLogView`, **`HPBar`**, **`StatusRow`** — small, decoupled,
  reusable UI pieces. `HPBar` draws a colored preview of upcoming status damage;
  `StatusRow` shows every active status uniformly (including non-damaging ones like Acid).

**Current playable state:** the player starts with their drafted familiar's own default
build, then plays through multiple rounds of autonomous 1v1 fights — **zero manual clicks
on either side** during a fight, both `Combatant`s choosing via the same
`choose_technique()` evaluator through `battle_controller.gd`'s unified `take_turn()` —
with the real tailored reward screen (session 8; weighted Species/Build/Wildcard slots,
shared rerolls, allocate-then-confirm stat upgrades) between rounds actually growing the
build. HP bars, status previews, and the status icon row all update live and pace one
step at a time now (each hit/heal/status application its own log line, not a batched turn
summary), with the whole HUD (panels, speed toggle, combat log) hidden during the reward
sequence and restored once the next fight begins. Verified with headless Godot scripting
(see `CLAUDE.md`'s Validation section), not only by manual play.

**What's conspicuously absent relative to Milestone 1:** no round/shop loop, no
rematch/rebuild flow, no persistent build accumulation across fights, no targeting (only
one possible opponent exists), no boss encounter, no save data, no permanent automated
test suite beyond `scripts/tools/balance_test.gd`/`diagnose_matchup.gd` (both committed,
not throwaway — everything else still follows the write-a-`_verify_*.gd`-script-and-
delete-it pattern).

**Session 7 update:** the 16-familiar roster is complete (Ashwing, Battabat, Berylazagor,
Carapax, Guubal, Ignimite, Ironcap, Mallegrav, Mystbud, Omenfly, Pebbloq, Pyrewisp,
Relikarn, Shrumbus, Thymoxen, Twerpent), each with two techniques, priority rules, and a
species passive, and the shared `FocusTable` finally has real content (four tier-gated
effects). A full-roster balance pass (manual tuning plus an automated stat-search tool,
see `DECISIONS.md`) landed every familiar between roughly 40–60% win rate in the
round-robin harness, none doomed. Four real engine bugs were found and fixed along the
way (a Retaliation stack-overflow, Ward absorbing self-applications, a lethal hit that
could heal itself back to life, Cleanse silently bypassing the passive-notification
system) — see `DEVLOG.md`/`DECISIONS.md` for the mechanics.

**Session 8 update:** the real reward screen exists (weighted Species/Build/Wildcard
slots, shared rerolls, allocate-then-confirm stat upgrades, the passive-trade flow), the
pre-fight `PriorityBuild` picker is retired, and the priority editor is integrated into
the live game loop. Most of the session after the reward system itself was a debugging
arc on the tooltip system it exposed — three real, non-obvious root causes (hover-tracking
keyed by the wrong granularity, a cached-vs-on-demand Control size read too early, and a
genuine `RichTextLabel` reliability gap confirmed by reading Godot's own engine source) —
see `DEVLOG.md`/`DECISIONS.md`.

**Session 8, continued (same day):** five rounds of live-tested drag-and-drop feel fixes
on the priority builder, a `PassiveEffect.describe()` overhaul, and the mock-state panel
rewritten from "declare a hypothetical state" into "play the current build out for real
against a passive dummy" — which immediately surfaced a genuine engine bug (Stasis's
stack-interception mechanism never told the passive system *it* was the status that
changed, so Pebbloq's Ancient Sentinel had silently never fired in any real fight, not
just this panel — see `DECISIONS.md`). Absorption gained a stack cap; the player/opponent
matchup is now randomly drawn at every launch instead of fixed; a Game Over screen with
Restart replaced quitting the app outright. All of this was still Claude-implemented, same
as sessions 7 and 8's first half — see the "third consecutive session" note in §7 below,
which this extends to a fourth.

## 2. Demonstrated knowledge

| Concept | Status | Evidence |
|---|---|---|
| Scene composition (Control/VBox/HBox, anchors, Containers) | Practicing | Restructured `HPBar`'s root from a bare `ProgressBar` into a composite `Control` via "Reparent to New Node"/"Save Branch as Scene"; still needed guidance on *why* `custom_minimum_size` and "Full Rect" anchors must be set at every level of a hierarchy, not just the top, so not yet independent here. The priority builder added a five-scene three-column layout (Claude-built), which surfaced the same lesson twice more concretely: a non-scrolling panel's minimum size propagates up and starves its siblings, and an empty `Container` has zero size — so a drop target needs `custom_minimum_size` or it is literally unhittable |
| Drag-and-drop (`_get_drag_data`/`_can_drop_data`/`_drop_data`) | Introduced | Claude-built for the priority builder. Worth knowing before touching it: `at_position` is in the *receiving* control's space (transform it rather than doing local rect math across a `MarginContainer`, and never substitute `get_global_mouse_position()`); drop targeting asks the innermost `MOUSE_FILTER_STOP` control and does **not** reliably bubble past one, so a parent that expects a refused query to reach it will simply never be asked — that bug made segment reordering silently do nothing |
| `HFlowContainer` vs `HBoxContainer` | Introduced | A row of dropdowns in a narrow column has to wrap, and an `HBox` can't — it forces the whole list to scroll sideways instead |
| Basic GDScript (functions, typed vars, `@onready`) | Demonstrated | Used correctly and independently across `BurnStatus`, `AcidStatus`, and multiple self-found bug fixes |
| `enum` | Demonstrated | Confidently expanded `Phase` from 3 to 5 states for the upkeep-phase redesign |
| Custom signals (declare + `emit` + `.connect()`) | Demonstrated | `CombatLog.entry_added` reused and extended correctly multiple times |
| Signals via editor `[connection]` blocks | Demonstrated | Wired three new action buttons (Poison, Burn, Acid) correctly and independently |
| `@export var x: T: set(value): ...` custom-setter pattern | Practicing | `HPBar`'s `bar_background_style`/`bar_fill_style` exported `StyleBox` setters, applied correctly and combined with `@tool` for live-editor preview — a nice self-directed extension |
| `@tool` scripts | Practicing | `hp_bar.gd`, applied correctly |
| Runtime `instantiate()`/`add_child`/`queue_free` | Practicing | `HPBar`'s status-preview `ColorRect`s, `CombatLogView`'s labels |
| `class_name` + inheritance/polymorphism (`extends`, overriding virtuals) | Demonstrated | `Status` → `PoisonStatus`/`BurnStatus`/`AcidStatus`, correctly recognizing which virtual methods needed overriding vs. which base defaults already worked (e.g. neither Poison nor Acid needed to touch `is_expired()`) — genuinely new this session, learned quickly |
| Typed collections (`Array[Dictionary]`, `Array[Status]`) | Practicing | |
| Custom `Resource` subclasses for data/content | Demonstrated | `Familiar`, extended with new content instances (`guubal.tres`/`twerpent.tres`) independently, including `AtlasTexture` sub-resources for sprites — beyond what was taught |
| Autoloads/singletons | Introduced | Concept known from the old tutorial; this project deliberately uses none |
| State machines | Practicing | A real enum-driven `Phase` state machine (not the old informal array+index), extended by the developer for the upkeep-phase redesign |
| Async/coroutines (`await`) | Practicing | Implemented the upkeep-phase pacing after a detailed design conversation; understands the "calling a coroutine without awaiting it still runs it" behavior and the `get_tree().quit()` timing gotcha it exposed |
| Save/persistence | Not introduced | — |
| Automated tests | Not introduced | The headless-script verification pattern (see `CLAUDE.md`) has been used constantly, but always written by Claude — writing one independently would be a good future exercise. The priority builder sharpened two rules that any such script needs: a GDScript runtime error aborts only its own function, so a harness without a per-check completion marker will report success for a check that crashed (observed), and any `SCRIPT ERROR` in the output has to be treated as a failure at the shell level since GDScript can't see its own runtime errors |
| Data vs. subclass judgment (parameterize vs. subtype) | Demonstrated | Correctly challenged Claude's own over-subclassed first pass at `Technique` (one subclass per status-applying move) as unearned, since the cases were parametrically identical rather than behaviorally different — led directly to the enum+fields redesign now in `DECISIONS.md` |
| Typed `Array[CustomResourceClass]` exports | Demonstrated | `Array[Technique]`, `Array[PriorityRule]`, `Array[Condition]` authored and edited correctly and independently via the Inspector across many resource files this session, including nested/embedded sub-resource arrays |
| Godot resource save/dirty-tracking mechanics | Introduced | Diagnosed (with Claude, via live MCP introspection) why a deeply-nested resource edit made through a scene's Inspector didn't persist to the underlying `.tres` file — a real, reusable debugging lesson, not yet independently applied |
| Large-scale data-driven architecture design | Demonstrated | Designed and implemented the entire composable `TechniqueStepGroup`/`TechniqueAction` rework of `Technique.execute()` independently (Claude reviewed and migrated existing `.tres` content afterward) — not an assigned exercise, a self-initiated redesign motivated by a real limitation hit while testing Enlarge. Re-derived the session-1 "subclass only when logic differs" rule unprompted while doing it (questioning whether `HealTechnique` still needed to be its own subclass) |
| Independent content authoring (Status subclasses) | Demonstrated | Implemented 11 new `Status` subclasses independently (Infestation, Hone, Fortify, Enlarge, Recharge, Ward, Thorns, Hex, Absorption, Ruin, Retaliation) — including Ward and Absorption, which needed the harder "intercept inside `Combatant`" shape rather than a normal overridden hook — with Claude limited to review, `StatusEffect` enum/factory wiring, and design guidance only when directly asked (Ward's approach) |
| Trigger/event-side matching (attacker vs. defender hooks, `trigger_target: SELF`/`TARGET`) | Demonstrated | After Claude explained why Taste for Blood's `HIT` trigger + default `trigger_target` never fired for Battabat's own attack, corrected both fields (`ATTACK`, `trigger_target = SELF`) independently and correctly on the first try |
| Reasoning about event-ordering/scoping bugs in a cascading system | Demonstrated | Diagnosed the real mechanism behind a passive firing twice in one turn after Claude's first two hypotheses were wrong, correctly landing on "a turn is upkeep + execution together" — the fix `battle_controller.gd` now implements |
| Recognizing when two symptoms share one root cause | Demonstrated | Correctly rejected Claude's premature "nothing consumes Stasis" conclusion by citing a specific counter-observation from real play (a Recharge pickup visibly draining Stasis) *before* Claude had found the real bug — redirected the investigation to the actual gap (the passive system never being told about it). Separately, independently connected "Pebbloq wasn't a balance outlier before" to "the same reason its passive didn't fire in the mock-state preview," ahead of Claude proposing that link |
| Game-balance reasoning about a shield/pool mechanic | Introduced | Correctly reasoned through, unprompted, that capping Absorption's stack pool only prevents the *unbounded-restacking* class of stalemate specifically, and that what matters is an opponent's cumulative damage within one round against whatever the pool holds — not "a single hit" in isolation |

**Design ownership — a milestone, not a checklist item**: session 2 recorded the developer's first substantive pushbacks on Claude's proposed designs (the `Technique` over-subclassing, and the Step-5 sequencing challenge). Sessions 3–4 went well beyond pushback: essentially the entire technique-rework-plus-eleven-statuses content wave was designed and typed by the developer, with Claude in a pure review/support role (enum wiring, resource migrations, bug fixes only when explicitly requested). That's the "developer designs and implements — Claude acts mainly as reviewer/debugging partner" end state `CLAUDE.md`'s north star describes, reached far earlier than the roadmap's original pacing expected. The one caution from this stretch: Claude implemented one full bug fix (the Ruin/Absorption damage-log bug) from a casual "let's fix X" without re-confirming first, a repeat of an already-flagged pattern — worth the developer continuing to watch for, not because the fix was wrong, but because the habit of asking first is what's actually being protected.

**Session 7 shifted the split back toward Claude-implemented**, specifically for the 16-familiar content pass and the engine bugs it exposed — a deliberate, explicit handoff (see the `pixel_pugilists_balance_tuning_workflow` memory), not a quiet regression from the sessions-3–4 high point. The developer's contribution this session was concentrated in design direction and judgment calls rather than typing: choosing between fix options Claude framed (e.g. "check death before Regeneration's heal fires" vs. "leave revival unconditional and compensate elsewhere"), asking for the impact of a candidate engine change to be simulated before committing to it, and — independently, before Claude had finished diagnosing it — correctly suspecting that "gain Absorption on any status removed" could re-trigger itself when Absorption's own depletion is itself a removal event. That last one is worth naming specifically: it's the same reentrancy-cascade pattern Claude had to hunt down as real bugs three separate times in session 6 (see `DECISIONS.md`), recognized on sight this time by the developer instead. Claude's default for new content in this vein should stay review/wiring-support once a specific piece is developer-owned again; this session's shift was to the content pass as a whole, not a permanent reset of that norm.

## 3. Current curriculum milestone

**Pixel Pugilists' core thesis** (`GAME_DESIGN.md` §1, §12): prove that constructing a
build, defining simple autonomous priorities, and watching the familiar execute that
build is satisfying enough to justify the full game. Explicitly no movement/spatial
combat, no Ranch, no circuits, no campaign, no injury system.

Progress so far: the combat engine, real stats, a 24-status effect system, a
`PassiveEffect` system (Focus breakpoints, a real `FocusTable`, and the continuously-live
`ModifyStatPassiveEffect` category all included), composable multi-step techniques, a
combat log/explanation surface, a full behavioral-priority system driving *both* sides
(Steps 4–5), and now the real reward screen (Step 6, session 8 — weighted
Species/Build/Wildcard slots, not the placeholder flat-pool version originally shipped —
see §4) all exist. **The full 16-familiar roster is built and balance-tested** (session 7).
**The full non-bracket play loop is now confirmed working end-to-end** (developer-verified,
same session): launch, get randomly assigned a fighter, fight through the whole opponent
lineup with a reward-and-priority-editor step after each non-final win, reach a win/loss
screen, and Restart into a genuinely new run. Still missing before Milestone 1 is
complete: the actual bracket/draft structure (replacing the current random-matchup
stand-in), targeting, and a boss encounter — the priority editor is fully integrated now,
no longer on this list.

## 4. Ordered learning/development steps

### Steps 1–2 — Combat skeleton (stats, HP bars, turn sequencing, Attack/Defend) — ✅ Done
Built as one bootstrapped scaffold rather than two separate incremental exercises: Claude
implemented `Familiar`/`Combatant`/`BattleController`/`CombatLog`/`HPBar` and one example
`Familiar` resource; the developer's hands-on part was creating the enemy's `Familiar`
resource, assigning both resources in the Inspector, and wiring the Attack/Defend button
signals — all done correctly. This also resolved the old tutorial's stat-asymmetry bug by
construction (see `DECISIONS.md`), rather than needing a separate fix.

### Step 3 — Status effects (Poison, Burn, Acid) — ✅ Done
- **What happened:** Claude implemented `Status`/`PoisonStatus` as the representative
  example; the developer implemented `BurnStatus` (introducing a genuinely different
  mechanic — duration-based decay instead of stack-based, plus a self-designed "Flare"
  reapplication bonus) and `AcidStatus` (a still-different mechanic — a passive Defense
  modifier via a new `modify_defense()` hook, rather than tick damage) largely
  independently, with Claude reviewing and the developer fixing real bugs found in review
  (missing button-disable wiring, twice; a hardcoded combat-log source that broke once
  statuses started flowing both directions).
- **Beyond original scope:** upkeep became its own turn phase with its own pause (not just
  a silent tick), and `HPBar` gained a damage-preview overlay showing upcoming status
  damage.
- **Unlocks:** enough of a status system to make priority conditions ("if target is
  poisoned...") meaningful in Step 4.

### Techniques-as-data refactor — ✅ Done (happened ahead of Step 4)
Resolved the open sequencing question by doing this first. `Technique` (Resource)
replaced the four duplicated damage-formula call sites. First pass over-subclassed
(one class per status-applying move); the developer correctly identified this as
unearned abstraction and it was collapsed into one parameterized class. See
`DECISIONS.md` for the durable rule this produced.

### Step 4 — Minimal behavioral priority system — ✅ Done
- **What happened:** Claude built the evaluator (`Combatant.choose_technique()`) and one
  example condition (`TargetMissingStatusCondition`); the developer built
  `SelfHPBelowXCondition` and `TargetStatusStacksBelowXCondition` — both had real bugs
  (int-division truncation; a fallback branch that misread "has an unrelated status" as
  "has the checked status") caught in review and fixed by the developer. Skip reasons log
  per §6.4, gated behind a `show_priority_skip_log` toggle (off by default) so normal play
  isn't noisy.
- **Beyond original scope:** `PriorityRule.condition` (singular) became
  `conditions: Array[Condition]` (ANDed) at the developer's suggestion, with an empty
  array serving as the catch-all case instead of a dedicated "always true" resource.
- **Unlocks:** Step 5.

### Step 5 — Player-side priorities + retiring the manual harness — ✅ Done
- **What happened:** `enemy_turn()` and the click-driven player path unified into one
  `take_turn(actor, target, source)` — both sides now choose identically. The developer
  raised a real design concern before implementation: retiring manual control entirely,
  before any buildcrafting exists to replace it, would leave the prototype with nothing
  to actually do. Resolved with a small pre-fight `PriorityBuild` build-select screen
  (Claude built "Status Stacker"; developer built "Poison Spammer") rather than either
  reordering the whole roadmap or shipping a dead spectator-only build.
- **Developer's exercise, done:** authored "Poison Spammer" (Defend below 50% HP,
  otherwise always Venom Strike) — genuinely different from "Status Stacker" (rotate
  through missing statuses, then Attack), confirmed via direct evaluator tests. Also
  caught its own real bug while doing so: editing the *shared* `fallback_attack.tres` to
  fit one build silently changed Guubal's fallback too — see `DECISIONS.md`.
- **Definition of done, met:** a full fight plays out with zero manual clicks, driven
  entirely by authored priorities on both sides.

### Step 6 — Round loop + reward selection — ✅ Done
Multiple sequential fights play out with the real, tailored reward screen (session 8)
between them — weighted Species/Build/Wildcard slots via `RewardSelector`, shared reroll
charges, allocate-then-confirm stat upgrades, and the round-4 passive-trade sacrifice flow
— replacing the earlier flat-pool placeholder version. Confirms runtime build growth
(`Familiar.techniques`/stats growing in memory across fights within one session works
fine — no explicit per-run build object needed). This is not yet the bracket itself (§9)
— no draft, no opponent scaling, no scouting/odds — just the accumulation loop the
bracket will eventually sit on top of.

### Content pass — ✅ Done (16-familiar roster complete, session 7)
Bulk status/technique/passive authoring toward the full 16-familiar roster
(`GAME_DESIGN.md` §8.4/§8.5, tracked loosely in `CONTENT_IDEAS.md`): 24 statuses, a full
`PassiveEffect` system (species-bound passives, Focus breakpoints, and now a real
`FocusTable` with content), `Technique` built from composable `TechniqueStepGroup`/
`TechniqueAction` steps — all 16 familiars now exist, each with two techniques, priority
rules, and a passive, balance-tested against the full field (`DEVLOG.md` session 7). The
collaborative shape that finished this pass: the developer describes a kit's theme,
passive behavior, techniques, and priority rules in plain language; Claude picks the
concrete numbers/triggers/limiters and iterates against `scripts/tools/balance_test.gd`
until nothing is doomed (see the `pixel_pugilists_balance_tuning_workflow` memory) — a
different split of labor than sessions 3–6's "developer designs and implements, Claude
reviews," closer to the reverse for this specific category, though the developer still
reviews Claude's numeric choices and does real hands-on tuning themselves (several
sessions' worth of direct stat edits, plus independently spotting the Cleanse/`pick_random()`
non-determinism risk before it was fully diagnosed). Traits/augments, if still wanted, are
the one piece of the originally-scoped content pass not yet started.

### Step 7 — Tournament bracket structure — ✅ Done (session 9)
The single-elimination bracket described in `GAME_DESIGN.md` §9: 16 entrants,
character select doubling as the bracket screen, off-screen matches resolved
and scouted, and the round loop running off the bracket instead of the
`opponent_lineup` gauntlet. Spec'd first
(`docs/superpowers/specs/2026-09-06-tournament-bracket-design.md`), then built
from a written plan in 12 tasks — Claude-implemented per the ownership split
agreed at the start of the session, with the developer reviewing each phase and
making three design calls that changed the result: restructuring the pre-fight
flow, moving the "haven't edited priorities" confirmation onto the skip path,
and cutting the combat-log reveal lines entirely on the reasoning that a
visible bracket makes narration redundant.

§9.3's own open questions all resolved *against* the doc's original guess: it
had assumed real simulation of off-screen matches would be too expensive, but
at ~11 matches per run and ~7.5ms each it's cheaper than maintaining a second
combat model — so the real engine runs, and its HP margin becomes odds that get
*rolled* rather than a verdict. See `DECISIONS.md`.

**New here, worth noticing:** this is the first feature in the project with a
committed, re-runnable test harness (`scripts/tools/bracket_test.gd`) rather
than throwaway `_verify_*.gd` scripts — closing the gap session 5 flagged and
never acted on. Its per-check completion markers exist because a GDScript
runtime error aborts only its own function; that mechanism caught real crashes
twice during the build instead of reporting false passes. Worth reading as the
model for how future systems get covered.

### Step 8 — Final showdown + build-comparison pass (higher-level)
The bracket's final match, opponents having accumulated a comparable amount of power to
the player over the run, plus a deliberate comparison of two different drafted builds
against it — directly testing the core thesis (`GAME_DESIGN.md` §1/§12) as a whole.
Developer-led by this point, Claude reviewing.

### Step 9 — AI drafting personalities & priority optimizer (not yet started; has a concrete integration point now)
Swaps in at exactly one place: `AIDrafter.apply_round_reward()`
(`scripts/bracket/ai_drafter.gd`), the deliberately naive placeholder the
bracket ships with — a stat-fraction rule plus an auto-picked Run-slot reward,
build-unaware by design. Nothing bracket-side needs to change when the real
system replaces it.

Full design in `docs/superpowers/specs/2026-09-06-ai-drafting-design.md` and
`GAME_DESIGN.md` §11. Deliberately sequenced *after* the bracket ships (Steps
7–8) rather than blocking it — the bracket's own AI-progression step starts
with a simple placeholder rule and swaps this in later with no bracket-side
changes required. Two motivations, one system: bracket AI opponents that feel
like different fighters (Greedy/Synergy Master/Random to start), and — the
more valuable half — a real answer to `scripts/tools/balance_test.gd` only
ever testing a familiar's default kit, never the range of builds it can
actually become. Developer's own design; Claude formalized it into the spec
and caught two real gaps during self-review (an AI stat-upgrade rule that
would've silently ignored Max HP due to differing stat scales; a "role
coverage" vs. "role bias" conflation that would've made Greedy behave like a
gap-filler instead of an offense-stacker) — worth reviewing both fixes
against what was actually intended before implementation starts.

## 5. Open design experiments

For each, the smallest reversible experiment — none of these get a permanent answer yet:

- **Combat timing (§5, §5.1):** No longer fixed alternation — Speed now drives turn order
  dynamically, re-decided every exchange (`DECISIONS.md`), which can hand one side two
  turns in a row on a mid-fight Speed swing. Still an experiment per §5's OPEN/PLAYTEST
  status, not declared canon; watch whether this reads as intended once fights have more
  varied Speed values to actually swing on.
- **Universal stat line size (§5.2):** Both stats now have a job — Speed drives turn
  order, Focus gates passive breakpoints (`FocusBreakpointCondition`) — closing the
  previous open question of whether either would stay unused.
- **Status/combo pacing (§11.3):** Genuinely testable now with 24 statuses across 4
  familiars. Worth a real observation pass once more familiars exist and fights aren't
  all still against the same one or two opponents: does a 2-status interaction feel like
  it needs more setup, or does even one feel fiddly?

## 6. Deferred systems

Explicitly not being built yet, to avoid scope creep:

- Movement, grids, arenas, forced movement, spatial statuses (Milestone 2+; explicitly
  excluded from Milestone 1 by `GAME_DESIGN.md` §17.2 and §19.3).
- Ranch, mentorship, lineage/breeding.
- Circuits, campaign narrative, corrupt-organization arc.
- Reputation-as-career-HP, career loss severity, Legacy Points.
- Postgame challenge-modifier system, medals/objectives beyond maybe a stub later.
- Save/persistence — not needed until a session needs to survive being closed.
- Any generalization still waiting on a second concrete case — see `DECISIONS.md` for
  the ones already discussed and deliberately deferred.
- Coaching/intervention system (§7) — priorities and a round loop both now exist (Steps
  4–6 done), but this is still Milestone-1-out-of-scope until the bracket (§9) gives
  coaching something structural to happen *between*.

## 7. Next lesson

The round loop (Step 6), Stasis's cross-cutting stack-loss interception, the
`PassiveEffect` system, the 16-familiar content pass, the real reward screen, and the
priority editor's integration (including its mock-state panel becoming a real playback
simulator) are all done — see `DEVLOG.md` sessions 6–8. Sessions 7 and 8 were both
overwhelmingly Claude-implemented for the actual GDScript — five new familiars and four
engine bugs in session 7; the reward system, a tooltip debugging arc, five rounds of
drag-and-drop fixes, a real engine bug (Stasis/passive-notification), and a balance/export/
Game-Over pass in session 8 — with the developer's hands-on contribution concentrated in
design direction, live playtesting/bug reports, sharp mid-debugging corrections (twice
this session, catching a premature conclusion from a real counter-observation rather than
just accepting it), and reviewing Claude's proposed fixes, rather than typing GDScript
directly. This is now true across an extended stretch, not just two sessions — the north
star in `CLAUDE.md` still points toward the developer implementing ordinary features
independently, and this is worth a real check-in (not another silent extension) before
starting the bracket, which is a large enough system that *how* it gets built matters as
much as what gets built.

**Immediate next step, per explicit developer direction ("bracket next")**: the tournament
bracket (§9/Step 7, `GAME_DESIGN.md`). Read §9's own open questions (off-screen simulation
odds/fidelity/cost) before implementing anything — this is the least-settled part of the
design doc and a good candidate for the developer to drive more of the actual
implementation on, given the check-in note above. The current random-matchup gauntlet
(`full_roster` in `battle_controller.gd`) is a deliberate, throwaway stand-in for the
bracket's real character-select/draft — expect it to be replaced outright, not extended.
The Game Over/Restart flow and matchup randomization are now developer-verified
end-to-end — the full non-bracket play loop genuinely works start to finish (§3). One
known loose end before the bracket: Pebbloq needs an actual rebalance now that its
Ancient Sentinel passive works (`DEVLOG.md`). Also re-export `build/FamiliarRPG0.exe`
before any external playtest — the file on disk predates this session's fixes. The
visual style pass and traits/augments remain open, lower-priority, and can slot in
whenever.
