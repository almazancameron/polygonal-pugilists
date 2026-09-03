# Priority Builder PoC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A standalone Scratch-style block editor scene for composing a familiar's `priority_rules`, with a mock-state probe showing which rule would fire.

**Architecture:** Descriptor-driven blocks. Two new `Resource` types (`ConditionBlockDefinition` / `SentencePart`) are authored as nine `.tres` files, one per condition *sentence shape*; a single generic `ConditionBlock` script builds its widgets from a definition and mints a fresh `Condition` instance per drag. Nesting condition blocks is presentation for ANDing, flattened pre-order into `PriorityRule.conditions`. Everything is additive except one method added to `Technique`.

**Tech Stack:** Godot 4.7.1, GDScript. No test framework in this repo — verification uses the project's two established patterns (see Global Constraints).

**Spec:** `docs/superpowers/specs/2026-09-02-priority-builder-poc-design.md` — read it alongside this plan; every task argues from a spec section.

## Global Constraints

- **Godot binary:** `../Godot_v4.7.1-stable_win64_console.exe`, relative to the project directory. All commands below run from the project root.
- **No test framework exists.** `CLAUDE.md` forbids inventing test infrastructure the repo does not contain. Verification is exactly two commands:
  - `"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit` — parse and missing-node errors project-wide.
  - `"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/_verify_priority_builder.gd` — behavior.
- **The verify script is throwaway.** `CLAUDE.md`'s pattern is delete-immediately-after-use. This plan deliberately keeps one `scripts/_verify_priority_builder.gd` alive across Tasks 1–9, growing it per task, and deletes it in Task 11. Deviation is intentional: per-task verification needs it to persist. It must not survive the final commit.
- **`extends SceneTree` verify scripts use `_initialize()`, not `_init()`.** `root` does not exist yet in `_init()`, and adding a `Control` to `root` is what makes its `_ready()` (and therefore its `@onready` vars) run.
- **Typed GDScript**, matching existing project style. Tabs for indentation, matching `scripts/combatant.gd`.
- **Never mutate a `ConditionBlockDefinition` at runtime.** Definitions are shared and read-only; each block owns its own `Condition`. See spec §6.1 and `DECISIONS.md` §"A resource referenced by more than one owner must not be edited to fit one consumer".
- **Enum ordinals are load-bearing** when authoring `.tres` `fixed_values` (spec §4.3): `FLAT_VALUE` = 1; `STATUS`/`HP`/`STAT` = 0; `Target.SELF` = 0, `Target.TARGET` = 1; `Comparator` is `GREATER`=0, `GREATER_OR_EQUAL`=1, `LESS`=2, `LESS_OR_EQUAL`=3, `EQUAL`=4.
- **Do not touch** `scenes/battle.tscn` or `scripts/battle_controller.gd`. The PoC is a separate screen (spec §2).
- **Commit per task.** The working tree already carries ~88 files of unrelated in-progress content work — every `git add` must name exact paths, never `-A` or `.`.

---

### Task 1: `Technique.describe()`

The only shared-code change in the whole PoC (spec §9). Isolated first so it gets its own review.

**Files:**
- Modify: `scripts/technique/technique.gd` (append method)
- Create: `scripts/_verify_priority_builder.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `Technique.describe() -> String`. Returns a human-readable summary. Status names are wrapped as `[url=<status_id>]Name[/url]` so `tooltip_panel.gd`'s `_on_meta_hover_started` resolves them to nested tooltips.

Relevant existing shapes: `TechniqueStepGroup` has `actions: Array[TechniqueAction]`, `repeat_count: int`, `conditions: Array[Condition]`, `numeric_bonuses: Array[NumericBonus]`. `HitAction` is a marker with no fields. `StatusApplicationAction` has `target: Target {SELF, TARGET}`, `effect: Status.StatusEffect`, `stacks: int`. `HealAction` has `heal_percent: float`, `heal_flat: int`. `ModifyStatusAction` has `effect`, `modifier: float`, `operator: Operator {MULTIPLY, SUBTRACT, DIVIDE, SET}`, `target: Target`.

- [ ] **Step 1: Write the failing verification**

Create `scripts/_verify_priority_builder.gd`:

```gdscript
extends SceneTree

## Throwaway verification for the priority builder PoC. Deleted in Task 11 --
## see the plan's Global Constraints. Grows one _check_* function per task.

var _failures: Array[String] = []

func _initialize() -> void:
	_check_technique_describe()

	if _failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		print("FAILURES (%d):" % _failures.size())
		for failure in _failures:
			print("  - %s" % failure)

	quit(1 if _failures.size() > 0 else 0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _check_technique_describe() -> void:
	var paths: Array[String] = [
		"res://resources/techniques/attack.tres",
		"res://resources/techniques/defend.tres",
		"res://resources/techniques/venom_strike.tres",
		"res://resources/techniques/acid_bath.tres",
		"res://resources/techniques/searing_spit.tres",
		"res://resources/techniques/triple_slash.tres",
		"res://resources/techniques/gorge.tres",
		"res://resources/techniques/open_wounds.tres",
		"res://resources/techniques/pure_restoration.tres",
		"res://resources/techniques/concussive_blow.tres",
		"res://resources/techniques/ultra_beam.tres",
	]

	for path in paths:
		var technique: Technique = load(path)
		_expect(technique != null, "could not load %s" % path)
		if technique == null:
			continue
		var text: String = technique.describe()
		_expect(text != "", "%s describe() returned empty" % technique.technique_name)
		print("  %s -> %s" % [technique.technique_name, text])

	# Defend self-applies Defending, so its description must name the status
	# and must link it for the nested-tooltip path in tooltip_panel.gd.
	var defend: Technique = load("res://resources/techniques/defend.tres")
	if defend != null:
		var text: String = defend.describe()
		_expect(text.contains("[url=defending]"), "Defend describe() missing [url=defending] link, got: %s" % text)
```

- [ ] **Step 2: Run it to verify it fails**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/_verify_priority_builder.gd
```

Expected: FAIL. `describe()` does not exist on `Technique`, so this is a parse/runtime error naming `describe`, not a clean assertion failure. That is the expected failing state.

- [ ] **Step 3: Implement `describe()`**

Append to `scripts/technique/technique.gd`:

```gdscript
## A human-readable summary built from step_groups, for tooltips and reward
## offers. Status names are wrapped in [url=...] so TooltipPanel's
## meta_hover path resolves them into nested status tooltips -- see
## tooltip_panel.gd's _on_meta_hover_started().
func describe() -> String:
	var parts: Array[String] = []

	for step_group in step_groups:
		var group_parts: Array[String] = []

		for action in step_group.actions:
			if action is HitAction:
				group_parts.append("deals %d%% damage" % int(power_multiplier * 100))
			elif action is StatusApplicationAction:
				var who: String = "self" if action.target == StatusApplicationAction.Target.SELF else "target"
				group_parts.append("applies %d %s to %s" % [
					action.stacks, _status_link(action.effect), who
				])
			elif action is ModifyStatusAction:
				var who: String = "self" if action.target == ModifyStatusAction.Target.SELF else "target"
				group_parts.append("%s %s's %s" % [
					_operator_phrase(action.operator, action.modifier), who, _status_link(action.effect)
				])
			elif action is HealAction:
				if action.heal_percent > 0.0 and action.heal_flat > 0:
					group_parts.append("heals %d%% of damage dealt +%d" % [int(action.heal_percent * 100), action.heal_flat])
				elif action.heal_percent > 0.0:
					group_parts.append("heals %d%% of damage dealt" % int(action.heal_percent * 100))
				else:
					group_parts.append("heals %d" % action.heal_flat)

		if group_parts.is_empty():
			continue

		var group_text: String = ", ".join(group_parts)

		if step_group.repeat_count > 1:
			group_text = "%s (x%d)" % [group_text, step_group.repeat_count]

		if not step_group.conditions.is_empty():
			var condition_texts: Array[String] = []
			for condition in step_group.conditions:
				condition_texts.append(condition.describe())
			group_text = "%s, if %s" % [group_text, " and ".join(condition_texts)]

		parts.append(group_text)

	if parts.is_empty():
		return "%s does nothing." % technique_name

	return "%s: %s." % [technique_name, "; ".join(parts)]

## Wraps a status name in the [url=...] markup TooltipPanel resolves, so a
## technique tooltip's status names get their own nested tooltips.
func _status_link(effect: Status.StatusEffect) -> String:
	var id: StringName = Status.status_effect_id(effect)
	return "[url=%s]%s[/url]" % [id, String(id).capitalize()]

func _operator_phrase(operator: ModifyStatusAction.Operator, modifier: float) -> String:
	match operator:
		ModifyStatusAction.Operator.MULTIPLY:
			return "multiplies by %s" % modifier
		ModifyStatusAction.Operator.SUBTRACT:
			return "removes %d from" % int(modifier)
		ModifyStatusAction.Operator.DIVIDE:
			return "divides by %s" % modifier
		ModifyStatusAction.Operator.SET:
			return "sets to %d" % int(modifier)
	return "changes"
```

- [ ] **Step 4: Run both verifications**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/_verify_priority_builder.gd
```

Expected: no parse errors; `ALL CHECKS PASSED`, with one printed description per technique. **Read the printed descriptions** — they are the actual tooltip copy. Fix awkward phrasing now.

- [ ] **Step 5: Commit**

```bash
git add scripts/technique/technique.gd scripts/_verify_priority_builder.gd
git commit -m "feat: Technique.describe() for technique tooltips"
```

---

### Task 2: Descriptor resources and the nine block definitions

Spec §4. Two `Resource` scripts plus nine `.tres` files.

**Files:**
- Create: `scripts/priority_builder/sentence_part.gd`
- Create: `scripts/priority_builder/condition_block_definition.gd`
- Create: `scripts/_generate_builder_blocks.gd` (throwaway, deleted this task)
- Create: `resources/priority_builder/blocks/*.tres` (nine files)
- Modify: `scripts/_verify_priority_builder.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `SentencePart` with `kind: Kind {TEXT, ENUM_CHOICE, NUMBER}`, `text: String`, `property: StringName`, `option_source: OptionSource {NONE, TARGET, COMPARATOR, STATUS_EFFECT, FAMILIAR_STAT}`, `min_value: float`, `max_value: float`, `step: float`, `display_scale: float`, `suffix: String`. `ConditionBlockDefinition` with `category: String`, `block_label: String`, `condition_script: Script`, `fixed_values: Dictionary`, `sentence: Array[SentencePart]`, `body_property: StringName`.

Authoring the nine `.tres` by hand means hand-writing `uid://` script references, which is error-prone. Generate them with `ResourceSaver` instead, then delete the generator.

- [ ] **Step 1: Write the two Resource scripts**

`scripts/priority_builder/sentence_part.gd`:

```gdscript
class_name SentencePart
extends Resource

## One fragment of a condition block's fill-in-the-blank sentence: either
## literal text, a dropdown bound to one of the shared enum option tables, or
## a numeric spinner. `property` names the field on the Condition this part
## writes to -- so the same option_source serves both left_target and
## right_target, differing only in destination.

enum Kind { TEXT, ENUM_CHOICE, NUMBER }
enum OptionSource { NONE, TARGET, COMPARATOR, STATUS_EFFECT, FAMILIAR_STAT }

@export var kind: Kind = Kind.TEXT

## Kind.TEXT only.
@export var text: String = ""

## Destination field on the Condition, for ENUM_CHOICE and NUMBER.
@export var property: StringName = &""

@export var option_source: OptionSource = OptionSource.NONE

@export var min_value: float = 0.0
@export var max_value: float = 99.0
@export var step: float = 1.0

## Widget value * display_scale = the value stored on the Condition. 0.01
## makes a spinner reading 25 store 0.25, which is how HpComparisonCondition
## expects a percentage (see poison_spammer.tres's right_value = 0.25).
@export var display_scale: float = 1.0

@export var suffix: String = ""
```

`scripts/priority_builder/condition_block_definition.gd`:

```gdscript
class_name ConditionBlockDefinition
extends Resource

## One palette block: which Condition subclass it builds, which of that
## subclass's fields its sentence exposes, and which it pins down.
##
## There is one definition per *sentence shape*, not per Condition subclass.
## compare_mode decides whether right_value or right_target is the live
## field, so a single block covering both would need slots that hide and
## show; instead "target's Acid stacks < 5" and "my Poison vs their Poison"
## are two separate blocks. That is what keeps ConditionBlock free of
## conditional visibility logic.
##
## Shared and read-only. Never mutated at runtime -- each ConditionBlock
## instantiates its own Condition via condition_script.new(). See
## DECISIONS.md on resources shared between owners.

## Palette grouping header ("Status", "HP", "Stat", "Logic").
@export var category: String = "Status"

## Short name shown on the block itself.
@export var block_label: String = ""

@export var condition_script: Script

## Fields the sentence never exposes, applied before the sentence's own
## values. Enum values are raw ints -- see the plan's Global Constraints for
## the ordinals, since getting these wrong yields a condition that silently
## always evaluates the same way.
@export var fixed_values: Dictionary = {}

@export var sentence: Array[SentencePart] = []

## Non-empty makes this a wrapper block: its single body child compiles to a
## Condition assigned to this property (only NotCondition.wrapped_condition
## today) instead of being flattened into the rule's conditions[]. See spec
## section 7.1 -- a wrapper's body takes exactly one leaf condition.
@export var body_property: StringName = &""
```

- [ ] **Step 2: Run the parse check to verify the scripts load**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit
```

Expected: no errors. (`class_name` registration is what later tasks depend on.)

- [ ] **Step 3: Write the generator**

Create `scripts/_generate_builder_blocks.gd`:

```gdscript
extends SceneTree

## Throwaway. Writes the nine ConditionBlockDefinition .tres files, so their
## script uid references are produced by ResourceSaver rather than typed by
## hand. Deleted at the end of Task 2.

const OUT_DIR: String = "res://resources/priority_builder/blocks"

const STATUS_CMP: String = "res://scripts/condition/status_comparison_condition.gd"
const HP_CMP: String = "res://scripts/condition/hp_comparison_condition.gd"
const STAT_CMP: String = "res://scripts/condition/stat_comparison_condition.gd"
const NOT_CND: String = "res://scripts/condition/not_condition.gd"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	# Enum ordinals per the plan's Global Constraints:
	#   compare_mode: 0 = STATUS/HP/STAT, 1 = FLAT_VALUE
	#   Target: 0 = SELF, 1 = TARGET
	#   Comparator: 0 GREATER, 1 GREATER_OR_EQUAL, 2 LESS, 3 LESS_OR_EQUAL, 4 EQUAL

	_save("status_vs_value", "Status", "Status stacks vs value", STATUS_CMP,
		{"compare_mode": 1}, "", [
			_enum("left_target", SentencePart.OptionSource.TARGET),
			_enum("left_status_effect", SentencePart.OptionSource.STATUS_EFFECT),
			_text(" stacks "),
			_enum("comparator", SentencePart.OptionSource.COMPARATOR),
			_number("right_value", 0, 99, 1, 1.0, ""),
		])

	_save("status_vs_status", "Status", "Status stacks vs status stacks", STATUS_CMP,
		{"compare_mode": 0}, "", [
			_enum("left_target", SentencePart.OptionSource.TARGET),
			_enum("left_status_effect", SentencePart.OptionSource.STATUS_EFFECT),
			_text(" stacks "),
			_enum("comparator", SentencePart.OptionSource.COMPARATOR),
			_enum("right_target", SentencePart.OptionSource.TARGET),
			_enum("right_status_effect", SentencePart.OptionSource.STATUS_EFFECT),
			_text(" stacks"),
		])

	_save("all_stacks_vs_value", "Status", "Total stacks vs value", STATUS_CMP,
		{"compare_mode": 1, "check_all": true}, "", [
			_enum("left_target", SentencePart.OptionSource.TARGET),
			_text(" total status stacks "),
			_enum("comparator", SentencePart.OptionSource.COMPARATOR),
			_number("right_value", 0, 99, 1, 1.0, ""),
		])

	_save("hp_vs_percent", "HP", "HP vs percent", HP_CMP,
		{"compare_mode": 1, "use_percent": true}, "", [
			_enum("left_target", SentencePart.OptionSource.TARGET),
			_text(" HP "),
			_enum("comparator", SentencePart.OptionSource.COMPARATOR),
			_number("right_value", 0, 100, 5, 0.01, "%"),
		])

	_save("hp_vs_value", "HP", "HP vs value", HP_CMP,
		{"compare_mode": 1, "use_percent": false}, "", [
			_enum("left_target", SentencePart.OptionSource.TARGET),
			_text(" HP "),
			_enum("comparator", SentencePart.OptionSource.COMPARATOR),
			_number("right_value", 0, 999, 1, 1.0, " HP"),
		])

	_save("hp_vs_hp", "HP", "HP vs HP", HP_CMP,
		{"compare_mode": 0, "use_percent": true}, "", [
			_enum("left_target", SentencePart.OptionSource.TARGET),
			_text(" HP "),
			_enum("comparator", SentencePart.OptionSource.COMPARATOR),
			_enum("right_target", SentencePart.OptionSource.TARGET),
			_text(" HP"),
		])

	_save("stat_vs_value", "Stat", "Stat vs value", STAT_CMP,
		{"compare_mode": 1}, "", [
			_enum("left_target", SentencePart.OptionSource.TARGET),
			_enum("left_stat", SentencePart.OptionSource.FAMILIAR_STAT),
			_text(" "),
			_enum("comparator", SentencePart.OptionSource.COMPARATOR),
			_number("right_value", 0, 99, 1, 1.0, ""),
		])

	_save("stat_vs_stat", "Stat", "Stat vs stat", STAT_CMP,
		{"compare_mode": 0}, "", [
			_enum("left_target", SentencePart.OptionSource.TARGET),
			_enum("left_stat", SentencePart.OptionSource.FAMILIAR_STAT),
			_text(" "),
			_enum("comparator", SentencePart.OptionSource.COMPARATOR),
			_enum("right_target", SentencePart.OptionSource.TARGET),
			_enum("right_stat", SentencePart.OptionSource.FAMILIAR_STAT),
		])

	_save("not", "Logic", "NOT", NOT_CND, {}, "wrapped_condition", [])

	print("generated 9 block definitions")
	quit()

func _text(value: String) -> SentencePart:
	var part := SentencePart.new()
	part.kind = SentencePart.Kind.TEXT
	part.text = value
	return part

func _enum(property: String, source: SentencePart.OptionSource) -> SentencePart:
	var part := SentencePart.new()
	part.kind = SentencePart.Kind.ENUM_CHOICE
	part.property = StringName(property)
	part.option_source = source
	return part

func _number(property: String, min_v: float, max_v: float, step: float, scale: float, suffix: String) -> SentencePart:
	var part := SentencePart.new()
	part.kind = SentencePart.Kind.NUMBER
	part.property = StringName(property)
	part.min_value = min_v
	part.max_value = max_v
	part.step = step
	part.display_scale = scale
	part.suffix = suffix
	return part

func _save(file_name: String, category: String, label: String, script_path: String,
		fixed: Dictionary, body_property: String, sentence: Array) -> void:
	var definition := ConditionBlockDefinition.new()
	definition.category = category
	definition.block_label = label
	definition.condition_script = load(script_path)
	definition.fixed_values = fixed
	definition.body_property = StringName(body_property)

	var typed: Array[SentencePart] = []
	for part in sentence:
		typed.append(part)
	definition.sentence = typed

	var path: String = "%s/%s.tres" % [OUT_DIR, file_name]
	var error: int = ResourceSaver.save(definition, path)
	if error != OK:
		push_error("failed to save %s (error %d)" % [path, error])
```

- [ ] **Step 4: Run the generator**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/_generate_builder_blocks.gd
ls resources/priority_builder/blocks/
```

Expected: `generated 9 block definitions`, and nine `.tres` files listed.

- [ ] **Step 5: Add the definition checks to the verify script**

In `scripts/_verify_priority_builder.gd`, add the call `_check_block_definitions()` to `_initialize()` after `_check_technique_describe()`, and append:

```gdscript
## Explicit property-list lookup rather than the `in` operator, which is
## ambiguous on Objects. This assertion is what catches a misspelled
## SentencePart.property -- Object.set() on a name that does not exist fails
## silently, so without this a bad definition would just never write.
func _has_property(object: Object, property: StringName) -> bool:
	for entry in object.get_property_list():
		if StringName(entry["name"]) == property:
			return true
	return false

func _check_block_definitions() -> void:
	var names: Array[String] = [
		"status_vs_value", "status_vs_status", "all_stacks_vs_value",
		"hp_vs_percent", "hp_vs_value", "hp_vs_hp",
		"stat_vs_value", "stat_vs_stat", "not",
	]

	for name in names:
		var path: String = "res://resources/priority_builder/blocks/%s.tres" % name
		var definition: ConditionBlockDefinition = load(path)
		_expect(definition != null, "could not load %s" % path)
		if definition == null:
			continue
		_expect(definition.block_label != "", "%s has no block_label" % name)
		_expect(definition.condition_script != null, "%s has no condition_script" % name)

		# Every definition must produce a working Condition, and every
		# sentence part must name a property that actually exists on it --
		# a typo here would silently no-op via Object.set().
		var condition: Condition = definition.condition_script.new()
		_expect(condition is Condition, "%s script is not a Condition" % name)

		for key in definition.fixed_values:
			_expect(_has_property(condition, StringName(key)),
				"%s fixed_values names missing property '%s'" % [name, key])

		for part in definition.sentence:
			if part.kind == SentencePart.Kind.TEXT:
				continue
			_expect(part.property != &"", "%s has a non-TEXT part with no property" % name)
			_expect(_has_property(condition, part.property),
				"%s sentence names missing property '%s'" % [name, part.property])

	# The wrapper block is the only one with body_property set.
	var not_definition: ConditionBlockDefinition = load("res://resources/priority_builder/blocks/not.tres")
	if not_definition != null:
		_expect(not_definition.body_property == &"wrapped_condition",
			"not.tres body_property should be wrapped_condition, got '%s'" % not_definition.body_property)
		_expect(not_definition.sentence.is_empty(), "not.tres should have an empty sentence")
```

- [ ] **Step 6: Run the verification**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/_verify_priority_builder.gd
```

Expected: `ALL CHECKS PASSED`. The `part.property in condition` check is the important one — it catches a misspelled property that `Object.set()` would otherwise swallow silently.

- [ ] **Step 7: Delete the generator and commit**

```bash
rm scripts/_generate_builder_blocks.gd
rm -f scripts/_generate_builder_blocks.gd.uid
git add scripts/priority_builder/sentence_part.gd scripts/priority_builder/condition_block_definition.gd resources/priority_builder/blocks scripts/_verify_priority_builder.gd
git commit -m "feat: condition block descriptor resources + nine definitions"
```

---

### Task 3: `ConditionBlock` — descriptor to widgets to `Condition`

Spec §4, §6.1. The generic block. No UI chrome yet beyond what the sentence needs; drop zones come in Task 8.

**Files:**
- Create: `scripts/priority_builder/condition_block.gd`
- Create: `scenes/priority_builder/condition_block.tscn`
- Modify: `scripts/_verify_priority_builder.gd`

**Interfaces:**
- Consumes: `ConditionBlockDefinition`, `SentencePart` (Task 2).
- Produces: `ConditionBlock` (extends `PanelContainer`) with `setup(definition: ConditionBlockDefinition) -> void`, `build_condition() -> Condition`, `is_complete() -> bool`, `is_wrapper() -> bool`, `body_children() -> Array[ConditionBlock]`, `definition: ConditionBlockDefinition`, `body: VBoxContainer`, and `signal structure_changed`.

Scene structure for `condition_block.tscn`:

```
ConditionBlock (PanelContainer)          condition_block.gd
└─ Rows (VBoxContainer)
   ├─ Sentence (HBoxContainer)           widgets built at runtime
   └─ Body (VBoxContainer)               nested blocks; drop zone in Task 8
```

- [ ] **Step 1: Write the failing verification**

Add `_check_condition_block()` to `_initialize()` and append:

```gdscript
const CONDITION_BLOCK_SCENE: String = "res://scenes/priority_builder/condition_block.tscn"

## Two combatants for is_met() checks. twerpent has max_hp 75, guubal is the
## other authored familiar.
func _make_pair() -> Array:
	var user := Combatant.new(load("res://resources/familiars/twerpent.tres"))
	var target := Combatant.new(load("res://resources/familiars/guubal.tres"))
	return [user, target]

func _add_status(combatant: Combatant, effect: Status.StatusEffect, stacks: int) -> void:
	# Declared, not applied -- bypasses add_status()'s Ward/on_applied hooks.
	# Mirrors state_probe.gd; see spec section 8.1.
	var status: Status = Status.create(effect, stacks)
	status.owner = combatant
	combatant.statuses.append(status)

func _check_condition_block() -> void:
	var scene: PackedScene = load(CONDITION_BLOCK_SCENE)
	_expect(scene != null, "could not load condition_block.tscn")
	if scene == null:
		return

	var definition: ConditionBlockDefinition = load("res://resources/priority_builder/blocks/status_vs_value.tres")

	var block_a: ConditionBlock = scene.instantiate()
	root.add_child(block_a)
	block_a.setup(definition)

	var block_b: ConditionBlock = scene.instantiate()
	root.add_child(block_b)
	block_b.setup(definition)

	# The aliasing check: two blocks from one shared definition must own
	# separate Condition instances. See DECISIONS.md on shared resources.
	var condition_a: Condition = block_a.build_condition()
	var condition_b: Condition = block_b.build_condition()
	_expect(condition_a != condition_b, "two blocks from one definition share a Condition instance")
	_expect(condition_a is StatusComparisonCondition, "status_vs_value did not build a StatusComparisonCondition")

	# fixed_values applied: compare_mode FLAT_VALUE is 1.
	_expect(condition_a.compare_mode == StatusComparisonCondition.CompareMode.FLAT_VALUE,
		"fixed_values did not set compare_mode to FLAT_VALUE")

	# Drive the widgets and confirm they reach the Condition. Acid is
	# StatusEffect index 3; LESS is comparator index 2.
	block_a.set_property_for_test(&"left_status_effect", Status.StatusEffect.ACID)
	block_a.set_property_for_test(&"left_target", 1)  # TARGET
	block_a.set_property_for_test(&"comparator", StatusComparisonCondition.Comparator.LESS)
	block_a.set_property_for_test(&"right_value", 5)

	var condition: StatusComparisonCondition = block_a.build_condition()
	_expect(condition.left_status_effect == Status.StatusEffect.ACID, "left_status_effect did not round-trip")
	_expect(condition.right_value == 5, "right_value did not round-trip, got %s" % condition.right_value)

	var pair: Array = _make_pair()
	var user: Combatant = pair[0]
	var target: Combatant = pair[1]
	_expect(condition.is_met(user, target), "target with 0 Acid should satisfy 'Acid < 5'")
	_add_status(target, Status.StatusEffect.ACID, 6)
	_expect(not condition.is_met(user, target), "target with 6 Acid should fail 'Acid < 5'")
	print("  status_vs_value describe: %s" % condition.describe())

	# The float-into-int check from spec section 4.2. The percent block's
	# display_scale is 0.01, so a widget reading 25 must store 0.25 on a
	# float property -- and an int-typed right_value must survive the same
	# set() path without becoming garbage.
	var hp_definition: ConditionBlockDefinition = load("res://resources/priority_builder/blocks/hp_vs_percent.tres")
	var hp_block: ConditionBlock = scene.instantiate()
	root.add_child(hp_block)
	hp_block.setup(hp_definition)
	hp_block.set_property_for_test(&"right_value", 0.25)
	hp_block.set_property_for_test(&"left_target", 0)  # SELF
	hp_block.set_property_for_test(&"comparator", HpComparisonCondition.Comparator.LESS)
	var hp_condition: HpComparisonCondition = hp_block.build_condition()
	_expect(is_equal_approx(hp_condition.right_value, 0.25),
		"HP percent should store 0.25, got %s" % hp_condition.right_value)

	var int_block: ConditionBlock = scene.instantiate()
	root.add_child(int_block)
	int_block.setup(definition)
	int_block.set_property_for_test(&"right_value", 7.0)
	var int_condition: StatusComparisonCondition = int_block.build_condition()
	_expect(int_condition.right_value == 7,
		"float 7.0 into int right_value should convert to 7, got %s" % int_condition.right_value)

	_expect(not block_a.is_wrapper(), "status_vs_value should not be a wrapper")
	_expect(block_a.is_complete(), "a leaf block with no body should be complete")

	var not_block: ConditionBlock = scene.instantiate()
	root.add_child(not_block)
	not_block.setup(load("res://resources/priority_builder/blocks/not.tres"))
	_expect(not_block.is_wrapper(), "not.tres should produce a wrapper block")
	_expect(not not_block.is_complete(), "an empty wrapper must be incomplete")
```

- [ ] **Step 2: Run it to verify it fails**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/_verify_priority_builder.gd
```

Expected: FAIL — `condition_block.tscn` does not exist yet.

- [ ] **Step 3: Write `condition_block.gd`**

```gdscript
class_name ConditionBlock
extends PanelContainer

## One condition in the builder, rendered as a fill-in-the-blank sentence
## built from its ConditionBlockDefinition. Owns exactly one Condition
## instance, minted fresh in setup() -- the definition is shared and stays
## read-only, so editing this block's dropdowns can never reach into another
## block or into an authored .tres. See DECISIONS.md on shared resources.
##
## Nesting a block inside `body` means AND. That is presentation only:
## SegmentList flattens the tree pre-order into PriorityRule.conditions,
## because an ANDed array is already what that field means. The exception is
## a wrapper block (body_property set, only NOT today), whose single body
## child is assigned to that property instead. See spec section 7.

signal structure_changed

@onready var sentence_row: HBoxContainer = $Rows/Sentence
@onready var body: VBoxContainer = $Rows/BodyMargin/Body

var definition: ConditionBlockDefinition

var _condition: Condition
## property -> the Control editing it, so build_condition() can re-read
## widget values without caching state that could drift.
var _widgets: Dictionary = {}

func setup(block_definition: ConditionBlockDefinition) -> void:
	definition = block_definition
	_condition = definition.condition_script.new()

	for key in definition.fixed_values:
		_condition.set(key, definition.fixed_values[key])

	for part in definition.sentence:
		match part.kind:
			SentencePart.Kind.TEXT:
				_add_text(part)
			SentencePart.Kind.ENUM_CHOICE:
				_add_enum_choice(part)
			SentencePart.Kind.NUMBER:
				_add_number(part)

	if definition.sentence.is_empty():
		var label := Label.new()
		label.text = definition.block_label
		sentence_row.add_child(label)

	if is_wrapper():
		_add_body_placeholder()

func _add_text(part: SentencePart) -> void:
	var label := Label.new()
	label.text = part.text
	sentence_row.add_child(label)

func _add_enum_choice(part: SentencePart) -> void:
	var option := OptionButton.new()
	for entry in _options_for(part.option_source):
		option.add_item(entry["label"])
		option.set_item_metadata(option.item_count - 1, entry["value"])

	# Show whatever the condition already holds (its own declared default,
	# or a fixed_values entry) rather than forcing index 0.
	var current: Variant = _condition.get(part.property)
	for i in option.item_count:
		if option.get_item_metadata(i) == current:
			option.select(i)
			break

	option.item_selected.connect(func(_index: int) -> void: structure_changed.emit())
	sentence_row.add_child(option)
	_widgets[part.property] = option

func _add_number(part: SentencePart) -> void:
	var spin := SpinBox.new()
	spin.min_value = part.min_value
	spin.max_value = part.max_value
	spin.step = part.step
	spin.suffix = part.suffix

	# The condition's stored value is scaled; the widget shows the unscaled
	# one (0.25 stored -> 25 shown for a percentage).
	var current: Variant = _condition.get(part.property)
	if current != null and part.display_scale != 0.0:
		spin.value = float(current) / part.display_scale

	spin.value_changed.connect(func(_value: float) -> void: structure_changed.emit())
	sentence_row.add_child(spin)
	_widgets[part.property] = spin

func _add_body_placeholder() -> void:
	var label := Label.new()
	label.name = "BodyPlaceholder"
	label.text = "drop one condition here"
	label.modulate = Color(1, 1, 1, 0.5)
	body.add_child(label)

## Option tables for each OptionSource. Values are stored explicitly, never
## derived from display order -- Comparator's declared order is GREATER,
## GREATER_OR_EQUAL, LESS, LESS_OR_EQUAL, EQUAL, which is not the order a
## person wants to read.
func _options_for(source: SentencePart.OptionSource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	match source:
		SentencePart.OptionSource.TARGET:
			entries.append({"label": "user's", "value": 0})
			entries.append({"label": "target's", "value": 1})
		SentencePart.OptionSource.COMPARATOR:
			entries.append({"label": "<", "value": 2})
			entries.append({"label": "<=", "value": 3})
			entries.append({"label": "==", "value": 4})
			entries.append({"label": ">=", "value": 1})
			entries.append({"label": ">", "value": 0})
		SentencePart.OptionSource.STATUS_EFFECT:
			for effect in Status.StatusEffect.values():
				if effect == Status.StatusEffect.NONE:
					continue
				entries.append({
					"label": String(Status.status_effect_id(effect)).capitalize(),
					"value": effect,
				})
		SentencePart.OptionSource.FAMILIAR_STAT:
			for stat in Familiar.Stat.values():
				entries.append({"label": Familiar.stat_name(stat), "value": stat})

	return entries

func is_wrapper() -> bool:
	return definition != null and definition.body_property != &""

## Nested condition blocks, in display order.
func body_children() -> Array[ConditionBlock]:
	var blocks: Array[ConditionBlock] = []
	for child in body.get_children():
		if child is ConditionBlock:
			blocks.append(child)
	return blocks

## A wrapper needs exactly one body child to be runnable -- an empty one is
## the null deref at not_condition.gd:7. Leaves are always complete.
func is_complete() -> bool:
	if not is_wrapper():
		for child in body_children():
			if not child.is_complete():
				return false
		return true

	var children: Array[ConditionBlock] = body_children()
	if children.size() != 1:
		return false
	return children[0].is_complete()

## Re-reads every widget onto the owned Condition and returns it. Called on
## each compile rather than trusting cached writes, so the widget row is the
## single source of truth.
func build_condition() -> Condition:
	for property in _widgets:
		var widget: Control = _widgets[property]
		if widget is OptionButton:
			_condition.set(property, widget.get_item_metadata(widget.selected))
		elif widget is SpinBox:
			var part: SentencePart = _part_for(property)
			var scale: float = part.display_scale if part != null else 1.0
			_condition.set(property, widget.value * scale)

	if is_wrapper():
		var children: Array[ConditionBlock] = body_children()
		if children.size() == 1:
			_condition.set(definition.body_property, children[0].build_condition())

	return _condition

func _part_for(property: StringName) -> SentencePart:
	for part in definition.sentence:
		if part.property == property:
			return part
	return null

## Test seam for headless verification -- drives a widget the way a click
## would, so build_condition()'s real read path is what gets exercised.
func set_property_for_test(property: StringName, value: Variant) -> void:
	var widget: Control = _widgets.get(property)
	if widget == null:
		return
	if widget is SpinBox:
		var part: SentencePart = _part_for(property)
		var scale: float = part.display_scale if part != null else 1.0
		widget.value = float(value) / scale
	elif widget is OptionButton:
		for i in widget.item_count:
			if widget.get_item_metadata(i) == value:
				widget.select(i)
				return
```

- [ ] **Step 4: Create `condition_block.tscn`**

Build it in the editor, or write the file directly:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/priority_builder/condition_block.gd" id="1"]

[node name="ConditionBlock" type="PanelContainer"]
mouse_filter = 0
script = ExtResource("1")

[node name="Rows" type="VBoxContainer" parent="."]
mouse_filter = 2

[node name="Sentence" type="HBoxContainer" parent="Rows"]
mouse_filter = 2

[node name="BodyMargin" type="MarginContainer" parent="Rows"]
mouse_filter = 2
theme_override_constants/margin_left = 16

[node name="Body" type="VBoxContainer" parent="Rows/BodyMargin"]
mouse_filter = 2
```

The 16px left margin on `BodyMargin` is what makes nesting read as containment — without it a nested block looks like a sibling. `mouse_filter = 2` is `IGNORE` on every container so the `ConditionBlock` root is the hit target and `at_position` stays block-relative (Task 8 depends on this); `mouse_filter = 0` is `STOP` on the root so it receives the drag virtuals.

Note the resulting path: `condition_block.gd`'s `body` accessor must be `@onready var body: VBoxContainer = $Rows/BodyMargin/Body`, not `$Rows/Body`. Update it in Step 3's script before running the check — `--check-only` will catch it if you forget.

- [ ] **Step 5: Run both verifications**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/_verify_priority_builder.gd
```

Expected: `ALL CHECKS PASSED`. If the float-into-int check fails, add `as_integer: bool` to `SentencePart` and branch in `build_condition()` — per spec §4.2 that is the designed fallback, not a new part kind.

- [ ] **Step 6: Commit**

```bash
git add scripts/priority_builder/condition_block.gd scenes/priority_builder/condition_block.tscn scripts/_verify_priority_builder.gd
git commit -m "feat: descriptor-driven ConditionBlock"
```

---

### Task 4: `TechniqueBlock`

Spec §5, §9. A placed technique, with a tooltip through the existing `TooltipLayer`.

**Files:**
- Create: `scripts/priority_builder/technique_block.gd`
- Create: `scenes/priority_builder/technique_block.tscn`

**Interfaces:**
- Consumes: `Technique.describe()` (Task 1).
- Produces: `TechniqueBlock` (extends `PanelContainer`) with `setup(technique_data: Technique, layer: TooltipLayer) -> void` and `technique: Technique`.

- [ ] **Step 1: Write `technique_block.gd`**

```gdscript
class_name TechniqueBlock
extends PanelContainer

## A technique placed in a rule slot. Unlike ConditionBlock this holds a
## reference to the shared Technique .tres rather than a fresh copy: the
## builder only ever references a technique, never edits one, so there is
## nothing to alias.

@onready var name_label: Label = $NameLabel

var technique: Technique

var _tooltip_layer: TooltipLayer

func setup(technique_data: Technique, layer: TooltipLayer) -> void:
	technique = technique_data
	_tooltip_layer = layer
	name_label.text = technique.technique_name

	# Same wiring battle_controller.gd:94-95 uses for upgrade buttons --
	# TooltipLayer replaces Godot's built-in tooltip_text entirely.
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if _tooltip_layer != null and technique != null:
		_tooltip_layer.hover_started(self, technique.describe())

func _on_mouse_exited() -> void:
	if _tooltip_layer != null:
		_tooltip_layer.hover_ended(self)
```

- [ ] **Step 2: Create `technique_block.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/priority_builder/technique_block.gd" id="1"]

[node name="TechniqueBlock" type="PanelContainer"]
mouse_filter = 0
script = ExtResource("1")

[node name="NameLabel" type="Label" parent="."]
text = "Technique"
```

`mouse_filter = 0` is `STOP`, required for `mouse_entered`/`mouse_exited` to fire and for the drag virtuals in Task 8.

- [ ] **Step 3: Run the parse check**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/priority_builder/technique_block.gd scenes/priority_builder/technique_block.tscn
git commit -m "feat: TechniqueBlock with describe() tooltip"
```

---

### Task 5: `RuleSegment` — one rule slot

Spec §6.4, §7. Where empty-vs-complete and the pre-order flatten live.

**Files:**
- Create: `scripts/priority_builder/rule_segment.gd`
- Create: `scenes/priority_builder/rule_segment.tscn`
- Modify: `scripts/_verify_priority_builder.gd`

**Interfaces:**
- Consumes: `ConditionBlock` (Task 3), `TechniqueBlock` (Task 4).
- Produces: `RuleSegment` (extends `PanelContainer`) with `build_rule() -> PriorityRule`, `is_empty() -> bool`, `is_complete() -> bool`, `set_verdict(badge: String, detail: String) -> void`, `condition_body: VBoxContainer`, `technique_slot: VBoxContainer`, `signal structure_changed`, `signal delete_requested(segment: RuleSegment)`.

Scene structure:

```
RuleSegment (PanelContainer)             rule_segment.gd
└─ Rows (VBoxContainer)
   ├─ Header (HBoxContainer)
   │  ├─ Handle (Label "≡")              drag-to-reorder grip (Task 8)
   │  ├─ IndexLabel (Label)
   │  ├─ VerdictLabel (Label)
   │  ├─ Spacer (Control, expand)
   │  └─ DeleteButton (Button "×")
   ├─ ConditionBody (VBoxContainer)
   └─ TechniqueSlot (VBoxContainer)
```

- [ ] **Step 1: Write the failing verification**

Add `_check_rule_segment()` to `_initialize()` and append:

```gdscript
const RULE_SEGMENT_SCENE: String = "res://scenes/priority_builder/rule_segment.tscn"
const TECHNIQUE_BLOCK_SCENE: String = "res://scenes/priority_builder/technique_block.tscn"

func _new_condition_block(definition_name: String) -> ConditionBlock:
	var scene: PackedScene = load(CONDITION_BLOCK_SCENE)
	var block: ConditionBlock = scene.instantiate()
	root.add_child(block)
	block.setup(load("res://resources/priority_builder/blocks/%s.tres" % definition_name))
	return block

func _check_rule_segment() -> void:
	var scene: PackedScene = load(RULE_SEGMENT_SCENE)
	_expect(scene != null, "could not load rule_segment.tscn")
	if scene == null:
		return

	var segment: RuleSegment = scene.instantiate()
	root.add_child(segment)

	_expect(segment.is_empty(), "a fresh segment should be empty")
	_expect(not segment.is_complete(), "a fresh segment should be incomplete")

	# A technique alone is the catch-all shape: non-empty, complete, and
	# compiles to an empty conditions array (vacuously true). See
	# priority_rule.gd:7.
	var technique_block: TechniqueBlock = load(TECHNIQUE_BLOCK_SCENE).instantiate()
	segment.technique_slot.add_child(technique_block)
	technique_block.setup(load("res://resources/techniques/attack.tres"), null)

	_expect(not segment.is_empty(), "a segment with a technique is not empty")
	_expect(segment.is_complete(), "a technique-only segment should be complete")

	var catch_all: PriorityRule = segment.build_rule()
	_expect(catch_all.conditions.is_empty(), "catch-all rule should have no conditions")
	_expect(catch_all.technique != null, "catch-all rule should have a technique")

	# Pre-order flatten: A holding B in its body, then C alongside A, must
	# compile to [A, B, C]. Order does not change whether the rule fires,
	# but choose_technique() reports the first failing condition, so
	# pre-order is what makes the reported reason match top-to-bottom
	# reading. See spec section 7.
	var block_a: ConditionBlock = _new_condition_block("status_vs_value")
	var block_b: ConditionBlock = _new_condition_block("hp_vs_percent")
	var block_c: ConditionBlock = _new_condition_block("stat_vs_value")

	root.remove_child(block_a)
	root.remove_child(block_b)
	root.remove_child(block_c)
	segment.condition_body.add_child(block_a)
	block_a.body.add_child(block_b)
	segment.condition_body.add_child(block_c)

	var rule: PriorityRule = segment.build_rule()
	_expect(rule.conditions.size() == 3, "expected 3 flattened conditions, got %d" % rule.conditions.size())
	if rule.conditions.size() == 3:
		_expect(rule.conditions[0] is StatusComparisonCondition, "conditions[0] should be the status block (A)")
		_expect(rule.conditions[1] is HpComparisonCondition, "conditions[1] should be the nested HP block (B)")
		_expect(rule.conditions[2] is StatComparisonCondition, "conditions[2] should be the sibling stat block (C)")

	# A wrapper assigns its child to body_property and must NOT also append
	# it to conditions[] -- otherwise the child would be ANDed in unnegated
	# alongside its own negation.
	var wrapper_segment: RuleSegment = scene.instantiate()
	root.add_child(wrapper_segment)
	var wrapper_technique: TechniqueBlock = load(TECHNIQUE_BLOCK_SCENE).instantiate()
	wrapper_segment.technique_slot.add_child(wrapper_technique)
	wrapper_technique.setup(load("res://resources/techniques/attack.tres"), null)

	var not_block: ConditionBlock = _new_condition_block("not")
	root.remove_child(not_block)
	wrapper_segment.condition_body.add_child(not_block)

	_expect(not wrapper_segment.is_complete(), "a segment with an empty NOT must be incomplete")

	var wrapped: ConditionBlock = _new_condition_block("hp_vs_percent")
	root.remove_child(wrapped)
	not_block.body.add_child(wrapped)

	_expect(wrapper_segment.is_complete(), "a filled NOT should make the segment complete")

	var wrapper_rule: PriorityRule = wrapper_segment.build_rule()
	_expect(wrapper_rule.conditions.size() == 1,
		"a NOT wrapping one condition should flatten to 1 condition, got %d" % wrapper_rule.conditions.size())
	if wrapper_rule.conditions.size() == 1:
		var not_condition: Condition = wrapper_rule.conditions[0]
		_expect(not_condition is NotCondition, "conditions[0] should be the NotCondition")
		_expect(not_condition.wrapped_condition is HpComparisonCondition,
			"NotCondition.wrapped_condition should be the HP block")

		# And the negation must actually invert.
		var pair: Array = _make_pair()
		var user: Combatant = pair[0]
		var target: Combatant = pair[1]
		var inner: Condition = not_condition.wrapped_condition
		_expect(not_condition.is_met(user, target) != inner.is_met(user, target),
			"NotCondition should invert its wrapped condition")
		print("  NOT describe: %s" % not_condition.describe())
```

- [ ] **Step 2: Run it to verify it fails**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/_verify_priority_builder.gd
```

Expected: FAIL — `rule_segment.tscn` does not exist.

- [ ] **Step 3: Write `rule_segment.gd`**

```gdscript
class_name RuleSegment
extends PanelContainer

## One rule slot: an ANDed set of condition blocks plus one technique,
## compiling to a single PriorityRule.
##
## Two predicates that must not be conflated (spec section 6.4):
##   is_empty()    -- nothing in it at all. Gates the Add Slot button.
##   is_complete() -- runnable. Gates inclusion in the probe.
## A slot with conditions but no technique is non-empty AND incomplete.

signal structure_changed
signal delete_requested(segment: RuleSegment)

@onready var index_label: Label = $Rows/Header/IndexLabel
@onready var verdict_label: Label = $Rows/Header/VerdictLabel
@onready var delete_button: Button = $Rows/Header/DeleteButton
@onready var handle: Label = $Rows/Header/Handle
@onready var condition_body: VBoxContainer = $Rows/ConditionBody
@onready var technique_slot: VBoxContainer = $Rows/TechniqueSlot

func _ready() -> void:
	delete_button.pressed.connect(func() -> void: delete_requested.emit(self))

	# Blocks are added to condition_body / technique_slot, NOT to this node
	# directly, so these must be connected on those containers -- connecting
	# them on `self` would never fire and the probe would never update.
	for container in [condition_body, technique_slot]:
		container.child_entered_tree.connect(_on_structure_changed)
		container.child_exiting_tree.connect(_on_structure_changed)

func _on_structure_changed(_node: Node) -> void:
	structure_changed.emit()

func technique_block() -> TechniqueBlock:
	for child in technique_slot.get_children():
		if child is TechniqueBlock:
			return child
	return null

## Top-level condition blocks, in display order. Nested ones are reached
## through each block's own body_children().
func condition_blocks() -> Array[ConditionBlock]:
	var blocks: Array[ConditionBlock] = []
	for child in condition_body.get_children():
		if child is ConditionBlock:
			blocks.append(child)
	return blocks

func is_empty() -> bool:
	return technique_block() == null and condition_blocks().is_empty()

## Runnable: has a technique, and every wrapper in the tree has its body
## filled. Both failures are latent null derefs in existing code --
## combatant.gd:189 and not_condition.gd:7 -- so an incomplete segment is
## excluded from evaluation rather than passed to the evaluator.
func is_complete() -> bool:
	if technique_block() == null:
		return false
	for block in condition_blocks():
		if not block.is_complete():
			return false
	return true

## Flattens this slot's block tree into one PriorityRule. Nesting means AND,
## which is already what PriorityRule.conditions means, so the tree
## collapses depth-first pre-order into that flat array. A wrapper block is
## the exception: it takes its single body child into its own
## body_property and is appended alone. See spec section 7.
func build_rule() -> PriorityRule:
	var rule := PriorityRule.new()

	var technique_holder: TechniqueBlock = technique_block()
	rule.technique = technique_holder.technique if technique_holder != null else null

	var conditions: Array[Condition] = []
	for block in condition_blocks():
		_collect(block, conditions)
	rule.conditions = conditions

	return rule

func _collect(block: ConditionBlock, into: Array[Condition]) -> void:
	# build_condition() already folds a wrapper's single body child into
	# body_property, so a wrapper is appended without recursing -- recursing
	# would ALSO append the child unnegated, ANDing a condition alongside
	# its own negation.
	into.append(block.build_condition())

	if block.is_wrapper():
		return

	for child in block.body_children():
		_collect(child, into)

func set_index(index: int) -> void:
	index_label.text = str(index)

func set_verdict(badge: String, detail: String) -> void:
	verdict_label.text = badge if detail == "" else "%s — %s" % [badge, detail]
```

- [ ] **Step 4: Create `rule_segment.tscn`**

Matching the structure above. `DeleteButton` text `×`, `Handle` text `≡`, `VerdictLabel` starts empty, and `Spacer` is a `Control` with `size_flags_horizontal = 3` (expand+fill) so the delete button sits right. Give `RuleSegment` `mouse_filter = 0`.

- [ ] **Step 5: Run both verifications**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/_verify_priority_builder.gd
```

Expected: `ALL CHECKS PASSED`. The `[A, B, C]` ordering assertion and the wrapper's single-condition assertion are the two that matter most — they are spec §7 and §7.1 respectively.

- [ ] **Step 6: Commit**

```bash
git add scripts/priority_builder/rule_segment.gd scenes/priority_builder/rule_segment.tscn scripts/_verify_priority_builder.gd
git commit -m "feat: RuleSegment with pre-order condition flattening"
```

---

### Task 6: `SegmentList` — ordering and compilation

Spec §6.3, §6.4, §7. The ordered list and the compile entry point.

**Files:**
- Create: `scripts/priority_builder/segment_list.gd`
- Modify: `scripts/_verify_priority_builder.gd`

**Interfaces:**
- Consumes: `RuleSegment` (Task 5).
- Produces: `SegmentList` (extends `VBoxContainer`) with `add_segment() -> RuleSegment`, `has_empty_segment() -> bool`, `compile() -> Dictionary`, `segments() -> Array[RuleSegment]`, `insert_index_for_y(y: float) -> int`, `signal structure_changed`.

`compile()` returns `{"rules": Array[PriorityRule], "segments": Array[RuleSegment], "incomplete": Array[RuleSegment]}`, where `rules[i]` corresponds to `segments[i]`. The pairing is built in one function so the index alignment is local and verifiable — unlike inferring it from `choose_technique()`'s internal append order, which spec §8.2 rejects.

- [ ] **Step 1: Write the failing verification**

Add `_check_segment_list()` to `_initialize()` and append:

```gdscript
func _filled_segment(technique_path: String) -> RuleSegment:
	var segment: RuleSegment = load(RULE_SEGMENT_SCENE).instantiate()
	root.add_child(segment)
	var block: TechniqueBlock = load(TECHNIQUE_BLOCK_SCENE).instantiate()
	segment.technique_slot.add_child(block)
	block.setup(load(technique_path), null)
	root.remove_child(segment)
	return segment

func _check_segment_list() -> void:
	var list := SegmentList.new()
	root.add_child(list)

	_expect(not list.has_empty_segment(), "an empty list has no empty segment")

	var fresh: RuleSegment = list.add_segment()
	_expect(fresh != null, "add_segment() returned null")
	_expect(list.has_empty_segment(), "the freshly added segment should count as empty")

	var first: RuleSegment = _filled_segment("res://resources/techniques/acid_bath.tres")
	var second: RuleSegment = _filled_segment("res://resources/techniques/venom_strike.tres")
	list.add_child(first)
	list.add_child(second)

	# Display order is compile order.
	var compiled: Dictionary = list.compile()
	var rules: Array[PriorityRule] = compiled["rules"]
	_expect(rules.size() == 2, "expected 2 complete rules, got %d" % rules.size())
	if rules.size() == 2:
		_expect(rules[0].technique.technique_name == "Acid Bath",
			"first rule should be Acid Bath, got %s" % rules[0].technique.technique_name)
		_expect(rules[1].technique.technique_name == "Venom Strike",
			"second rule should be Venom Strike, got %s" % rules[1].technique.technique_name)

	# The incomplete segment is excluded from rules but reported, so the UI
	# can badge it -- see spec section 8.3.
	var incomplete: Array[RuleSegment] = compiled["incomplete"]
	_expect(incomplete.size() == 1, "the empty segment should be reported incomplete")
	_expect(incomplete.has(fresh), "the reported incomplete segment should be the empty one")

	# rules[i] must correspond to segments[i].
	var paired: Array[RuleSegment] = compiled["segments"]
	_expect(paired.size() == rules.size(), "segments and rules must be index-aligned")
	if paired.size() == 2:
		_expect(paired[0] == first, "segments[0] should be the first segment")

	# Reordering by move_child changes compile order, which is the whole
	# point of the screen.
	list.move_child(second, first.get_index())
	var reordered: Array[PriorityRule] = list.compile()["rules"]
	if reordered.size() == 2:
		_expect(reordered[0].technique.technique_name == "Venom Strike",
			"after reorder the first rule should be Venom Strike, got %s" % reordered[0].technique.technique_name)
```

- [ ] **Step 2: Run it to verify it fails**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/_verify_priority_builder.gd
```

Expected: FAIL — `SegmentList` is not defined.

- [ ] **Step 3: Write `segment_list.gd`**

```gdscript
class_name SegmentList
extends VBoxContainer

## The ordered list of rule slots, and the single place the block tree turns
## into Array[PriorityRule]. Display order is priority order.

signal structure_changed

const RULE_SEGMENT_SCENE: PackedScene = preload("res://scenes/priority_builder/rule_segment.tscn")

func segments() -> Array[RuleSegment]:
	var found: Array[RuleSegment] = []
	for child in get_children():
		if child is RuleSegment:
			found.append(child)
	return found

func add_segment() -> RuleSegment:
	var segment: RuleSegment = RULE_SEGMENT_SCENE.instantiate()
	add_child(segment)
	segment.structure_changed.connect(_on_segment_changed)
	segment.delete_requested.connect(_on_delete_requested)
	_refresh_indices()
	structure_changed.emit()
	return segment

func _on_segment_changed() -> void:
	_refresh_indices()
	structure_changed.emit()

func _on_delete_requested(segment: RuleSegment) -> void:
	segment.queue_free()
	# queue_free() is deferred, so the segment is still a child right now --
	# recompute after it actually leaves the tree.
	await segment.tree_exited
	_refresh_indices()
	structure_changed.emit()

func _refresh_indices() -> void:
	var position: int = 1
	for segment in segments():
		segment.set_index(position)
		position += 1

## True while any slot is entirely empty. Gates the Add Slot button, so
## there is never more than one empty slot (spec section 6.4).
func has_empty_segment() -> bool:
	for segment in segments():
		if segment.is_empty():
			return true
	return false

## Compiles complete slots to rules, in display order, and reports the
## incomplete ones separately so they can be badged rather than crashing
## the evaluator. rules[i] corresponds to segments[i] by construction.
func compile() -> Dictionary:
	var rules: Array[PriorityRule] = []
	var paired: Array[RuleSegment] = []
	var incomplete: Array[RuleSegment] = []

	for segment in segments():
		if segment.is_complete():
			rules.append(segment.build_rule())
			paired.append(segment)
		else:
			incomplete.append(segment)

	return {"rules": rules, "segments": paired, "incomplete": incomplete}

## Where a segment dragged to local y should be inserted -- compared against
## each existing segment's vertical midpoint. Used by _drop_data in Task 8
## and by the insertion indicator.
func insert_index_for_y(y: float) -> int:
	var index: int = 0
	for segment in segments():
		if y < segment.position.y + segment.size.y * 0.5:
			return index
		index += 1
	return index
```

- [ ] **Step 4: Run both verifications**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/_verify_priority_builder.gd
```

Expected: `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit**

```bash
git add scripts/priority_builder/segment_list.gd scripts/_verify_priority_builder.gd
git commit -m "feat: SegmentList ordering and rule compilation"
```

---

### Task 7: The palettes

Spec §5, §6. `PaletteBlock` and the shared `BlockPalette` used by both columns.

**Files:**
- Create: `scripts/priority_builder/palette_block.gd`
- Create: `scenes/priority_builder/palette_block.tscn`
- Create: `scripts/priority_builder/block_palette.gd`

**Interfaces:**
- Consumes: `ConditionBlockDefinition` (Task 2), `Technique.describe()` (Task 1).
- Produces: `PaletteBlock` (extends `PanelContainer`) with `setup_condition(definition: ConditionBlockDefinition) -> void`, `setup_technique(technique_data: Technique, layer: TooltipLayer) -> void`. `BlockPalette` (extends `VBoxContainer`) with `populate_conditions(definitions: Array[ConditionBlockDefinition]) -> void`, `populate_techniques(techniques: Array[Technique], layer: TooltipLayer) -> void`.

- [ ] **Step 1: Write `palette_block.gd`**

```gdscript
class_name PaletteBlock
extends PanelContainer

## A draggable entry in either palette. Never leaves the palette -- dragging
## it hands over a *description* of what to build (a definition, or a
## technique reference), and the drop target constructs the real block. That
## is what keeps a shared ConditionBlockDefinition from ever being handed out
## as a live editable Condition. See spec section 6.1.

var definition: ConditionBlockDefinition
var technique: Technique

var _tooltip_layer: TooltipLayer

@onready var label: Label = $Label

func setup_condition(block_definition: ConditionBlockDefinition) -> void:
	definition = block_definition
	label.text = definition.block_label

func setup_technique(technique_data: Technique, layer: TooltipLayer) -> void:
	technique = technique_data
	_tooltip_layer = layer
	label.text = technique.technique_name
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if _tooltip_layer != null and technique != null:
		_tooltip_layer.hover_started(self, technique.describe())

func _on_mouse_exited() -> void:
	if _tooltip_layer != null:
		_tooltip_layer.hover_ended(self)

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = label.text
	set_drag_preview(preview)

	if definition != null:
		return {"source": "palette", "definition": definition}
	if technique != null:
		return {"source": "palette", "technique": technique}
	return null
```

- [ ] **Step 2: Create `palette_block.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/priority_builder/palette_block.gd" id="1"]

[node name="PaletteBlock" type="PanelContainer"]
mouse_filter = 0
script = ExtResource("1")

[node name="Label" type="Label" parent="."]
text = "Block"
```

- [ ] **Step 3: Write `block_palette.gd`**

```gdscript
class_name BlockPalette
extends VBoxContainer

## Both palettes. Condition blocks group under headers taken from each
## definition's `category`, so spec section 5's "split by kind" requirement is
## satisfied by data rather than by layout code.

const PALETTE_BLOCK_SCENE: PackedScene = preload("res://scenes/priority_builder/palette_block.tscn")

func populate_conditions(definitions: Array[ConditionBlockDefinition]) -> void:
	_clear()

	var seen_categories: Array[String] = []
	for definition in definitions:
		if not seen_categories.has(definition.category):
			seen_categories.append(definition.category)

	for category in seen_categories:
		_add_header(category)
		for definition in definitions:
			if definition.category != category:
				continue
			var block: PaletteBlock = PALETTE_BLOCK_SCENE.instantiate()
			add_child(block)
			block.setup_condition(definition)

func populate_techniques(techniques: Array[Technique], layer: TooltipLayer) -> void:
	_clear()
	for technique in techniques:
		var block: PaletteBlock = PALETTE_BLOCK_SCENE.instantiate()
		add_child(block)
		block.setup_technique(technique, layer)

func _add_header(text: String) -> void:
	var header := Label.new()
	header.text = text.to_upper()
	add_child(header)

func _clear() -> void:
	for child in get_children():
		child.queue_free()
```

- [ ] **Step 4: Run the parse check**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add scripts/priority_builder/palette_block.gd scenes/priority_builder/palette_block.tscn scripts/priority_builder/block_palette.gd
git commit -m "feat: condition and technique palettes"
```

---

### Task 8: Drag-and-drop wiring

Spec §6.1–6.4, §7.1. The drop targets, reordering, and the wrapper arity refusal.

**Files:**
- Modify: `scripts/priority_builder/condition_block.gd` (drop zone on `body`, drag-out)
- Modify: `scripts/priority_builder/rule_segment.gd` (drop zones, header drag)
- Modify: `scripts/priority_builder/segment_list.gd` (reorder drop, insertion indicator)

**Interfaces:**
- Consumes: everything from Tasks 3–7.
- Produces: no new public API. Payload contract per spec §6: `{source: "palette", definition: …}`, `{source: "palette", technique: …}`, `{source: "build", node: …}`.

Godot detail that shapes all of this: drop targeting asks the innermost `Control` under the cursor first and walks up the parent chain, skipping `mouse_filter = IGNORE` nodes. So nesting needs no depth bookkeeping — a condition block's `body` wins over the segment containing it automatically.

**Ordering rule that applies to every `_drop_data` below:** `setup()` populates
`@onready` containers, so a freshly instantiated block must be added to the
tree *before* `setup()` is called. Always `add_child(block)` then
`block.setup(...)`, never the reverse.

Drop zones are handled on the block and segment scripts themselves, routing by
cursor position against the child container's rect, rather than by giving each
container its own script. Fewer files, and the routing is visible in one place.

- [ ] **Step 1: Add drop handling and drag-out to `condition_block.gd`**

Append to `condition_block.gd`:

```gdscript
## Dragging a placed block carries the node itself, so dragging out of a
## slot and dragging between slots are the same path.
func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = definition.block_label if definition != null else "condition"
	set_drag_preview(preview)
	return {"source": "build", "node": self}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if not _is_over_body(at_position):
		return false
	return _accepts_condition(data)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _is_over_body(at_position):
		return
	_remove_body_placeholder()

	if data.get("source") == "palette":
		var block: ConditionBlock = load("res://scenes/priority_builder/condition_block.tscn").instantiate()
		body.add_child(block)
		block.setup(data["definition"])
		block.structure_changed.connect(func() -> void: structure_changed.emit())
	else:
		var moved: ConditionBlock = data["node"]
		moved.get_parent().remove_child(moved)
		body.add_child(moved)

	structure_changed.emit()

## Global rects, not local ones. `body` sits inside a MarginContainer, so
## body.position is margin-relative while at_position is block-relative --
## subtracting one from the other would be off by the margin. Comparing
## global rects against the global cursor is correct at any nesting depth.
func _is_over_body(_at_position: Vector2) -> bool:
	return body.get_global_rect().has_point(get_global_mouse_position())

## A wrapper's body takes exactly one leaf condition, and that condition
## takes no body children of its own. Without this a block nested inside a
## NOT would flatten into the rule's conditions[] and escape the negation,
## turning "not (A and B)" into "not A and B" -- the picture would lie. See
## spec section 7.1.
func _accepts_condition(data: Dictionary) -> bool:
	if data.get("source") == "build" and data.get("node") == self:
		return false  # can't drop a block into itself

	if is_wrapper():
		return body_children().is_empty()

	# Inside a wrapper's subtree, no further nesting is allowed.
	if _is_inside_wrapper():
		return false

	return data.has("definition") or (data.get("source") == "build" and data.get("node") is ConditionBlock)

func _is_inside_wrapper() -> bool:
	var node: Node = get_parent()
	while node != null:
		if node is ConditionBlock and node.is_wrapper():
			return true
		node = node.get_parent()
	return false

func _remove_body_placeholder() -> void:
	var placeholder: Node = body.get_node_or_null("BodyPlaceholder")
	if placeholder != null:
		placeholder.queue_free()
```

Spec §7.1 also requires the refusal to be *visible*, not merely enforced: `_add_body_placeholder()` (Task 3) already names the arity, and a filled wrapper body has no placeholder, so it reads as full rather than as an open target.

Set `Body`'s and `Sentence`'s `mouse_filter` to `MOUSE_FILTER_IGNORE` in
`condition_block.tscn`, so the `ConditionBlock` itself is the hit target and the
`at_position` passed to `_can_drop_data` / `_drop_data` is block-relative —
which is what `_is_over_body()` assumes.

- [ ] **Step 2: Add drop handling and the header drag to `rule_segment.gd`**

```gdscript
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false

	if _is_over(technique_slot, at_position):
		return _accepts_technique(data)

	if _is_over(condition_body, at_position):
		return data.has("definition") or (data.get("source") == "build" and data.get("node") is ConditionBlock)

	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _is_over(technique_slot, at_position):
		_drop_technique(data)
	elif _is_over(condition_body, at_position):
		_drop_condition(data)
	structure_changed.emit()

## Global rects for the same reason as ConditionBlock._is_over_body() --
## these containers are nested under Rows, so their local positions are not
## in the same space as at_position.
func _is_over(container: Control, _at_position: Vector2) -> bool:
	return container.get_global_rect().has_point(get_global_mouse_position())

## One technique per slot.
func _accepts_technique(data: Dictionary) -> bool:
	if not data.has("technique") and not (data.get("node") is TechniqueBlock):
		return false
	return technique_block() == null

func _drop_technique(data: Dictionary) -> void:
	if data.get("source") == "palette":
		var block: TechniqueBlock = load("res://scenes/priority_builder/technique_block.tscn").instantiate()
		technique_slot.add_child(block)
		block.setup(data["technique"], _tooltip_layer)
	else:
		var moved: TechniqueBlock = data["node"]
		moved.get_parent().remove_child(moved)
		technique_slot.add_child(moved)

func _drop_condition(data: Dictionary) -> void:
	if data.get("source") == "palette":
		var block: ConditionBlock = load("res://scenes/priority_builder/condition_block.tscn").instantiate()
		condition_body.add_child(block)
		block.setup(data["definition"])
		block.structure_changed.connect(func() -> void: structure_changed.emit())
	else:
		var moved: ConditionBlock = data["node"]
		moved.get_parent().remove_child(moved)
		condition_body.add_child(moved)
```

Add the tooltip layer reference and the header drag:

```gdscript
var _tooltip_layer: TooltipLayer

func set_tooltip_layer(layer: TooltipLayer) -> void:
	_tooltip_layer = layer

## Only the header handle starts a reorder drag -- dragging anywhere on the
## segment would fight with dragging the blocks inside it.
func _get_drag_data(at_position: Vector2) -> Variant:
	if not _is_over(handle, at_position):
		return null
	var preview := Label.new()
	preview.text = "Priority %s" % index_label.text
	set_drag_preview(preview)
	return {"source": "build", "node": self}
```

- [ ] **Step 3: Add reorder drop and the insertion indicator to `segment_list.gd`**

```gdscript
var _indicator: ColorRect

func _ready() -> void:
	_indicator = ColorRect.new()
	_indicator.color = Color(1, 1, 1, 0.6)
	_indicator.custom_minimum_size = Vector2(0, 2)
	_indicator.visible = false
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_indicator)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if not (data.get("source") == "build" and data.get("node") is RuleSegment):
		_indicator.visible = false
		return false

	# _can_drop_data runs every frame during a hover, which is what makes it
	# the right place to move the insertion indicator.
	var index: int = insert_index_for_y(at_position.y)
	move_child(_indicator, index)
	_indicator.visible = true
	return true

func _drop_data(at_position: Vector2, data: Variant) -> void:
	_indicator.visible = false
	var segment: RuleSegment = data["node"]
	if segment.get_parent() != self:
		return
	move_child(segment, clampi(insert_index_for_y(at_position.y), 0, get_child_count() - 1))
	_refresh_indices()
	structure_changed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_indicator.visible = false
```

The indicator is a child of the list, so `segments()`'s `child is RuleSegment` filter already skips it and `insert_index_for_y` is unaffected.

- [ ] **Step 4: Run the parse check and re-run the behavior checks**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/_verify_priority_builder.gd
```

Expected: no parse errors, and `ALL CHECKS PASSED` still — Tasks 3, 5, and 6's assertions must not have regressed. Drag behavior itself is verified manually in Task 11.

- [ ] **Step 5: Commit**

```bash
git add scripts/priority_builder/condition_block.gd scripts/priority_builder/rule_segment.gd scripts/priority_builder/segment_list.gd
git commit -m "feat: drag-and-drop, nesting, and reordering"
```

---

### Task 9: `StateProbe`

Spec §8. Declared state, four verdicts, and the cross-check.

**Files:**
- Create: `scripts/priority_builder/state_probe.gd`
- Modify: `scripts/_verify_priority_builder.gd`

**Interfaces:**
- Consumes: `SegmentList.compile()` (Task 6), `RuleSegment.set_verdict()` (Task 5).
- Produces: `StateProbe` (extends `PanelContainer`) with `setup(builder: Familiar, opponent: Familiar) -> void`, `evaluate(compiled: Dictionary) -> void`, `user: Combatant`, `target: Combatant`, `signal state_changed`.

- [ ] **Step 1: Write the failing verification**

Add `_check_state_probe()` to `_initialize()` and append:

```gdscript
func _check_state_probe() -> void:
	var probe := StateProbe.new()
	root.add_child(probe)
	probe.setup(load("res://resources/familiars/twerpent.tres"), load("res://resources/familiars/guubal.tres"))

	_expect(probe.user != null and probe.target != null, "probe should build both combatants")
	_expect(probe.user.current_hp == probe.user.familiar.max_hp, "probe user should start at full HP")

	# Declared state must land verbatim -- not filtered through
	# add_status()'s Ward absorption. Give the target Ward first, then
	# Poison; both must be present at the stacks asked for.
	probe.set_status(probe.target, Status.StatusEffect.WARD, 5)
	probe.set_status(probe.target, Status.StatusEffect.POISON, 3)
	var poison: Status = probe.target.get_status(Status.StatusEffect.POISON)
	_expect(poison != null, "declared Poison should be present despite Ward")
	if poison != null:
		_expect(poison.stacks == 3, "declared Poison should keep 3 stacks, got %d" % poison.stacks)

	# Verdicts. Rule 1 requires target Poison < 1 (fails, target has 3).
	# Rule 2 is an unconditional catch-all (fires). Rule 3 is unreached.
	var list := SegmentList.new()
	root.add_child(list)

	var conditional: RuleSegment = _filled_segment("res://resources/techniques/acid_bath.tres")
	list.add_child(conditional)
	var block: ConditionBlock = _new_condition_block("status_vs_value")
	root.remove_child(block)
	conditional.condition_body.add_child(block)
	block.set_property_for_test(&"left_target", 1)  # TARGET
	block.set_property_for_test(&"left_status_effect", Status.StatusEffect.POISON)
	block.set_property_for_test(&"comparator", StatusComparisonCondition.Comparator.LESS)
	block.set_property_for_test(&"right_value", 1)

	var catch_all: RuleSegment = _filled_segment("res://resources/techniques/venom_strike.tres")
	list.add_child(catch_all)
	var dead: RuleSegment = _filled_segment("res://resources/techniques/attack.tres")
	list.add_child(dead)

	probe.evaluate(list.compile())

	_expect(probe.verdict_for(conditional) == StateProbe.Verdict.SKIPPED,
		"rule 1 should be SKIPPED, got %s" % probe.verdict_for(conditional))
	_expect(probe.verdict_for(catch_all) == StateProbe.Verdict.FIRES,
		"the catch-all should FIRE, got %s" % probe.verdict_for(catch_all))
	_expect(probe.verdict_for(dead) == StateProbe.Verdict.UNREACHED,
		"the rule below the catch-all should be UNREACHED, got %s" % probe.verdict_for(dead))
	_expect(probe.mismatch_message() == "",
		"probe walk and choose_technique() disagreed: %s" % probe.mismatch_message())

	# An incomplete segment is badged and excluded, not crashed on.
	var incomplete: RuleSegment = load(RULE_SEGMENT_SCENE).instantiate()
	list.add_child(incomplete)
	var orphan: ConditionBlock = _new_condition_block("hp_vs_percent")
	root.remove_child(orphan)
	incomplete.condition_body.add_child(orphan)
	probe.evaluate(list.compile())
	_expect(probe.verdict_for(incomplete) == StateProbe.Verdict.INCOMPLETE,
		"a technique-less segment should be INCOMPLETE")

	# With no complete rule at all, the probe reports no match rather than
	# returning a null technique silently.
	var empty_list := SegmentList.new()
	root.add_child(empty_list)
	probe.evaluate(empty_list.compile())
	_expect(probe.no_match_message() != "", "an empty build should produce a no-match message")
	print("  no-match message: %s" % probe.no_match_message())
```

- [ ] **Step 2: Run it to verify it fails**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/_verify_priority_builder.gd
```

Expected: FAIL — `StateProbe` is not defined.

- [ ] **Step 3: Write `state_probe.gd`**

```gdscript
class_name StateProbe
extends PanelContainer

## Editable mock battle state, plus a per-rule verdict for the current build.
##
## State is *declared*, not applied: statuses go straight onto
## Combatant.statuses instead of through add_status(), which would run Ward
## absorption and the on_applied hooks. A probe where entering "3 Poison"
## silently yields 0 because the target has Ward would be useless for
## reasoning about conditions. See spec section 8.1.

signal state_changed

enum Verdict { FIRES, SKIPPED, UNREACHED, INCOMPLETE }

var user: Combatant
var target: Combatant

var _verdicts: Dictionary = {}      # RuleSegment -> Verdict
var _mismatch: String = ""
var _no_match: String = ""

func setup(builder: Familiar, opponent: Familiar) -> void:
	user = Combatant.new(builder)
	target = Combatant.new(opponent)

## Declares a status at an exact stack count, replacing any existing one.
## Mirrors combatant.gd:77-78's append plus owner assignment, minus the
## hooks -- see the class comment.
func set_status(combatant: Combatant, effect: Status.StatusEffect, stacks: int) -> void:
	var existing: Status = combatant.get_status(effect)
	if existing != null:
		combatant.statuses.erase(existing)

	if stacks <= 0:
		state_changed.emit()
		return

	var status: Status = Status.create(effect, stacks)
	if status != null:
		status.owner = combatant
		combatant.statuses.append(status)

	state_changed.emit()

func set_hp(combatant: Combatant, value: int) -> void:
	combatant.current_hp = clampi(value, 0, combatant.familiar.max_hp)
	state_changed.emit()

## Walks the compiled rules against the current mock state and records a
## verdict per segment.
##
## The walk is restated here rather than read out of choose_technique(),
## which returns skip_reasons as a flat Array[String] -- badging rule i from
## skip_reasons[i] would couple this UI to that loop's internal append
## order. Only the loop is restated; the primitive that matters,
## condition.is_met(), is the real one. The cross-check below is what keeps
## the restatement from drifting.
func evaluate(compiled: Dictionary) -> void:
	_verdicts.clear()
	_mismatch = ""
	_no_match = ""

	var rules: Array[PriorityRule] = compiled["rules"]
	var segments: Array[RuleSegment] = compiled["segments"]

	for segment in compiled["incomplete"]:
		_verdicts[segment] = Verdict.INCOMPLETE
		segment.set_verdict("⚠ incomplete", _incomplete_reason(segment))

	var winner: int = -1

	for i in rules.size():
		var segment: RuleSegment = segments[i]

		if winner != -1:
			_verdicts[segment] = Verdict.UNREACHED
			segment.set_verdict("– unreached", "a rule above this one already fired")
			continue

		var failed: Condition = null
		for condition in rules[i].conditions:
			if not condition.is_met(user, target):
				failed = condition
				break

		if failed == null:
			winner = i
			_verdicts[segment] = Verdict.FIRES
			segment.set_verdict("✓ FIRES", rules[i].technique.technique_name)
		else:
			_verdicts[segment] = Verdict.SKIPPED
			segment.set_verdict("✗ skipped", failed.describe())

	if winner == -1:
		_no_match = "No rule matched — add a slot with a technique and no conditions."

	_cross_check(rules, winner)

## Runs the real evaluator on the same compiled list and compares winners.
## Cheap insurance that evaluate()'s restated loop still agrees with the one
## combat actually uses.
func _cross_check(rules: Array[PriorityRule], winner: int) -> void:
	var probe_familiar := Familiar.new()
	probe_familiar.max_hp = user.familiar.max_hp
	probe_familiar.power = user.familiar.power
	probe_familiar.defense = user.familiar.defense
	probe_familiar.speed = user.familiar.speed
	probe_familiar.focus = user.familiar.focus
	probe_familiar.familiar_name = user.familiar.familiar_name
	probe_familiar.priority_rules = rules

	var shadow := Combatant.new(probe_familiar)
	shadow.current_hp = user.current_hp
	shadow.statuses = user.statuses

	var decision: Dictionary = shadow.choose_technique(target)
	var expected: Technique = rules[winner].technique if winner != -1 else null

	if decision["technique"] != expected:
		var got: String = decision["technique"].technique_name if decision["technique"] != null else "none"
		var want: String = expected.technique_name if expected != null else "none"
		_mismatch = "probe says %s, choose_technique() says %s" % [want, got]

func _incomplete_reason(segment: RuleSegment) -> String:
	if segment.is_empty():
		return "empty slot"
	if segment.technique_block() == null:
		return "no technique"
	return "a NOT block has an empty body"

func verdict_for(segment: RuleSegment) -> Verdict:
	return _verdicts.get(segment, Verdict.INCOMPLETE)

func mismatch_message() -> String:
	return _mismatch

func no_match_message() -> String:
	return _no_match
```

- [ ] **Step 4: Run both verifications**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/_verify_priority_builder.gd
```

Expected: `ALL CHECKS PASSED`. Note the Ward assertion — if declared Poison comes back at fewer than 3 stacks, `set_status` is going through `add_status()` somewhere and spec §8.1 is violated.

- [ ] **Step 5: Commit**

```bash
git add scripts/priority_builder/state_probe.gd scripts/_verify_priority_builder.gd
git commit -m "feat: StateProbe with per-rule verdicts and evaluator cross-check"
```

---

### Task 10: The screen

Spec §5. Assembles everything, adds the probe's own controls and the familiar panel.

**Files:**
- Create: `scripts/priority_builder/priority_builder.gd`
- Create: `scenes/priority_builder/priority_builder.tscn`
- Modify: `scripts/priority_builder/state_probe.gd` (add its control rows)

**Interfaces:**
- Consumes: everything.
- Produces: a runnable scene.

- [ ] **Step 1: Add the probe's control rows to `state_probe.gd`**

```gdscript
## Builds the HP spinner and status rows for one side. Called by
## PriorityBuilder after setup(), since the probe owns the combatants but
## not its own layout.
func build_controls(into: VBoxContainer) -> void:
	_add_side_controls(into, user, "Me")
	_add_side_controls(into, target, "Them")

func _add_side_controls(into: VBoxContainer, combatant: Combatant, label_text: String) -> void:
	var row := HBoxContainer.new()
	into.add_child(row)

	var name_label := Label.new()
	name_label.text = "%s (%s)" % [label_text, combatant.familiar.familiar_name]
	row.add_child(name_label)

	var hp := SpinBox.new()
	hp.min_value = 0
	hp.max_value = combatant.familiar.max_hp
	hp.value = combatant.current_hp
	hp.value_changed.connect(func(value: float) -> void: set_hp(combatant, int(value)))
	row.add_child(hp)

	var effect_picker := OptionButton.new()
	for effect in Status.StatusEffect.values():
		if effect == Status.StatusEffect.NONE:
			continue
		effect_picker.add_item(String(Status.status_effect_id(effect)).capitalize())
		effect_picker.set_item_metadata(effect_picker.item_count - 1, effect)
	row.add_child(effect_picker)

	var stacks := SpinBox.new()
	stacks.min_value = 0
	stacks.max_value = 99
	stacks.value = 0
	row.add_child(stacks)

	var apply := Button.new()
	apply.text = "set"
	apply.pressed.connect(func() -> void:
		var effect: Status.StatusEffect = effect_picker.get_item_metadata(effect_picker.selected)
		set_status(combatant, effect, int(stacks.value))
	)
	row.add_child(apply)
```

- [ ] **Step 2: Write `priority_builder.gd`**

```gdscript
class_name PriorityBuilder
extends Control

## The priority builder screen. Standalone by design -- it touches neither
## battle.tscn nor battle_controller.gd (spec section 2). It produces an
## in-memory Array[PriorityRule]; nothing consumes it yet.

const BLOCK_DIR: String = "res://resources/priority_builder/blocks"

@export var builder_familiar: Familiar
@export var opponent_familiar: Familiar

## Palette order. Exported rather than scanned so the palette's order is
## authored, matching how battle_controller.gd exports available_builds.
@export var block_definitions: Array[ConditionBlockDefinition] = []

@onready var tooltip_layer: TooltipLayer = $TooltipLayer/TooltipContainer
@onready var portrait: TextureRect = $Columns/LeftColumn/FamiliarPanel/Rows/Portrait
@onready var familiar_name_label: Label = $Columns/LeftColumn/FamiliarPanel/Rows/NameLabel
@onready var stat_grid: GridContainer = $Columns/LeftColumn/FamiliarPanel/Rows/StatGrid
@onready var technique_palette: BlockPalette = $Columns/LeftColumn/TechniqueScroll/TechniquePalette
@onready var condition_palette: BlockPalette = $Columns/RightColumn/ConditionScroll/ConditionPalette
@onready var segment_list: SegmentList = $Columns/BuildColumn/BuildScroll/SegmentList
@onready var add_slot_button: Button = $Columns/BuildColumn/Header/AddSlotButton
@onready var state_probe: StateProbe = $Columns/RightColumn/StateProbe
@onready var probe_controls: VBoxContainer = $Columns/RightColumn/StateProbe/Rows/Controls
@onready var probe_message: Label = $Columns/RightColumn/StateProbe/Rows/Message

func _ready() -> void:
	state_probe.setup(builder_familiar, opponent_familiar)
	state_probe.build_controls(probe_controls)
	state_probe.state_changed.connect(_refresh)

	familiar_name_label.text = builder_familiar.familiar_name
	portrait.texture = builder_familiar.sprite

	condition_palette.populate_conditions(_definitions())
	technique_palette.populate_techniques(builder_familiar.techniques, tooltip_layer)

	segment_list.structure_changed.connect(_refresh)
	add_slot_button.pressed.connect(_on_add_slot_pressed)

	_on_add_slot_pressed()
	_refresh()

## Falls back to scanning BLOCK_DIR when block_definitions is left empty in
## the Inspector, so the scene works the moment it's opened.
func _definitions() -> Array[ConditionBlockDefinition]:
	if not block_definitions.is_empty():
		return block_definitions

	var found: Array[ConditionBlockDefinition] = []
	var order: Array[String] = [
		"status_vs_value", "status_vs_status", "all_stacks_vs_value",
		"hp_vs_percent", "hp_vs_value", "hp_vs_hp",
		"stat_vs_value", "stat_vs_stat", "not",
	]
	for name in order:
		var definition: ConditionBlockDefinition = load("%s/%s.tres" % [BLOCK_DIR, name])
		if definition != null:
			found.append(definition)
	return found

func _on_add_slot_pressed() -> void:
	var segment: RuleSegment = segment_list.add_segment()
	segment.set_tooltip_layer(tooltip_layer)
	_refresh()

func _refresh() -> void:
	# Only one empty slot at a time (spec section 6.4).
	add_slot_button.disabled = segment_list.has_empty_segment()

	var compiled: Dictionary = segment_list.compile()
	state_probe.evaluate(compiled)

	_refresh_stats()

	var messages: Array[String] = []
	if state_probe.no_match_message() != "":
		messages.append(state_probe.no_match_message())
	if state_probe.mismatch_message() != "":
		messages.append("EVALUATOR MISMATCH: %s" % state_probe.mismatch_message())
	probe_message.text = "\n".join(messages)

## Base stats, plus the effective value when a declared status changes it --
## stat_vs_value conditions read the effective one, so showing only the base
## would mislead.
func _refresh_stats() -> void:
	for child in stat_grid.get_children():
		child.queue_free()

	for stat in Familiar.Stat.values():
		var name_label := Label.new()
		name_label.text = Familiar.stat_name(stat)
		stat_grid.add_child(name_label)

		var base: int = builder_familiar.get_stat(stat)
		var effective: int = state_probe.user.effective_stat(stat)

		var value_label := Label.new()
		value_label.text = str(base) if base == effective else "%d → %d" % [base, effective]
		stat_grid.add_child(value_label)
```

- [ ] **Step 3: Create `priority_builder.tscn`**

Node tree per spec §5, with these specifics:

- Root `PriorityBuilder` (Control), anchors Full Rect.
- `Columns` (HBoxContainer), Full Rect.
- `LeftColumn` (VBoxContainer), `custom_minimum_size = (260, 0)`; `FamiliarPanel` (PanelContainer) containing `Rows` (VBoxContainer) with `NameLabel`, `Portrait` (TextureRect, `expand_mode = 1`, `custom_minimum_size = (96, 96)`), `StatGrid` (GridContainer, `columns = 2`); then `TechniqueScroll` (ScrollContainer, `size_flags_vertical = 3`) containing `TechniquePalette` (VBoxContainer + `block_palette.gd`).
- `BuildColumn` (VBoxContainer, `size_flags_horizontal = 3`); `Header` (HBoxContainer) with a `Label` "PRIORITY" and `AddSlotButton` (Button, "+ Add slot"); `BuildScroll` (ScrollContainer, `size_flags_vertical = 3`) containing `SegmentList` (VBoxContainer + `segment_list.gd`).
- `RightColumn` (VBoxContainer), `custom_minimum_size = (320, 0)`; `ConditionScroll` (ScrollContainer, `size_flags_vertical = 3`) containing `ConditionPalette` (VBoxContainer + `block_palette.gd`); then `StateProbe` (PanelContainer + `state_probe.gd`) containing `Rows` (VBoxContainer) with `Controls` (VBoxContainer) and `Message` (Label, `autowrap_mode = 3`).
- `TooltipLayer` (Control, Full Rect, `mouse_filter = 2` IGNORE) containing `TooltipContainer` — instance `scenes/tooltip_layer.tscn` here, matching how `battle.tscn` mounts it at `$TooltipLayer/TooltipContainer`.
- Set `builder_familiar` to `resources/familiars/twerpent.tres` and `opponent_familiar` to `resources/familiars/guubal.tres` in the Inspector.

Per `CLAUDE.md`, if the Godot editor is open with this scene, make these changes through the MCP toolkit (`scene_create_node` / `node_set_property` / `editor_save_scene`) rather than editing the `.tscn` on disk — the editor's in-memory state otherwise wins and silently overwrites the disk edit.

- [ ] **Step 4: Run the parse check and the behavior checks**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit
"../Godot_v4.7.1-stable_win64_console.exe" --headless --script res://scripts/_verify_priority_builder.gd
```

Expected: no parse or missing-node errors (this catches every `@onready` path above being wrong), and `ALL CHECKS PASSED`.

- [ ] **Step 5: Commit**

```bash
git add scripts/priority_builder/priority_builder.gd scripts/priority_builder/state_probe.gd scenes/priority_builder/priority_builder.tscn
git commit -m "feat: priority builder screen"
```

---

### Task 11: Manual verification pass and cleanup

Spec §11. The parts no headless script can check.

**Files:**
- Delete: `scripts/_verify_priority_builder.gd` (+ its `.uid`)
- Modify: `.claude/DEVLOG.md`, `.claude/LEARNING_ROADMAP.md`

- [ ] **Step 1: Run the scene and work through the checklist**

```bash
"../Godot_v4.7.1-stable_win64_console.exe" res://scenes/priority_builder/priority_builder.tscn
```

Check each, and write down what actually happened:

1. Three columns render; both palettes scroll; condition blocks are grouped under STATUS / HP / STAT / LOGIC headers.
2. Hovering a technique block shows its `describe()` text; hovering a status name inside that tooltip opens a nested tooltip.
3. Dragging a condition from the palette into a slot creates an editable sentence; the palette entry stays put.
4. Editing a dropdown in one block does not change any other block built from the same palette entry (the aliasing check, live).
5. Dragging condition B onto condition A's body nests it and visibly insets it.
6. Dropping a second condition into a NOT's body is refused, and the body's placeholder text explains the arity.
7. Dragging a slot's header handle reorders it, with the insertion line tracking the cursor.
8. `+ Add slot` disables while an empty slot exists and re-enables once it's filled.
9. Verdict badges update live while editing dropdowns and probe state; a catch-all above other rules marks them `– unreached`.
10. A slot with conditions but no technique badges `⚠ incomplete` and does not change which rule fires.
11. `EVALUATOR MISMATCH` never appears.

- [ ] **Step 2: Delete the verify script**

```bash
rm scripts/_verify_priority_builder.gd
rm -f scripts/_verify_priority_builder.gd.uid
"../Godot_v4.7.1-stable_win64_console.exe" --headless --check-only --quit
```

Expected: no errors after removal — nothing in the shipped code referenced it.

- [ ] **Step 3: Update the project docs**

Add a `DEVLOG.md` entry for the session covering what was built and what the manual pass actually showed. In `LEARNING_ROADMAP.md`, update the concept table: Godot drag-and-drop (`_get_drag_data`/`_can_drop_data`/`_drop_data`) moves from **Not introduced** to **Introduced**, and note that scene composition with Controls/Containers got substantial new practice. Record any of spec §12's open questions that the manual pass produced an opinion on — as an observation, not a decision.

- [ ] **Step 4: Commit**

```bash
git add -u scripts/_verify_priority_builder.gd .claude/DEVLOG.md .claude/LEARNING_ROADMAP.md
git commit -m "chore: priority builder verification pass, drop throwaway script"
```

---

## Notes for the executor

- **Never `git add -A` or `git add .`** — the working tree carries ~88 unrelated in-progress files.
- If `--check-only` reports errors in files you did not touch, they are pre-existing from that in-progress work. Confirm by checking whether the named file is in your task's file list before trying to fix it.
- Spec §12 lists three deliberately-open questions. Do not resolve them in code. If the manual pass produces an opinion, record it in Task 11 Step 3.
- The one place to push back: if `Object.set()` turns out not to convert a float into an `int`-typed property cleanly (Task 3 Step 5), add `as_integer: bool` to `SentencePart`. Do not add a new `Kind` — spec §4.2 rules that out explicitly.
