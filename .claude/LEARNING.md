# Learning Reference

Concepts encountered so far, organized by topic. Update entries in place as understanding deepens rather than appending duplicates.

## RefCounted vs Resource vs Node
Use `Resource` for data authored ahead of time in the Inspector, worth saving to disk (`Familiar`). Use `RefCounted` for runtime-only objects that need automatic memory cleanup but no scene-tree presence — no `_process`, no children, never edited in the Inspector (`Combatant`, `Status` and its subclasses). Use `Node` only when something actually needs to live in the scene tree.

## Control layout: minimum size and anchors
A plain `Control` does not propagate its children's minimum size the way a `Container` (VBoxContainer, HBoxContainer, etc.) does — a parent Container only ever queries a direct child's own `custom_minimum_size`. When restructuring `HPBar` from a bare `ProgressBar` into a `Control` wrapping a `Bar` child, `custom_minimum_size` had to move up to the new root, and `Bar` needed an explicit "Full Rect" anchor preset to track whatever size the root ends up being. Anchors on a child are relative to its own direct parent, not to some ancestor further up — every level in a hierarchy needs its own correct anchor setup.

## Godot coroutines (`await`)
Calling a function that contains an `await`, without awaiting the call yourself, still starts it immediately (synchronously, up to its first `await` point) and lets it keep running in the background — this is how `enemy_turn()` gets fired from `advance_turn()` without blocking. `get_tree().quit()` only *requests* a quit at the end of the current frame — it does not stop the currently-running function from continuing to execute. This caused a real bug: `check_victory()` fell through to `return false` after calling `quit()`, so callers never saw the "battle's over" signal.

## GDScript lambda closures capture by value
A local variable read/written inside a `func(...):` lambda does not share storage with the enclosing function's variable — mutating it inside the lambda does not propagate back out. This surfaced twice while writing throwaway verification scripts; in both cases the *test* was wrong, not the code under test. Fixed by printing from inside the lambda directly instead of relying on an outer variable.

## Polymorphism for "same interface, different behavior"
The `Status` base class defines a handful of virtual methods (`on_tick`, `on_reapply`, `is_expired`, `next_tick_damage`, `preview_color`, `modify_defense`, `stack_with`) with sensible no-op defaults; each concrete status (`PoisonStatus`, `BurnStatus`, `AcidStatus`) overrides only the ones it actually needs. Recognizing when *not* to override something — neither `PoisonStatus` nor `AcidStatus` needed to touch `is_expired()`, since the base `stacks <= 0` was already correct for both — is as important as knowing when to.

## Two hooks can each see different state
`Combatant.add_status()` calls `on_reapply(target)` before `stack_with(other)` specifically because `on_reapply` only receives the target (not the incoming status) and `stack_with` only receives the incoming status (not the target). Burn's Flare mechanic (bonus damage based on stacks remaining *before* the reapplication resets them) only works because it reads `stacks` before `stack_with` overwrites it. Order matters whenever two hooks have different, non-overlapping visibility into state.

## When an abstraction is/isn't earned yet
`modify_defense(base_defense) -> int` was added to `Status` specifically for Acid, and deliberately *not* generalized into a broader `modify_stat(stat_name, base_value)` — there was only one concrete case (Defense). The rule of thumb applied repeatedly this session: wait for a second real, concrete use before widening a narrow method's shape, since guessing the right general shape from a single example usually guesses wrong.
