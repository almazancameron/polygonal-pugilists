# Familiar Fight Club — Learning Roadmap

Living curriculum tying real FFC development to the developer's growing Godot/GDScript
fluency. Update this file whenever a concept's status changes, a step is completed, or
the architecture shifts — see `.claude/CLAUDE.md` for the teaching workflow this file
supports.

Developer's stated priority order: **#1 learn the engine, #2 build FFC, #3 have fun.**
Pacing favors depth over speed — slow down, ask for explanations back, and spend extra
exercises on shaky concepts rather than rushing toward a milestone.

## 1. Current project snapshot

Godot 4.7 (Forward Plus, Jolt Physics, d3d12 on Windows), `project.godot` already correctly
named "Polygonal Pugilists." The project was bootstrapped from scratch — no code carried
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
- **`CombatLog`** / `CombatLogView`, **`HPBar`** — small, decoupled, reusable UI pieces.
  `HPBar` is a composite `Control` (`Bar` + `StatusPreview` + `Label`) that also draws a
  colored preview of the damage each active status will deal on its next tick.

**Current playable state:** a full 1v1 fight plays out correctly — every player action
works, Guubal automatically uses an acid attack every turn (still zero decision-making,
deliberately — see §4 Step 4 below), HP bars and status previews update live, and victory
and defeat both end the battle correctly. This has been verified with headless Godot
scripting (see `CLAUDE.md`'s Validation section), not only by manual play.

**What's conspicuously absent relative to Milestone 1:** no behavioral-priority system yet
(the enemy unconditionally executes one hardcoded action), no targeting (only one possible
opponent exists), no round/shop loop, no rematch/rebuild flow, no save data, no permanent
automated test suite (a reliable throwaway headless-verification pattern exists and has
been used constantly, but always written by Claude and deleted after use — see §7). This
is expected at this point in the roadmap, not a gap in what's been done.

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

## 3. Current curriculum milestone

**Milestone 1 — Polygonal Pugilists** (`GAME_DESIGN.md` §17.2): prove that constructing a
build, defining simple autonomous priorities, and watching the familiar execute that
build is satisfying enough to justify the full game. Explicitly no movement/spatial
combat, no Ranch, no circuits, no campaign, no injury system.

Progress so far: the combat engine, real stats, a small status/event system (Poison/Burn/
Acid), and a combat log/explanation surface all exist. Still missing before Milestone 1 is
complete: behavioral priorities, targeting, the round/shop loop, rematch/rebuild flow, and
a boss encounter.

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

### Before Step 4 — an open sequencing question, not yet decided
Four action handlers (Poison Strike, Searing Spit, Acid Bath, and Guubal's acid attack)
currently duplicate the same damage formula. Moving techniques to a `Technique` Resource
(subclassed per move, the way `Status` already is) would remove that duplication and
matches where `GAME_DESIGN.md` §9/§10 already points — but it's real, separate work from
Step 4 below. Whether to do that refactor before or after Step 4 hasn't been decided; see
`DECISIONS.md` and `DEVLOG.md`'s "Where to continue."

### Step 4 — Minimal behavioral priority system
- **FFC feature/result:** An ordered list of condition→action rules that the *enemy*
  evaluates each turn to autonomously pick among its available moves, replacing the
  current hardcoded single action. Skip reasons get logged per §6.4 ("explanation tooling
  ... should prioritize this visibility early").
- **Concepts introduced/practiced:** the smallest usable rule vocabulary (condition +
  action, no movement/targeting complexity yet, per §6.2's direction to start minimal),
  iterating an ordered list and explaining why an option was or wasn't chosen.
- **Already decided:** this must be a real ordered-priority system, not randomness — a
  50/50 coin-flip between moves was explicitly considered and rejected this session for
  being a different, likely-throwaway mechanism (see `DECISIONS.md`).
- **Who implements the first example:** Claude (the evaluator + one example condition).
- **Developer's exercise:** add a second, related condition.
- **Definition of done:** the enemy chooses among more than one move without manual
  clicks, and every choice (and every skip) has a visible, correct reason in the log.
- **Unlocks:** this is the point where the manual button harness starts being retired, per
  Step 5.

### Step 5 — Player-side priorities + retiring the manual harness
- **FFC feature/result:** The player's familiar also acts via the same priority
  evaluator; Attack/Defend/status buttons are removed (their job is done — they proved the
  resolution engine).
- **Concepts introduced/practiced:** reuse of Step 4's evaluator across both sides;
  minimal "build configuration" UI to let the developer *set* priorities rather than
  hardcode them.
- **Who implements the first example:** Claude sets up the shared evaluator path; **the
  developer** authors the player's rule list contents.
- **Developer's exercise:** author two meaningfully different player rule sets and observe
  how differently the same techniques play out — an early check against Milestone 1's
  success criterion #1 ("two meaningfully different successful builds").
- **Definition of done:** a full fight can play out with zero manual clicks, driven
  entirely by authored priorities on both sides.

### Step 6 — Round loop + simple shop/reward (higher-level, less detailed)
Rounds 1–5 with a minimal reward/shop step between them and an immediate rematch/rebuild
flow (both explicitly required by Milestone 1). First real place persistence-during-a-
session likely matters.

### Step 7 — Boss/final encounter + build-comparison pass (higher-level)
A stronger final opponent and a deliberate comparison of two different builds against it,
directly testing Milestone 1's success criteria as a whole. Developer-led by this point,
Claude reviewing.

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
- A generic `modify_stat()` hook, a status icon row's special-case for "Defending," and
  any other generalization waiting on a second concrete case — see `DECISIONS.md` for the
  specific ones already discussed and deliberately deferred.
- Coaching/intervention system (§7) — depends on priorities existing first (Step 4/5).

## 7. Next lesson

Two things worth deciding before writing more code, both already surfaced in
`DEVLOG.md`'s "Where to continue" and `DECISIONS.md`:

1. **Sequencing:** techniques-as-data refactor first, or Step 4's behavioral-priority
   system first? Not yet decided — see "Before Step 4" above.
2. **A concrete, designed-but-unbuilt piece regardless of that decision:** a status icon
   row (separate from `HPBar`, showing every active status's presence + stack count,
   since Acid currently has no visual indicator at all beyond its one application log
   line). Full design already written down in `DEVLOG.md` — implementing it doesn't
   depend on the sequencing decision above and could happen first if it's a better next
   rep for the developer.

Whichever comes first, the pattern stays the same: Claude designs/reviews, developer
implements, following the ownership progression `CLAUDE.md` describes — the developer has
now driven the last two statuses (Burn, Acid) close to independently, which is the right
direction.
