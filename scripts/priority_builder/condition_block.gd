class_name ConditionBlock
extends PanelContainer

## One condition in the builder, rendered as a fill-in-the-blank sentence
## built from its ConditionBlockDefinition. Owns exactly one Condition
## instance, minted fresh in setup() -- the definition is shared and stays
## read-only, so editing this block's dropdowns can never reach into another
## block or into an authored .tres. See DECISIONS.md on resources referenced
## by more than one owner.
##
## Nesting a block inside `body` means AND. That is presentation only:
## RuleSegment flattens the tree pre-order into PriorityRule.conditions,
## because an ANDed array is already what that field means. The exception is
## a wrapper block (body_property set, only NOT today), whose single body
## child is assigned to that property instead.

signal structure_changed

@onready var sentence_row: HBoxContainer = $Rows/Sentence
@onready var body: VBoxContainer = $Rows/BodyMargin/Body

var definition: ConditionBlockDefinition

var _condition: Condition

## property -> the Control editing it, so build_condition() can re-read
## widget values instead of caching state that could drift out of sync.
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

	# A wrapper has no sentence of its own, so it needs its label drawn.
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

	# Show whatever the condition already holds -- its own declared default,
	# or a fixed_values entry -- rather than forcing index 0.
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

	# The condition stores a scaled value; the widget shows the unscaled one
	# (0.25 stored reads as 25 for a percentage).
	var current: Variant = _condition.get(part.property)
	if current != null and not is_zero_approx(part.display_scale):
		spin.value = float(current) / part.display_scale

	spin.value_changed.connect(func(_value: float) -> void: structure_changed.emit())
	sentence_row.add_child(spin)
	_widgets[part.property] = spin

## Spec section 7.1 requires the wrapper's one-condition limit to be visible,
## not merely enforced -- a drop refused for a non-obvious reason reads as a
## bug. Removed as soon as something is dropped in, so a filled wrapper
## reads as full rather than as an open target.
func _add_body_placeholder() -> void:
	var label := Label.new()
	label.name = "BodyPlaceholder"
	label.text = "drop one condition here"
	label.modulate = Color(1, 1, 1, 0.5)
	body.add_child(label)

## Option tables per OptionSource. Values are stored explicitly rather than
## derived from display order -- Comparator's declared order is GREATER,
## GREATER_OR_EQUAL, LESS, LESS_OR_EQUAL, EQUAL, which is not the order a
## person wants to read, so index and value deliberately disagree here.
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
## each compile rather than trusting cached writes, so the widget row stays
## the single source of truth.
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
## would, so build_condition()'s real read path is what gets exercised
## rather than a shortcut around it.
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
