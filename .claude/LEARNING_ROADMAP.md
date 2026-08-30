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
- **`Status`** (`status.gd`, `RefCounted`) base class, with `PoisonStatus`, `BurnStatus`,
  and `AcidStatus` subclasses. See `DECISIONS.md` and `LEARNING.md` for the mechanics and
  the polymorphism/hook-ordering lessons this produced.
- **`Technique`** (`technique.gd`, `Resource`) — a familiar's authored combat action.
  Status-applying moves are one class parameterized by `status_effect`/`status_stacks`,
  not one subclass per move; `DefendTechnique` is a real subclass since its `execute()`
  genuinely differs. `Familiar.techniques: Array[Technique]` holds each familiar's
  moveset. See `DECISIONS.md`.
- **`Condition`** (`condition.gd`, `Resource`) — one subclass per condition kind
  (`TargetMissingStatusCondition`, `SelfHPBelowXCondition`,
  `TargetStatusStacksBelowXCondition`), since these read genuinely different battle-state
  facts, unlike `Technique`'s parameterized cases. `PriorityRule` pairs an ANDed
  `conditions: Array[Condition]` with a `technique`; `Familiar.priority_rules` is an
  ordered list of these, evaluated by `Combatant.choose_technique()`.
- **`PriorityBuild`** (`priority_build.gd`, `Resource`) — a named, authored
  `priority_rules` set the player can pick between on a small pre-fight build-select
  screen. Deliberately the smallest possible slice of buildcrafting, not the eventual
  round/reward loop — see `DECISIONS.md`.
- **`CombatLog`** / `CombatLogView`, **`HPBar`**, **`StatusRow`** — small, decoupled,
  reusable UI pieces. `HPBar` draws a colored preview of upcoming status damage;
  `StatusRow` shows every active status uniformly (including non-damaging ones like Acid).

**Current playable state:** the player picks a `PriorityBuild` on a small pre-fight
screen, then a full 1v1 fight plays out with **zero manual clicks on either side** — both
`Combatant`s choose their technique each turn via the same `choose_technique()` evaluator,
via `battle_controller.gd`'s unified `take_turn()`. HP bars, status previews, and the
status icon row all update live; victory and defeat both end the battle correctly. This
has been verified with headless Godot scripting (see `CLAUDE.md`'s Validation section),
not only by manual play. Playtest note: with only two premade builds and five techniques,
watching a fight feels thin right now — expected, since the real buildcrafting layer
(Step 6) doesn't exist yet; see `DEVLOG.md`.

**What's conspicuously absent relative to Milestone 1:** no round/shop loop, no
rematch/rebuild flow, no persistent build accumulation across fights, no targeting (only
one possible opponent exists), no boss encounter, no save data, no permanent automated
test suite (a reliable throwaway headless-verification pattern exists and has been used
constantly, but always written by Claude and deleted after use — see §7).

## 2. Demonstrated knowledge

| Concept | Status | Evidence |
|---|---|---|
| Scene composition (Control/VBox/HBox, anchors, Containers) | Practicing | Restructured `HPBar`'s root from a bare `ProgressBar` into a composite `Control` via "Reparent to New Node"/"Save Branch as Scene"; still needed guidance on *why* `custom_minimum_size` and "Full Rect" anchors must be set at every level of a hierarchy, not just the top, so not yet independent here |
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
| Automated tests | Not introduced | The headless-script verification pattern (see `CLAUDE.md`) has been used constantly this session, but always written by Claude — writing one independently would be a good future exercise |
| Data vs. subclass judgment (parameterize vs. subtype) | Demonstrated | Correctly challenged Claude's own over-subclassed first pass at `Technique` (one subclass per status-applying move) as unearned, since the cases were parametrically identical rather than behaviorally different — led directly to the enum+fields redesign now in `DECISIONS.md` |
| Typed `Array[CustomResourceClass]` exports | Demonstrated | `Array[Technique]`, `Array[PriorityRule]`, `Array[Condition]` authored and edited correctly and independently via the Inspector across many resource files this session, including nested/embedded sub-resource arrays |
| Godot resource save/dirty-tracking mechanics | Introduced | Diagnosed (with Claude, via live MCP introspection) why a deeply-nested resource edit made through a scene's Inspector didn't persist to the underlying `.tres` file — a real, reusable debugging lesson, not yet independently applied |

**Also worth noting — design ownership, not a checklist item**: this session the developer initiated two substantive pushbacks on Claude's own proposed designs (the `Technique` over-subclassing above, and a sequencing challenge to Step 5 that led to inserting the pre-fight build-select screen — see `DECISIONS.md`) rather than just implementing assigned exercises. That's ahead of where `CLAUDE.md`'s ownership progression expected at this point in the roadmap; worth continuing to invite real critique of proposed designs, not just review-after-implementation.

## 3. Current curriculum milestone

**Pixel Pugilists' core thesis** (`GAME_DESIGN.md` §1, §12): prove that constructing a
build, defining simple autonomous priorities, and watching the familiar execute that
build is satisfying enough to justify the full game. Explicitly no movement/spatial
combat, no Ranch, no circuits, no campaign, no injury system.

Progress so far: the combat engine, real stats, a small status/event system (Poison/Burn/
Acid), a combat log/explanation surface, and a full behavioral-priority system driving
*both* sides (Steps 4–5) all exist — a fight plays out entirely autonomously once the
player picks a pre-fight build. Still missing before Milestone 1 is complete: the
round/shop loop, rematch/rebuild flow, persistent build accumulation across a run,
targeting, and a boss encounter.

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

### Step 6 — Tournament bracket structure (higher-level, less detailed)
Superseded/sharpened by a design conversation after Step 5: this is no longer "rounds 1–5
with a shop layer" but the single-elimination bracket described in `GAME_DESIGN.md` §9 —
a 16-or-32-entrant bracket doubling as character select, simulated off-screen matches
(stat comparison → odds → roll, with scouting), and upgrade choices between rounds
replacing the current pre-fight `PriorityBuild` picker. First real place
persistence-during-a-run likely matters (does `Familiar.techniques`/`priority_rules`
growing at runtime suffice, or does an explicit per-run build object make more sense?).
See `GAME_DESIGN.md` §9's open questions before implementing.

### Step 7 — Final showdown + build-comparison pass (higher-level)
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
- A generic `modify_stat()` hook, and any other generalization waiting on a second
  concrete case — see `DECISIONS.md` for the specific ones already discussed and
  deliberately deferred.
- Coaching/intervention system (§7) — priorities now exist (Steps 4–5 done), but this is
  still Milestone-1-out-of-scope until the round loop (Step 6) gives coaching something
  to happen *between*.

## 7. Next lesson

Step 6 — the round loop + simple shop/reward layer (see §4 above) — is the clear next
step: it's Milestone 1's biggest remaining gap, and it's what turns the pre-fight
build-select screen from "pick between two fixed builds" into real, accumulating
buildcrafting. Worth a design conversation before implementing (per the developer's own
recent instinct about sequencing) covering at minimum: how many rounds, what a
reward/shop offer actually looks like for a five-technique/three-condition roster this
small, and whether `Familiar.techniques`/`priority_rules` growing at runtime (works today,
since resources persist in memory across scene reloads within a session) is sufficient or
whether an explicit per-run build object is worth introducing.

Given the developer's demonstrated architecture judgment this session (see §2's note on
design ownership), Step 6 is a good candidate to push further along the ownership curve:
Claude proposing/reviewing the round-loop shape, developer driving more of the actual
implementation than in Steps 4–5.
