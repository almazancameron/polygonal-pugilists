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

## `Status.modify_defense()` stays narrow, not generalized to `modify_stat()`
Only one concrete stat-modifying status exists (Acid, reducing Defense). Generalizing to a stat-name-keyed method now would mean guessing at a shape (string-keyed stat lookup, a guard clause every override would need) before a second real case (e.g. a Power- or Speed-reducing status) exists to validate it against.

## "Defending" is now a Status, not a plain bool
`Combatant.is_defending` used to be a one-shot bool, on the reasoning that it didn't fit `Status`'s shape (consumed by the next incoming hit, not decaying over turns). Once `Status` grew an `on_hit()` hook (added for Bleed) and an `on_applied()` hook (added for Stagger), that reasoning stopped applying: `DefendingStatus` now reuses `modify_defense()` (the same hook `AcidStatus` proved out) to double defense, and `on_hit()` to consume itself the next time its owner is hit. `is_defending` is gone from `Combatant` entirely; `DefendTechnique` applies `DefendingStatus` through the normal `add_status()` path like everything else.

## Techniques are data, not one subclass per move
`Technique` (`Resource`) replaced the old duplicated-damage-formula button handlers. Status-applying techniques (Venom Strike, Searing Spit, Acid Bath) are a single `Technique` class parameterized by `status_effect` (enum) + `status_stacks` fields, *not* one subclass each — they're the same formula with different constants, and an early pass that gave each its own subclass was corrected. `DefendTechnique` is a real subclass, since its `execute()` genuinely replaces the damage-then-status shape rather than parameterizing it. `Familiar.techniques: Array[Technique]` holds each familiar's authored moveset (Resource, not RefCounted like `Status`, specifically so it can be authored in the Inspector and later drawn from procedurally-generated pools — see `LEARNING.md`). Rule of thumb going forward: subclass when the *logic* differs; use exported fields when only the *numbers* differ.

## `Condition` is subclassed per kind, not parameterized by an enum
Deliberate contrast with `Technique` above: each condition kind (`TargetMissingStatusCondition`, `SelfHPBelowXCondition`, `TargetStatusStacksBelowXCondition`) reads a genuinely different fact about battle state and compares it differently — real behavioral divergence, not shared logic with different constants — so subclassing is the right call here even though it wasn't for `Technique`. `Condition` is still a `Resource` (not `RefCounted`) for the same Inspector-authoring/future-procedural-pool reasons as `Technique`.

## `PriorityRule.conditions` is an AND-array; an empty array is the catch-all
All conditions on a rule must hold for it to fire. An empty `conditions` array is vacuously true, which doubles as the unconditional catch-all case — no dedicated "AlwaysCondition" or `always.tres` resource is needed (that file was retired once this landed). `Combatant.choose_technique()` expects every `Familiar.priority_rules` list to end with such a catch-all rule so a familiar is never left with no technique chosen.

## Manual button harness is fully retired; both sides act through the same evaluator
`Combatant.choose_technique()` (walks `familiar.priority_rules` in order) is now how *both* the player and the enemy pick a technique each turn — `battle_controller.gd`'s `take_turn(actor, target, source)` replaced the old separate button-driven player path and `enemy_turn()`. There is no manual per-turn control left in the game.

## A pre-fight build-select screen exists as a deliberate stopgap, not the real buildcrafting UI
Removing manual per-turn control (above) would otherwise leave the prototype with literally nothing for the player to do, since the real replacement — an accumulating build across a run (Step 6's round/reward loop) — doesn't exist yet. `PriorityBuild` (a named, authored `Array[PriorityRule]`) plus a small button row at the start of each fight lets the player pick between pre-authored rule sets before watching the fight play out automatically. This is intentionally the smallest possible slice of buildcrafting, not a permanent feature to build further — expect it to be superseded or absorbed once Step 6's real round/reward loop exists.

## A resource referenced by more than one owner must not be edited to fit one consumer
Concrete incident: `fallback_attack.tres` is shared between Guubal's `priority_rules` and a player `PriorityBuild`. Editing it to give the player build a different fallback technique silently changed Guubal's fallback too. If a resource is genuinely shared, a build-specific need gets its own dedicated resource (see `fallback_venom_strike.tres`) instead of repointing the shared one.
