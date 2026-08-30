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

## Data (exported fields) vs. subclassing: ask whether the *behavior* differs, not just the numbers
Sharpened by a real correction this session: `Technique` initially got one subclass per status-applying move (`VenomStrikeTechnique`, `SearingSpitTechnique`, `AcidBathTechnique`), mirroring `Status`'s pattern — but those three were the *same formula* with different constants plugged in, not different behavior, so subclassing them was over-engineering. Collapsed into one class with `status_effect`/`status_stacks` exported fields and a small internal factory. `DefendTechnique` stayed a genuine subclass because its `execute()` really does something different. Contrast with `Condition`: each condition kind (`TargetMissingStatusCondition`, `SelfHPBelowXCondition`, `TargetStatusStacksBelowXCondition`) reads a genuinely different battle-state fact and compares it differently, so subclassing those *was* right, and collapsing them into an enum+match would have just relocated the same problem. The question to ask isn't "could I use one class with more fields" — it's "do these cases actually run different logic, or just different numbers through the same logic."

## `Resource` earns its keep even for data that's never reused
Initial assumption to correct: `Resource` seemed like the wrong choice for `Technique`/`Condition`/`PriorityRule` because a specific familiar's move list or rule list isn't shared with anything else. But reuse was never the defining property — `Familiar.sprite`'s `AtlasTexture` isn't reused either, and it's still correctly a `Resource`. The actual property that matters is "can this be authored in the Inspector or saved to disk," which only `Resource` supports (not `RefCounted`, which is why `Status` stays `RefCounted` — it's genuinely never authored, only ever constructed mid-battle). Concretely proven by embedding one-off `Condition`/`Technique` instances as inline `[sub_resource]` blocks directly inside `guubal.tres` with zero extra files — impossible if either type were `RefCounted`. `Resource` also costs nothing for future procedural assignment (`SomeTechnique.new()` works identically regardless of base type); it only adds the *option* of Inspector authoring and disk-saving on top.

## A resource file referenced by more than one owner is a shared asset, not a scratchpad
Real incident, not hypothetical: `fallback_attack.tres` is referenced by both Guubal's `priority_rules` and the "Status Stacker" player build. Editing it directly to give Status Stacker a different fallback move silently changed Guubal's fallback too (to a technique Guubal doesn't even have in its `techniques` list) — nothing crashed, it just quietly did the wrong thing. If a resource is actually shared, a build-specific need means creating that build its own dedicated resource, not repointing the shared one.

## Godot resource-saving gotchas worth remembering
- The `.tres` serializer omits `@export` properties whose current value equals the property's declared default — a field missing from a saved file isn't necessarily a bug, it can just mean "still at default."
- Editing a resource property several levels deep (e.g. `Familiar → priority_rules[] → PriorityRule → conditions[] → Condition`) through a *scene's* Inspector doesn't reliably mark the underlying external `.tres` file dirty for saving — a known rough edge in Godot's dirty-tracking for nested arrays-of-resources. Saving the scene isn't enough; open and save the resource itself directly when editing something that deeply nested.

## GDScript pitfall: `int / int` truncates
`(user.current_hp / user.familiar.max_hp) < hp_percent` always evaluated to `0 < hp_percent` (true) for any HP below max, because both operands were `int` and GDScript performs integer division unless at least one side is a `float`. Fix: `float(user.current_hp) / user.familiar.max_hp`.

## `Callable.bind()` for one handler shared across many generated nodes
`button.pressed.connect(_on_technique_button_pressed.bind(technique))` — `.bind()` wraps a method reference in a new `Callable` with extra trailing arguments baked in, so a signal that normally calls its handler with no arguments still delivers `technique` as if it were a parameter. This is what lets N runtime-generated buttons all connect to the *same* handler function while each still carrying its own captured value — the same role a closure plays in other languages.
