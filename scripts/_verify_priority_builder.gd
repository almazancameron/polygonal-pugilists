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
]

var _failures: Array[String] = []
var _completed: Array[String] = []

func _initialize() -> void:
	_check_technique_describe()
	_check_block_definitions()

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
