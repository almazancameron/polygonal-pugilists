# Development Log

## 2026-08-29 — Milestone 1 bootstrap + status effects (Poison, Burn, Acid)

Bootstrapped Polygonal Pugilists from an empty Godot 4.7 project into a playable 1v1 combat prototype, then built out the status-effect system.

**Combat skeleton**: `Familiar` (Resource) holds a familiar's build (stats, sprite) identically for player and enemy — no autoload, no asymmetry between sides. `Combatant` (RefCounted) wraps a `Familiar` with per-battle runtime state (current_hp, is_defending, statuses). `BattleController` drives a `Phase` enum state machine (PLAYER_TURN / ENEMY_UPKEEP / ENEMY_TURN / PLAYER_UPKEEP / BATTLE_OVER), resolves Attack/Defend, and ends the battle on victory/defeat. `CombatLog`/`CombatLogView` and `HPBar` are small, decoupled, reusable UI pieces.

**HP bar gained a damage-preview overlay**: `HPBar`'s root was restructured from a bare `ProgressBar` into a composite `Control` (`Bar` + `StatusPreview` + `Label`), so it can draw colored segments showing how much damage each active status will deal on its next tick, sized/positioned in pixels computed from the bar's current value.

**Status effects**: `Status` (RefCounted) base class, with `PoisonStatus` (stacking DoT, damage = stacks, decays by 1/tick), `BurnStatus` (fixed damage/tick, duration-based, "Flare" bonus damage + duration reset on reapplication), `AcidStatus` (stacking Defense reduction, 10%/stack up to 5 stacks, infinite duration). Upkeep became its own turn phase with its own pause, played only when the acting side actually has active statuses.

**Bugs found and fixed this session**:
- `check_victory()` never returned `true` — both branches fell through to the unconditional `return false`, since `get_tree().quit()` only requests a quit at end-of-frame rather than halting execution. Caused duplicate victory/defeat log lines and a doubled quit delay.
- A plain Attack didn't refresh the HP bar's status preview (only status-applying moves did), leaving the preview segment visually stuck at the old fill position. Fixed by consolidating every HP-changing call site through one `update_hp_display()` function.
- Two new-button omissions (Burn, then Acid): the button was wired to a handler but never added to `set_action_buttons_enabled()`, leaving it clickable during the enemy's turn.
- `apply_status()`'s combat-log source was hardcoded to PLAYER, which broke once the enemy started applying statuses to the player too (Guubal's acid attack) — fixed to key off which side is receiving the status.

**Enemy behavior**: Guubal's `enemy_turn()` now always uses an acid-based attack instead of a plain Attack — deliberately still zero decision-making (a single hardcoded action, not a coin-flip or priority list), to avoid quietly building Step 4's behavioral-priority system ahead of schedule.

### Where to continue

- **Status icon row (not yet built) — do this before it's forgotten.** Acid has no HP-bar damage-preview segment (it doesn't deal tick damage), so it's currently invisible once applied beyond the initial log line. Designed but not implemented: a small separate component (e.g. `StatusIconRow`, an `HBoxContainer` + script) living as a *sibling* of `HPBar` in `PlayerPanel`/`EnemyPanel` — not nested inside `HPBar` itself, since cramming an unbounded number of non-damaging status indicators onto the HP bar's already-one-job widget doesn't scale. One method, `set_status_icons(entries: Array[Dictionary])`, each entry roughly `{color, stacks}`, rendered with the same "clear children, spawn a `ColorRect` + `Label` per entry" approach already proven in `HPBar`'s preview segments and `CombatLogView`. Show *every* active status uniformly (Poison/Burn get an icon too, not just Acid) rather than special-casing "only non-damaging statuses" — simpler rule, and the icon answers a different question ("what's active, how many stacks") than the bar segment does ("how much will this hurt next"). Wire it into the existing `update_hp_display()` single-point-of-truth rather than a new parallel call site. Do **not** special-case `is_defending` into this — Defend is slated to become a real Status soon (see `DECISIONS.md`), at which point it shows up in the same generic `combatant.statuses` loop for free.
- **Sequencing decision, still open**: tackle the techniques-as-data refactor (see `DECISIONS.md`) before starting Step 4's behavioral-priority system, or build Step 4 against the current hardcoded moves first and refactor after. Not yet decided.
