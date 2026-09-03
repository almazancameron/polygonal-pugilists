class_name StateProbe
extends PanelContainer

## Editable mock battle state, plus a per-rule verdict for the current build.
##
## State is *declared*, not applied: statuses go straight onto
## Combatant.statuses instead of through add_status(), which would run Ward
## absorption and the on_applied/on_reapply hooks. A probe where entering
## "3 Poison" silently yields 0 because the target has Ward would be useless
## for reasoning about conditions -- you want to state the situation, not
## simulate arriving at it.

signal state_changed

enum Verdict { FIRES, SKIPPED, UNREACHED, INCOMPLETE }

var user: Combatant
var target: Combatant

var _verdicts: Dictionary = {}
var _mismatch: String = ""
var _no_match: String = ""

func setup(builder: Familiar, opponent: Familiar) -> void:
	user = Combatant.new(builder)
	target = Combatant.new(opponent)

## Declares a status at an exact stack count, replacing any existing one.
## Mirrors what combatant.gd does when appending a genuinely new status
## (append plus owner assignment) minus the hooks -- see the class comment.
## A count of 0 or less removes it.
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
## condition.is_met(), is the real one. _cross_check() is what keeps the
## restatement from drifting away from the evaluator combat actually uses.
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
			segment.set_verdict("– unreached", "an earlier rule fired")
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
## Cheap insurance that evaluate()'s restated loop still agrees with
## Combatant.choose_technique(). Normally silent.
func _cross_check(rules: Array[PriorityRule], winner: int) -> void:
	var probe_familiar := Familiar.new()
	probe_familiar.familiar_name = user.familiar.familiar_name
	probe_familiar.max_hp = user.familiar.max_hp
	probe_familiar.power = user.familiar.power
	probe_familiar.defense = user.familiar.defense
	probe_familiar.speed = user.familiar.speed
	probe_familiar.focus = user.familiar.focus
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

	var holder: TechniqueBlock = segment.technique_block()
	if holder == null or holder.technique == null:
		return "no technique"

	return "a NOT block has an empty body"

func verdict_for(segment: RuleSegment) -> Verdict:
	return _verdicts.get(segment, Verdict.INCOMPLETE)

func mismatch_message() -> String:
	return _mismatch

func no_match_message() -> String:
	return _no_match

## Builds the HP spinner and status rows for both sides. The probe owns the
## combatants but not its own layout, so PriorityBuilder hands it a container
## to fill.
func build_controls(into: VBoxContainer) -> void:
	_add_side_controls(into, user, "Me")
	_add_side_controls(into, target, "Them")

## Two narrow rows per side rather than one wide one. A single row of
## label + HP + status picker + stacks + button measured well over 500px,
## and since this panel is not scrollable its minimum size propagated up and
## starved the middle build column, clipping the Add Slot button.
func _add_side_controls(into: VBoxContainer, combatant: Combatant, label_text: String) -> void:
	var hp_row := HBoxContainer.new()
	into.add_child(hp_row)

	var name_label := Label.new()
	name_label.text = "%s (%s)" % [label_text, combatant.familiar.familiar_name]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	hp_row.add_child(name_label)

	var hp := SpinBox.new()
	hp.min_value = 0
	hp.max_value = combatant.familiar.max_hp
	hp.value = combatant.current_hp
	hp.custom_minimum_size = Vector2(72, 0)
	hp.value_changed.connect(func(value: float) -> void: set_hp(combatant, int(value)))
	hp_row.add_child(hp)

	var status_row := HBoxContainer.new()
	into.add_child(status_row)

	var effect_picker := OptionButton.new()
	for effect in Status.StatusEffect.values():
		if effect == Status.StatusEffect.NONE:
			continue
		effect_picker.add_item(String(Status.status_effect_id(effect)).capitalize())
		effect_picker.set_item_metadata(effect_picker.item_count - 1, effect)
	effect_picker.clip_text = true
	effect_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(effect_picker)

	var stacks := SpinBox.new()
	stacks.min_value = 0
	stacks.max_value = 99
	stacks.value = 0
	stacks.custom_minimum_size = Vector2(64, 0)
	status_row.add_child(stacks)

	# "set" rather than "add": 0 removes the status, so one control both
	# applies and clears.
	var apply := Button.new()
	apply.text = "set"
	apply.pressed.connect(func() -> void:
		var effect: Status.StatusEffect = effect_picker.get_item_metadata(effect_picker.selected)
		set_status(combatant, effect, int(stacks.value))
	)
	status_row.add_child(apply)
