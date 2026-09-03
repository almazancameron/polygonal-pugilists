# Priority Builder PoC — Design

**Date:** 2026-09-02
**Status:** approved, not yet implemented
**Scope:** Pixel Pugilists

## 1. Goal

A standalone, Scratch-style block editor for composing a familiar's
`priority_rules`: drag technique and condition blocks into an ordered list of
rule slots, nest conditions to AND them, and see which rule would fire against
an editable mock battle state.

This is the prototype for the in-run priority-rule editor that
`GAME_DESIGN.md` §10 names as the next roadmap item and §9.4 designates as the
replacement for the `PriorityBuild` stopgap. It is built as its own screen so
it can be judged on feel before anything integrates it.

The question it exists to answer: **is assembling and ordering priority rules
by hand legible and satisfying enough to be the game's buildcrafting layer?**

## 2. Scope

**In scope**

- A standalone scene, run directly, that touches neither `battle.tscn` nor
  `battle_controller.gd`.
- Nine authored condition blocks covering status, HP, stat, and negation.
- Technique blocks sourced from a familiar's own `techniques` array.
- Nested condition blocks as AND.
- Reorderable rule slots.
- A mock-state probe reporting per-rule fire/skip/unreached/incomplete.

**Out of scope**

- Any integration with the run loop, bracket, or reward flow. The PoC produces
  an in-memory `Array[PriorityRule]`; nothing consumes it yet.
- Saving a build to disk. No `PriorityBuild` `.tres` is written. Persistence is
  `Not introduced` on the learning roadmap and would be its own exercise.
- OR conditions. There is no `OrCondition` class and none is being added.
- Editing techniques, stats, or statuses. The builder edits rules only.

**Deferred with a reason**

- `BOOL_TOGGLE` sentence part — `fixed_values` (§4) covers every boolean field
  in the codebase today.
- Changing `Combatant.choose_technique()` to return per-rule results. That is
  the correct refactor when this graduates into the real §9.4 flow, not while
  it is a PoC. See §8.
- Hardening `choose_technique()` against a null technique. A one-line
  follow-up, deliberately not bundled with a PoC. See §8.3.

An earlier draft deferred raw-value HP comparison as needing a separate float
part kind. It does not: §4.2 collapses integer, float, and percentage into one
`NUMBER` part, so raw-value HP costs one `.tres` and is in scope.

## 3. Approach: descriptor-driven blocks

Three approaches were weighed:

- **A** — blocks own live `Condition` instances, one hand-written block script
  per condition kind.
- **B** — blocks hold plain UI state and compile to fresh resources via a
  mapping layer.
- **C** — one generic block script driven by authored descriptor resources.

**C was chosen.** `StatusComparisonCondition`, `HpComparisonCondition`, and
`StatComparisonCondition` are structurally isomorphic — all three declare
`left_target`, `compare_mode`, `right_target`, `right_value`, and `comparator`,
differing only in the one "which thing" field and a kind-specific toggle. A
descriptor there is not a speculative generalization; it names a symmetry the
code already has.

B was rejected because its block-to-resource mapping layer must be updated
every time a `Condition` subclass gains a field, and goes stale silently. A was
rejected because it writes per-kind code for a shape that is already uniform.

C's usual weakness — indirection that outweighs the saving at small counts —
is answered by §4's "one descriptor per sentence shape" rule, which removes the
need for conditional slot visibility, the part of C that would otherwise be
ugly.

## 4. The descriptor model

Two new `Resource` types, authored as `.tres` in the Inspector exactly the way
`TechniqueStepGroup` and `TechniqueAction` are.

```gdscript
class_name ConditionBlockDefinition
extends Resource

@export var category: String = "Status"          # palette grouping header
@export var block_label: String = ""             # short name shown on the block
@export var condition_script: Script             # .new()'d fresh per drag
@export var fixed_values: Dictionary = {}        # fields the sentence never exposes
@export var sentence: Array[SentencePart] = []
@export var body_property: StringName = &""      # see §7
```

```gdscript
class_name SentencePart
extends Resource

enum Kind { TEXT, ENUM_CHOICE, NUMBER }
enum OptionSource { NONE, TARGET, COMPARATOR, STATUS_EFFECT, FAMILIAR_STAT }

@export var kind: Kind = Kind.TEXT
@export var text: String = ""                    # Kind.TEXT only
@export var property: StringName = &""           # destination field on the condition
@export var option_source: OptionSource = OptionSource.NONE
@export var min_value: float = 0.0
@export var max_value: float = 99.0
@export var step: float = 1.0
@export var display_scale: float = 1.0           # widget value * scale = stored value
@export var suffix: String = ""
```

### 4.1 One descriptor per sentence shape

The key rule. `compare_mode` decides whether `right_value` or `right_target`
is the live field, so a single block covering both would need slots that hide
and show. Instead, each *shape* is its own palette block, with `fixed_values`
pinning down what the sentence does not expose. No conditional visibility
anywhere, and the palette gets richer rather than more modal.

This is also what makes `check_all` and `use_percent` need no widget: a
"total stacks" block sets `check_all: true` in `fixed_values` and simply omits
the status dropdown.

### 4.2 Numeric parts

`Kind.NUMBER` is one part kind covering integers, raw floats, and percentages —
what varies is the widget's configuration, not the property's type:

| Use | min | max | step | display_scale | suffix |
|---|---|---|---|---|---|
| Stack count | 0 | 99 | 1 | 1.0 | `""` |
| HP percent | 0 | 100 | 5 | 0.01 | `"%"` |
| Raw HP | 0 | 999 | 1 | 1.0 | `" HP"` |
| Stat value | 0 | 99 | 1 | 1.0 | `""` |

Written as `condition.set(part.property, spin.value * part.display_scale)`.
The HP percent row reproduces `poison_spammer.tres`'s `right_value = 0.25`
from a widget reading `25`.

**To verify first:** that `set()` writes a float into the `int`-typed
`right_value` of `StatusComparisonCondition`/`StatComparisonCondition` with a
correct conversion. If it does not, `SentencePart` gains an explicit
`as_integer: bool` — not a new part kind.

### 4.3 Enum option tables

`option_source` selects the option list; `property` selects the destination.
The same source therefore serves `left_target` and `right_target`.

- `TARGET` → `user's` = 0 (`SELF`), `target's` = 1 (`TARGET`).
- `COMPARATOR` → displayed `<`, `<=`, `>`, `>=`, `==`, stored as
  `GREATER` = 0, `GREATER_OR_EQUAL` = 1, `LESS` = 2, `LESS_OR_EQUAL` = 3,
  `EQUAL` = 4.
- `STATUS_EFFECT` → every `Status.StatusEffect` except `NONE`, labelled with
  `String(Status.status_effect_id(e)).capitalize()`.
- `FAMILIAR_STAT` → every `Familiar.Stat`, labelled with
  `Familiar.stat_name(s)`.

**The comparator table must map explicitly, never by display index.** The
declared enum order is `GREATER, GREATER_OR_EQUAL, LESS, LESS_OR_EQUAL, EQUAL`
in all three condition classes, which is not the order a person wants to read.

`fixed_values` is authored as raw ints in the `.tres`, so the `CompareMode`
mapping matters there too. All three classes declare the
compare-against-the-other-side mode first and `FLAT_VALUE` second:

| Class | 0 | 1 |
|---|---|---|
| `StatusComparisonCondition` | `STATUS` | `FLAT_VALUE` |
| `HpComparisonCondition` | `HP` | `FLAT_VALUE` |
| `StatComparisonCondition` | `STAT` | `FLAT_VALUE` |

So every `compare_mode: FLAT_VALUE` in §4.4 is authored as `1`, and
`compare_mode: STATUS` / `HP` / `STAT` as `0`.

These tables encode a latent coupling: all three classes independently declare
identical `Target` and `Comparator` enums, and identical `CompareMode`
orderings per the table above. Reordering any one of them silently breaks the
tables. Noted here because nothing in the code enforces it.

### 4.4 The nine block definitions

`resources/priority_builder/blocks/`. `fixed_values` shown symbolically;
authored as the ints above.

| `.tres` | category | fixed_values | sentence |
|---|---|---|---|
| `status_vs_value` | Status | `compare_mode: FLAT_VALUE` | `[TARGET] [STATUS_EFFECT]` stacks `[COMPARATOR] [NUMBER]` |
| `status_vs_status` | Status | `compare_mode: STATUS` | `[TARGET] [STATUS_EFFECT]` stacks `[COMPARATOR] [TARGET] [STATUS_EFFECT]` stacks |
| `all_stacks_vs_value` | Status | `compare_mode: FLAT_VALUE`, `check_all: true` | `[TARGET]` total stacks `[COMPARATOR] [NUMBER]` |
| `hp_vs_percent` | HP | `compare_mode: FLAT_VALUE`, `use_percent: true` | `[TARGET]` HP `[COMPARATOR] [NUMBER%]` |
| `hp_vs_value` | HP | `compare_mode: FLAT_VALUE`, `use_percent: false` | `[TARGET]` HP `[COMPARATOR] [NUMBER]` |
| `hp_vs_hp` | HP | `compare_mode: HP`, `use_percent: true` | `[TARGET]` HP `[COMPARATOR] [TARGET]` HP |
| `stat_vs_value` | Stat | `compare_mode: FLAT_VALUE` | `[TARGET] [FAMILIAR_STAT] [COMPARATOR] [NUMBER]` |
| `stat_vs_stat` | Stat | `compare_mode: STAT` | `[TARGET] [FAMILIAR_STAT] [COMPARATOR] [TARGET] [FAMILIAR_STAT]` |
| `not` | Logic | — | (empty sentence; `body_property: "wrapped_condition"`) |

Adding a condition kind later is a `.tres`, plus at most one `OptionSource`
entry. No new block code.

## 5. Layout

```
PriorityBuilder (Control, Full Rect)              priority_builder.gd
├─ Columns (HBoxContainer)
│  ├─ LeftColumn (VBoxContainer, min_x 260)
│  │  ├─ FamiliarPanel (PanelContainer)          portrait + 5-row stat grid
│  │  └─ TechniquePalette (ScrollContainer)      block_palette.gd
│  ├─ BuildColumn (VBoxContainer, EXPAND_FILL)
│  │  ├─ Header (HBoxContainer)                  "Priority" + AddSlotButton
│  │  └─ ScrollContainer → SegmentList           segment_list.gd
│  └─ RightColumn (VBoxContainer, min_x 320)
│     ├─ ConditionPalette (ScrollContainer)      block_palette.gd
│     └─ StateProbe (PanelContainer)             state_probe.gd
└─ TooltipLayer                                   instance of tooltip_layer.tscn
```

Both palettes are the same `block_palette.gd`, grouping blocks under category
headers — so `ConditionBlockDefinition.category` is what splits the right-hand
palette into Status / HP / Stat / Logic.

The familiar panel shows base stats from `Familiar`, and additionally the
`effective_stat()` value beside the base whenever a probe status changes it
(Hone, Fortify, Enlarge, Ruin). `stat_vs_value` conditions read the effective
value, so showing only the base would mislead.

## 6. Drag and drop

Godot's `_get_drag_data` / `_can_drop_data` / `_drop_data` `Control` virtuals.
Payloads are Dictionaries:

| Source | Payload |
|---|---|
| Palette condition block | `{source: "palette", definition: <ConditionBlockDefinition>}` |
| Palette technique block | `{source: "palette", technique: <Technique>}` |
| Block already in the build | `{source: "build", node: self}` |
| Rule slot header handle | `{source: "build", node: <RuleSegment>}` |

Palette blocks never leave the palette. Blocks already in the build carry
themselves and get reparented, so dragging out of a slot and dragging between
slots are the same code path.

### 6.1 Fresh instances, and why techniques differ

`ConditionBlock._setup(definition)` calls `definition.condition_script.new()`,
applies `fixed_values`, then applies each sentence part's current widget value.
A definition is shared and read-only; a `Condition` instance belongs to exactly
one block and is mutated by its widgets.

This is the direct fix for the incident in `DECISIONS.md` §"A resource
referenced by more than one owner must not be edited to fit one consumer",
where editing `fallback_attack.tres` for a player build silently changed
Guubal's fallback. A palette that handed out references to shared `Condition`
instances would reproduce that bug at UI speed.

`Technique` resources are *not* copied — `rule.technique` points at the shared
`.tres`. The distinction is that the builder never mutates a technique, only
references it; conditions get their fields written by widgets.

### 6.2 Nesting

Drop targeting asks the innermost `Control` under the cursor first and bubbles
up the parent chain, skipping `mouse_filter = IGNORE` nodes. A condition
block's body zone therefore wins over the rule slot containing it, and
nesting needs no depth bookkeeping.

### 6.3 Reordering

Rule slots drag by their header handle. `SegmentList._drop_data` computes the
insert index by comparing `at_position.y` against each child's rect midpoint,
then calls `move_child`. `_can_drop_data` runs every frame during a hover, so
that is where the insertion-line indicator is positioned.

### 6.4 The one-empty-slot rule

`AddSlotButton.disabled = _has_empty_segment()`, recomputed on every structural
change via one signal that segments emit upward.

Two distinct predicates, which must not be conflated:

- **empty** — no condition blocks *and* no technique. Gates the add button.
- **complete** — has a technique, and every wrapper block has a filled body.
  Conditions are optional. Gates inclusion in the probe (§8).

A slot with conditions but no technique is non-empty *and* incomplete: the add
button stays disabled, and the probe skips the slot with a badge.

Each slot has its own delete button, so an unwanted empty slot is removable
rather than a dead end.

## 7. Compiling the block tree to rules

`SegmentList` walks its slots in display order and produces
`Array[PriorityRule]`. Nesting is **presentation only** — condition B nested
inside A means "A AND B", which flattens to `conditions = [A, B]`, because an
ANDed array is already what `PriorityRule.conditions` means and there is no
`AndCondition` class.

For each slot:

1. `rule = PriorityRule.new()`
2. `rule.technique` = the technique block's shared `Technique`, or `null`.
3. Walk the slot's condition blocks depth-first, pre-order, appending each
   block's `Condition` to `rule.conditions`.
4. If the slot is incomplete (§6.4), it is excluded from the compiled list
   entirely and badged.

Pre-order matters for one reason only: all conditions are ANDed, so order does
not change *whether* a rule fires, but `choose_technique()` reports the *first*
failing condition as the skip reason. Pre-order makes the reported failure
match top-to-bottom visual reading.

### 7.1 Wrapper blocks

A block whose `body_property` is non-empty (today only `not`) is a wrapper. Its
single body child is compiled to a `Condition` and assigned via
`wrapper.set(body_property, child_condition)`; the wrapper is appended to
`rule.conditions` and **the child is not appended separately**.

**A wrapper's body accepts exactly one condition, and that condition accepts no
body children of its own.** Enforced in `_can_drop_data`. Without this rule a
block nested inside a `not` would flatten into the rule's `conditions[]` and
escape the negation, turning `not (A AND B)` into `not A AND B` — a silent
semantic change.

The consequence is that `not (A AND B)` is not expressible. This is acceptable:
it equals `not A OR not B`, and there is no OR.

## 8. The state probe

Two `Combatant`s built from exported familiars: `builder_familiar` (default
`twerpent.tres`) and `opponent_familiar` (default `guubal.tres`).

### 8.1 Declared, not simulated, state

`add_status()` runs Ward absorption, `on_reapply`, `on_applied`, and
`trigger_on_status_applied`. A probe where entering "3 Poison" yields 0 Poison
because the target already has Ward would be useless for reasoning about
conditions. So the probe attaches statuses directly, matching what
`combatant.gd` does at lines 77-78 minus the hooks:

```gdscript
var s: Status = Status.create(effect, stacks)
s.owner = combatant
combatant.statuses.append(s)
```

Controls per side: an HP `SpinBox` bounded `0..familiar.max_hp`, and an
add/remove status row (effect dropdown excluding `NONE`, stacks spinbox). Any
edit, and any change to the block tree, re-runs evaluation.

### 8.2 Per-rule verdicts

| Badge | Meaning |
|---|---|
| `✓ FIRES` | first rule whose conditions all hold |
| `✗ skipped` | evaluated, a condition failed — shows `failed_condition.describe()` |
| `– unreached` | a rule above it already fired |
| `⚠ incomplete` | not runnable, excluded from evaluation |

`choose_technique()` cannot produce this by itself: it returns `skip_reasons` as
a flat `Array[String]`, so badging rule *i* would mean assuming
`skip_reasons[i]` corresponds to rule *i* — true today, but couples the UI to
the loop's internal append order.

So the probe walks the compiled list itself. This restates the loop but not the
primitive: `condition.is_met()` is the real one, called directly. To keep the
restated loop from drifting, the probe **also** calls the real
`choose_technique()` once on the same compiled list and compares winners,
surfacing a mismatch label if they ever disagree. Normally that label is empty.

`– unreached` is the most valuable badge: it is how a catch-all sitting above
three conditional rules becomes visibly the reason they are all dead. That is
the exact class of ordering mistake the builder exists to make visible.

### 8.3 Incomplete rules

Two forms, both latent null-dereferences in existing code that a live probe
would otherwise hit on every edit:

- A rule with no technique — `rule.technique.technique_name` at
  `combatant.gd:189`.
- A wrapper block with an empty body — `wrapped_condition.is_met()` at
  `not_condition.gd:7`.

Both are excluded from the compiled list and badged. Exclusion is silent with
respect to *evaluation* — a half-built rule in the middle cannot change which
rule fires — with the badge as the only explanation needed.

These are latent rather than live bugs in the main project, since authored
rules always have techniques. The PoC works around them rather than changing
shared code. Hardening `choose_technique()` against a null technique is a
reasonable one-line follow-up, deliberately not bundled here.

### 8.4 No match

If no rule matches, the probe says so and names the fix: "no rule matched — add
a slot with a technique and no conditions." The catch-all requirement is
currently tribal knowledge in a comment at `priority_rule.gd:7`; this surfaces
it in the UI.

## 9. `Technique.describe()`

`Technique` is the only content class without `describe()` — `Status`,
`Condition`, and `UpgradeOption` all have one. Technique blocks need hover text,
so `describe()` is added to `Technique`, walking `step_groups` to summarize
power multiplier, hit count, heals, and status applications.

This is **the only edit to shared code in the PoC.** It is additive. It also
fixes a live gap: `add_technique_upgrade.gd:15` currently offers "Learn Acid
Bath" with no indication of what Acid Bath does, so the running game's reward
screen benefits too.

Status names in the output are wrapped as `[url=<status_id>]Name[/url]`, which
`tooltip_panel.gd:36-42` already resolves into nested status tooltips via
`Status.from_id()`. No new tooltip machinery.

Blocks call the existing `TooltipLayer` API — `hover_started(control, text)` /
`hover_ended(control)` from their own `mouse_entered` / `mouse_exited`, the same
way `battle_controller.gd:94-95` wires upgrade buttons.

## 10. Files

New, all additive except §9.

```
scripts/priority_builder/
    condition_block_definition.gd      Resource (§4)
    sentence_part.gd                   Resource (§4)
    priority_builder.gd                screen root, owns the familiars
    block_palette.gd                   category-grouped palette, both columns
    palette_block.gd                   a draggable palette entry
    segment_list.gd                    slot ordering + compile (§7)
    rule_segment.gd                    one rule slot
    condition_block.gd                 generic descriptor-driven block
    technique_block.gd                 a placed technique
    state_probe.gd                     mock state + verdicts (§8)

scenes/priority_builder/
    priority_builder.tscn  rule_segment.tscn  condition_block.tscn
    technique_block.tscn   palette_block.tscn

resources/priority_builder/blocks/     nine .tres definitions (§4.4)

scripts/technique/technique.gd         + describe()        ← only shared edit
```

## 11. Validation

Using the two patterns `CLAUDE.md` already establishes.

- `godot --headless --check-only --quit` for parse and missing-node errors.
- One throwaway `scripts/_verify_priority_builder.gd`, deleted immediately
  after use, covering what a screenshot cannot:
  - `set()` writes a float into an `int`-typed `right_value` correctly (§4.2).
  - A nested block tree compiles to the expected `conditions[]` order (§7).
  - A wrapper block assigns to `body_property` and does not also append its
    child (§7.1).
  - Two blocks dragged from the same palette entry hold *different* `Condition`
    instances (§6.1).
  - An incomplete rule is excluded rather than crashing (§8.3).
  - `Technique.describe()` returns non-empty text for every authored technique.
- Drag feel, tooltip behavior, and layout are inherently manual. The scene will
  be run and observed, and anything left unverified stated plainly.

## 12. Open questions

Deliberately unresolved, to be answered by using the thing:

- Does nesting read as AND to someone who did not build it, or does a flat
  ANDed list with an explicit `AND` separator read better? Cheap to switch —
  it changes `condition_block.tscn` and §7's walk, nothing else.
- Is a nine-block palette the right granularity, or do `status_vs_status` /
  `stat_vs_stat` / `hp_vs_hp` go unused enough to cut?
- Does the probe want a "step forward one turn" button, or is single-state
  evaluation enough to reason about ordering?

None of these should be settled by the first implementation. Per `CLAUDE.md`,
observations go into the roadmap or a design note rather than being declared
canon.
