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

## Loaded by path rather than preloaded: a scene whose own script preloads
## that same scene is a cyclic dependency Godot rejects.
const SCENE_PATH: String = "res://scenes/priority_builder/condition_block.tscn"

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
			var value_scale: float = part.display_scale if part != null else 1.0
			_condition.set(property, widget.value * value_scale)

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

## Dragging a placed block carries the node itself, so dragging out of a
## slot and dragging between slots are one code path.
func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = definition.block_label if definition != null else "condition"
	set_drag_preview(preview)
	return {"source": "build", "node": self}

## Drop targeting asks the innermost Control under the cursor first and walks
## up the parent chain, skipping MOUSE_FILTER_IGNORE nodes. Every container
## in this scene is IGNORE and the root is STOP, so a nested block is asked
## before the block containing it -- which is exactly the nesting behavior
## wanted, with no depth bookkeeping. Returning false here lets the query
## bubble to the parent.
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
		var block: ConditionBlock = load(SCENE_PATH).instantiate()
		# setup() populates @onready containers, so it must run after the
		# node is in the tree.
		body.add_child(block)
		block.setup(data["definition"])
		block.structure_changed.connect(_on_child_structure_changed)
	else:
		var moved: ConditionBlock = data["node"]
		moved.get_parent().remove_child(moved)
		body.add_child(moved)
		if not moved.structure_changed.is_connected(_on_child_structure_changed):
			moved.structure_changed.connect(_on_child_structure_changed)

	structure_changed.emit()

func _on_child_structure_changed() -> void:
	structure_changed.emit()

## Global rects, not local ones. `body` sits inside a MarginContainer, so
## body.position is margin-relative while at_position is block-relative --
## subtracting one from the other would be off by the margin. Comparing
## global rects against the global cursor is correct at any nesting depth.
func _is_over_body(_at_position: Vector2) -> bool:
	return body.get_global_rect().has_point(get_global_mouse_position())

## A wrapper's body takes exactly one leaf condition, and that condition
## takes no body children of its own. Without this, a block nested inside a
## NOT would flatten into the rule's conditions[] and escape the negation --
## "not (A and B)" on screen compiling to "not A and B", which are not
## equal. Refusing the drop is what keeps the drawing honest.
func _accepts_condition(data: Dictionary) -> bool:
	var dragged: Variant = data.get("node")

	if dragged == self:
		return false

	# Reparenting a block into its own descendant would make a cycle.
	if dragged is Node and dragged.is_ancestor_of(self):
		return false

	if is_wrapper():
		return body_children().is_empty() and _is_condition_payload(data)

	if _is_inside_wrapper():
		return false

	return _is_condition_payload(data)

func _is_condition_payload(data: Dictionary) -> bool:
	if data.has("definition"):
		return true
	return data.get("source") == "build" and data.get("node") is ConditionBlock

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
		body.remove_child(placeholder)
		placeholder.queue_free()

## Test seam for headless verification -- drives a widget the way a click
## would, so build_condition()'s real read path is what gets exercised
## rather than a shortcut around it.
func set_property_for_test(property: StringName, value: Variant) -> void:
	var widget: Control = _widgets.get(property)
	if widget == null:
		return

	if widget is SpinBox:
		var part: SentencePart = _part_for(property)
		var value_scale: float = part.display_scale if part != null else 1.0
		widget.value = float(value) / value_scale
	elif widget is OptionButton:
		for i in widget.item_count:
			if widget.get_item_metadata(i) == value:
				widget.select(i)
				return
