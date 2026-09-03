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
- **`Status`** (`scripts/status/status.gd`, `RefCounted`) base class — now 19 concrete
  subclasses covering damage-over-time, stat buffs/debuffs (`modify_stat()`, generalized
  from an Acid-only `modify_defense()` once Fortify/Hone/Enlarge needed it too),
  interception (Ward, Absorption — see `DECISIONS.md`), and retaliation (Thorns,
  Retaliation). See `DECISIONS.md` and `LEARNING.md` for the mechanics and hook-ordering
  lessons this produced.
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
  reward choice, subclassed (`AddTechniqueUpgrade`, `ModifyStatUpgrade`) since each kind
  changes a familiar's build differently.
- **`PriorityBuild`** (`priority_build.gd`, `Resource`) — a named, authored
  `priority_rules` set the player picks between at the start of a run. Now feeds into a
  round loop rather than being a one-and-done pick — see `DECISIONS.md`.
- **`CombatLog`** / `CombatLogView`, **`HPBar`**, **`StatusRow`** — small, decoupled,
  reusable UI pieces. `HPBar` draws a colored preview of upcoming status damage;
  `StatusRow` shows every active status uniformly (including non-damaging ones like Acid).

**Current playable state:** the player picks a `PriorityBuild`, then plays through
multiple rounds of autonomous 1v1 fights — **zero manual clicks on either side** during a
fight, both `Combatant`s choosing via the same `choose_technique()` evaluator through
`battle_controller.gd`'s unified `take_turn()` — with an `UpgradeOption` reward pick
between rounds that actually grows the build. HP bars, status previews, and the status
icon row all update live and pace one step at a time now (each hit/heal/status
application its own log line, not a batched turn summary). Verified with headless Godot
scripting (see `CLAUDE.md`'s Validation section), not only by manual play. Playtest note
from before the round loop existed: with only two premade builds and five techniques,
watching a fight felt thin — expected, since the real buildcrafting layer
(Step 6) doesn't exist yet; see `DEVLOG.md`.

**What's conspicuously absent relative to Milestone 1:** no round/shop loop, no
rematch/rebuild flow, no persistent build accumulation across fights, no targeting (only
one possible opponent exists), no boss encounter, no save data, no permanent automated
test suite (a reliable throwaway headless-verification pattern exists and has been used
constantly, but always written by Claude and deleted after use — see §7).

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

**Design ownership — a milestone, not a checklist item**: session 2 recorded the developer's first substantive pushbacks on Claude's proposed designs (the `Technique` over-subclassing, and the Step-5 sequencing challenge). Sessions 3–4 went well beyond pushback: essentially the entire technique-rework-plus-eleven-statuses content wave was designed and typed by the developer, with Claude in a pure review/support role (enum wiring, resource migrations, bug fixes only when explicitly requested). That's the "developer designs and implements — Claude acts mainly as reviewer/debugging partner" end state `CLAUDE.md`'s north star describes, reached far earlier than the roadmap's original pacing expected. The one caution from this stretch: Claude implemented one full bug fix (the Ruin/Absorption damage-log bug) from a casual "let's fix X" without re-confirming first, a repeat of an already-flagged pattern — worth the developer continuing to watch for, not because the fix was wrong, but because the habit of asking first is what's actually being protected. Going forward, Claude's role for new content in this vein should default to review/wiring-support unless the developer specifically asks for an implementation.

## 3. Current curriculum milestone

**Pixel Pugilists' core thesis** (`GAME_DESIGN.md` §1, §12): prove that constructing a
build, defining simple autonomous priorities, and watching the familiar execute that
build is satisfying enough to justify the full game. Explicitly no movement/spatial
combat, no Ranch, no circuits, no campaign, no injury system.

Progress so far: the combat engine, real stats, a 19-status effect system, composable
multi-step techniques, a combat log/explanation surface, a full behavioral-priority
system driving *both* sides (Steps 4–5), and a round loop with post-fight reward
selection (Step 6, in a lighter form than originally planned — see §4) all exist. A
content pass toward the full 16-familiar roster is now underway. Still missing before
Milestone 1 is complete: the actual bracket/draft structure, an in-run priority-rule
editor, targeting, and a boss encounter.

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

### Step 6 — Round loop + reward selection — ✅ Done (lighter than originally planned)
Multiple sequential fights now play out with an `UpgradeOption` reward pick (via
`AddTechniqueUpgrade`/`ModifyStatUpgrade`) between them, proving out
runtime build growth (`Familiar.techniques`/stats growing in memory across fights within
one session works fine — no explicit per-run build object needed yet). This is not yet
the bracket itself (§9) — no draft, no opponent scaling, no scouting/odds — just the
accumulation loop the bracket will eventually sit on top of.

### Content pass (current, not originally in this roadmap) — developer-led, Claude reviewing
Bulk status/technique/passive authoring toward the full 16-familiar roster
(`GAME_DESIGN.md` §8.4/§8.5, tracked loosely in `CONTENT_IDEAS.md`): 19 statuses now
exist, `Technique` reworked into composable `TechniqueStepGroup`/`TechniqueAction` steps
with situational `NumericBonus`es, and `scripts/` reorganized into per-category
subfolders. Unlike every earlier step in this roadmap, the developer designed and wrote
nearly all of this independently — see §2's "Design ownership" note and `DEVLOG.md`'s
latest entry for the full attribution. None of the newest statuses are wired into a real
`.tres` technique/build yet — verified individually via throwaway scripts only.

### Step 7 (renumbered from the bracket) — Tournament bracket structure (higher-level, less detailed)
The single-elimination bracket described in `GAME_DESIGN.md` §9 — a 16-or-32-entrant
bracket doubling as character select, simulated off-screen matches (stat comparison →
odds → roll, with scouting), and upgrade choices between rounds replacing the current
pre-fight `PriorityBuild` picker/reward loop. See `GAME_DESIGN.md` §9's open questions
before implementing.

### Step 8 — Final showdown + build-comparison pass (higher-level)
The bracket's final match, opponents having accumulated a comparable amount of power to
the player over the run, plus a deliberate comparison of two different drafted builds
against it — directly testing the core thesis (`GAME_DESIGN.md` §1/§12) as a whole.
Developer-led by this point, Claude reviewing.

## 5. Open design experiments

For each, the smallest reversible experiment — none of these get a permanent answer yet:

- **Combat timing (§5, §5.1):** Currently sequential/fixed alternation — `BattleController`'s
  `Phase` enum lets the player fully resolve, then the enemy fully resolves, repeat. One
  candidate among several, being observed rather than declared canon.
- **Universal stat line size (§5.2):** `Familiar` currently exposes max_hp/power/defense/
  speed/focus. Speed and Focus are both defined but functionally unused by any system —
  don't give either a job until a specific mechanic needs one.
- **Status/combo pacing (§18.3):** Now genuinely testable with three statuses in place.
  Worth observing once Step 4/5 exist and statuses can interact without direct player
  clicking: does a 2-status interaction feel like it needs more setup, or does even one
  feel fiddly? Record the observation here rather than immediately tuning numbers.

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
  the ones already discussed and deliberately deferred (e.g. Persistence/Stasis's
  cross-cutting stack-loss interception, not yet designed).
- Coaching/intervention system (§7) — priorities and a round loop both now exist (Steps
  4–6 done), but this is still Milestone-1-out-of-scope until the bracket (§9) gives
  coaching something structural to happen *between*.

## 7. Next lesson

The round loop (Step 6) shipped; the content pass toward the full 16-familiar roster is
now underway (19 statuses, composable technique steps, damage bonuses — see `DEVLOG.md`'s
latest entry). **Developer-requested next item: a Stasis status** (renamed mid-session from the
brainstormed "Persistence" — see `CONTENT_IDEAS.md`). Design not yet started: it needs to
intercept stack decrements across *every* existing status, which likely means a
`Status.owner: Combatant` back-reference plus a custom
`stacks` property setter (a `var stacks: int: set(value): ...`, a pattern not yet used
anywhere in this codebase) rather than an additive per-status change. Good candidate for
a real design conversation before implementation, given it's cross-cutting rather than
another independent `Status` subclass.

After Stasis: keep filling out the content pass (more familiars/techniques/traits per
`GAME_DESIGN.md` §8.4/§8.5's Species/entrant-skeleton shape), then wire at least one real
`.tres` per new status so each gets exercised through an actual fight rather than only a
throwaway verification script.
