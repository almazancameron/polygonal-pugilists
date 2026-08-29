# Architectural & Design Decisions

Durable decisions future work should respect. Not a changelog — update or remove entries that get superseded rather than layering new ones on top.

## Familiar/Combatant model is symmetric between player and enemy
`Familiar` (Resource, static build data) and `Combatant` (RefCounted, per-battle runtime state) are the same classes for both sides, with no player-specific autoload. This was a deliberate fix for a bug in the reference tutorial project, where player stats lived in a global singleton and enemy stats lived on a Resource — asymmetric, and neither wrote HP changes back to its source. Any new per-combatant state should go on `Combatant`, never on a side-specific global.

## No autoloads yet
Nothing currently needs to survive a scene change (single scene, no menu/reward loop this milestone). Introduce an autoload only when a real cross-scene need appears (e.g. the eventual round/shop loop), not preemptively.

## Turn timing is fixed alternation, not Speed-based
`GAME_DESIGN.md` §5 leaves combat timing an open playtest question. Fixed alternation (player always acts first) was chosen as the simplest baseline to validate the turn state machine against; Speed exists as a stat but is currently unused. This is an experiment, not a locked answer — revisit if playtesting says otherwise.

## Status upkeep ticks at the start of the afflicted combatant's own turn
Not at the end of the turn that applied the status. This is an undocumented-by-design-doc call, chosen for being the more common convention and for keeping the tick next to the "is this side now allowed to act" decision. Upkeep is its own `Phase` (`ENEMY_UPKEEP`/`PLAYER_UPKEEP`) with its own pause, but that pause only plays when the side actually has active statuses — an ordinary Attack/Defend turn stays fast.

## Enemy behavior stays fully hardcoded until the real priority system exists
Guubal's `enemy_turn()` always uses the same one action (currently an acid attack). A 50/50 random choice between two moves was explicitly considered and rejected — it would have been a different decision-making mechanism than the ordered-priority system `GAME_DESIGN.md` §6.1 actually wants, and likely throwaway work once Step 4 (behavioral priorities) is built for real.

## `Status.modify_defense()` stays narrow, not generalized to `modify_stat()`
Only one concrete stat-modifying status exists (Acid, reducing Defense). Generalizing to a stat-name-keyed method now would mean guessing at a shape (string-keyed stat lookup, a guard clause every override would need) before a second real case (e.g. a Power- or Speed-reducing status) exists to validate it against.

## "Defending" stays a plain bool, not a Status — for now
`Combatant.is_defending` doesn't fit `Status`'s shape: it's a one-shot flag consumed by the next incoming hit, not something that decays over turns. This is expected to change soon — Defend is planned to become a real duration-based Status giving a temporary Defense buff, at which point it would naturally reuse the `modify_defense()` hook Acid already proved out, and `is_defending` would disappear from `Combatant` entirely.

## Techniques-as-data refactor is deliberately deferred
Four button handlers (`_on_poison_button_pressed`, `_on_burn_button_pressed`, `_on_acid_button_pressed`, and `enemy_turn()`'s acid attack) currently duplicate the same damage formula. Moving techniques to a `Technique` Resource (subclassed per move, the way `Status` already is) is the planned fix, but treated as its own dedicated design conversation rather than folded into whatever feature happens to be in flight — not started yet. Player-side move buttons are also understood to be a temporary manual test harness (`LEARNING_ROADMAP.md` Step 5 plans to retire it once the player also gets priorities), so a fully dynamic N-button UI-generation system is explicitly not being pursued now.
