extends SceneTree

## Throwaway verification for the priority builder PoC. Deleted in Task 11 --
## see the plan's Global Constraints. Grows one _check_* function per task.

## Every check that must run to completion. A GDScript runtime error aborts
## only the function it happens in -- the caller keeps going -- so without
## this list an aborted check leaves _failures empty and the harness reports
## success for code that never ran. Each _check_* appends its own name as its
## last statement; anything missing here is reported as a failure.
const EXPECTED_CHECKS: Array[String] = [
	"technique_describe",
	"block_definitions",
	"condition_block",
]

const CONDITION_BLOCK_SCENE: String = "res://scenes/priority_builder/condition_block.tscn"
const RULE_SEGMENT_SCENE: String = "res://scenes/priority_builder/rule_segment.tscn"
const TECHNIQUE_BLOCK_SCENE: String = "res://scenes/priority_builder/technique_block.tscn"
const BLOCK_DIR: String = "res://resources/priority_builder/blocks"

var _failures: Array[String] = []
var _completed: Array[String] = []

## Checks run on the first process_frame, NOT in _initialize(). During
## _initialize() the SceneTree's root is not yet inside the tree
## (root.is_inside_tree() == false), so add_child() does not propagate
## _ready() and every @onready var on an added Control stays null. By the
## first process_frame root is in-tree and _ready() fires normally.
func _initialize() -> void:
	process_frame.connect(_run_checks, CONNECT_ONE_SHOT)

func _run_checks() -> void:
	_check_technique_describe()
	_check_block_definitions()
	_check_condition_block()

	for check_name in EXPECTED_CHECKS:
		if not _completed.has(check_name):
			_failures.append("check '%s' never completed -- a SCRIPT ERROR above aborted it" % check_name)

	if _failures.is_empty():
		print("ALL CHECKS PASSED (%d)" % _completed.size())
	else:
		print("FAILURES (%d):" % _failures.size())
		for failure in _failures:
			print("  - %s" % failure)

	quit(1 if _failures.size() > 0 else 0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _definition(name: String) -> ConditionBlockDefinition:
	return load("%s/%s.tres" % [BLOCK_DIR, name])

## Two combatants for is_met() checks -- twerpent (max_hp 75) versus guubal.
func _make_pair() -> Array:
	var user := Combatant.new(load("res://resources/familiars/twerpent.tres"))
	var target := Combatant.new(load("res://resources/familiars/guubal.tres"))
	return [user, target]

## Declared, not applied -- bypasses add_status()'s Ward absorption and
## on_applied hooks. Mirrors state_probe.gd; see spec section 8.1.
func _add_status(combatant: Combatant, effect: Status.StatusEffect, stacks: int) -> void:
	var status: Status = Status.create(effect, stacks)
	status.owner = combatant
	combatant.statuses.append(status)

func _new_condition_block(definition_name: String) -> ConditionBlock:
	var block: ConditionBlock = load(CONDITION_BLOCK_SCENE).instantiate()
	root.add_child(block)
	block.setup(_definition(definition_name))
	return block

func _check_condition_block() -> void:
	var scene: PackedScene = load(CONDITION_BLOCK_SCENE)
	_expect(scene != null, "could not load condition_block.tscn")
	if scene == null:
		return

	var definition: ConditionBlockDefinition = _definition("status_vs_value")

	var block_a: ConditionBlock = scene.instantiate()
	root.add_child(block_a)
	block_a.setup(definition)

	var block_b: ConditionBlock = scene.instantiate()
	root.add_child(block_b)
	block_b.setup(definition)

	# The aliasing check: two blocks built from one shared definition must
	# own separate Condition instances. See DECISIONS.md on the incident
	# where editing fallback_attack.tres for one build changed Guubal's too.
	var condition_a: Condition = block_a.build_condition()
	var condition_b: Condition = block_b.build_condition()
	_expect(condition_a != condition_b, "two blocks from one definition share a Condition instance")
	_expect(condition_a is StatusComparisonCondition, "status_vs_value did not build a StatusComparisonCondition")

	_expect(condition_a.compare_mode == StatusComparisonCondition.CompareMode.FLAT_VALUE,
		"fixed_values did not set compare_mode to FLAT_VALUE")

	# Drive the widgets and confirm the values reach the Condition.
	block_a.set_property_for_test(&"left_status_effect", Status.StatusEffect.ACID)
	block_a.set_property_for_test(&"left_target", 1)
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

	# Editing block_a must not have touched block_b -- the live half of the
	# aliasing check.
	var untouched: StatusComparisonCondition = block_b.build_condition()
	_expect(untouched.left_status_effect != Status.StatusEffect.ACID or untouched.right_value != 5,
		"editing block_a's widgets changed block_b's condition")

	# The float-into-int question from spec 4.2. hp_vs_percent's
	# display_scale is 0.01, so a widget reading 25 must store 0.25 on a
	# float property; the status block's right_value is int-typed and must
	# survive the same set() path.
	var hp_block: ConditionBlock = scene.instantiate()
	root.add_child(hp_block)
	hp_block.setup(_definition("hp_vs_percent"))
	hp_block.set_property_for_test(&"right_value", 0.25)
	hp_block.set_property_for_test(&"left_target", 0)
	hp_block.set_property_for_test(&"comparator", HpComparisonCondition.Comparator.LESS)
	var hp_condition: HpComparisonCondition = hp_block.build_condition()
	_expect(is_equal_approx(hp_condition.right_value, 0.25),
		"HP percent should store 0.25, got %s" % hp_condition.right_value)
	print("  hp_vs_percent describe: %s" % hp_condition.describe())

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
	not_block.setup(_definition("not"))
	_expect(not_block.is_wrapper(), "not.tres should produce a wrapper block")
	_expect(not not_block.is_complete(), "an empty wrapper must be incomplete")

	_completed.append("condition_block")

## Explicit property-list lookup rather than the `in` operator, which is
## ambiguous on Objects. This is what catches a misspelled
## SentencePart.property -- Object.set() on a name that does not exist fails
## silently, so without this a bad definition would simply never write.
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
		if definition.condition_script == null:
			continue

		# Every definition must produce a working Condition, and every field
		# it names -- fixed or exposed -- must actually exist on it.
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

	# The enum ordinals the .tres files hardcode. If any of these classes
	# reorders its own enum, every fixed_values entry silently means
	# something else -- so assert the mapping rather than trusting it.
	_expect(StatusComparisonCondition.CompareMode.FLAT_VALUE == 1, "StatusComparisonCondition FLAT_VALUE is no longer 1")
	_expect(HpComparisonCondition.CompareMode.FLAT_VALUE == 1, "HpComparisonCondition FLAT_VALUE is no longer 1")
	_expect(StatComparisonCondition.CompareMode.FLAT_VALUE == 1, "StatComparisonCondition FLAT_VALUE is no longer 1")
	_expect(StatusComparisonCondition.CompareMode.STATUS == 0, "StatusComparisonCondition STATUS is no longer 0")
	_expect(HpComparisonCondition.CompareMode.HP == 0, "HpComparisonCondition HP is no longer 0")
	_expect(StatComparisonCondition.CompareMode.STAT == 0, "StatComparisonCondition STAT is no longer 0")
	_expect(StatusComparisonCondition.Target.SELF == 0 and StatusComparisonCondition.Target.TARGET == 1,
		"StatusComparisonCondition Target ordinals changed")
	_expect(StatusComparisonCondition.Comparator.LESS == 2, "Comparator.LESS is no longer 2")

	_completed.append("block_definitions")

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

	# Ultra Beam's charged step group carries a +390%-of-Power NumericBonus
	# alongside a 0.1 power_multiplier, so describing the multiplier alone
	# reported "10% damage" for a hit that lands around 400%. The bonus is
	# the move's whole identity, so it has to appear.
	var ultra: Technique = load("res://resources/techniques/ultra_beam.tres")
	if ultra != null:
		var ultra_text: String = ultra.describe()
		_expect(ultra_text.contains("390%"),
			"Ultra Beam describe() should surface its +390%% Power bonus, got: %s" % ultra_text)
		_expect(ultra_text.contains("Power"),
			"Ultra Beam describe() should name the bonus's source stat, got: %s" % ultra_text)

	_completed.append("technique_describe")
