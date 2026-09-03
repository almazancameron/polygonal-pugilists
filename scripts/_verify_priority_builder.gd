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
]

var _failures: Array[String] = []
var _completed: Array[String] = []

func _initialize() -> void:
	_check_technique_describe()

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
