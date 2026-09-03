class_name RuleSegment
extends PanelContainer

## One rule slot: an ANDed set of condition blocks plus one technique,
## compiling to a single PriorityRule.
##
## Two predicates that must not be conflated:
##   is_empty()    -- nothing in it at all. Gates the Add Slot button, so
##                    there is never more than one empty slot.
##   is_complete() -- runnable. Gates inclusion in the probe.
## A slot with conditions but no technique is non-empty AND incomplete: the
## add button stays disabled, and the probe skips it with a badge.

signal structure_changed
signal delete_requested(segment: RuleSegment)

const TECHNIQUE_BLOCK_SCENE: String = "res://scenes/priority_builder/technique_block.tscn"

@onready var handle: Label = $Rows/Header/Handle
@onready var index_label: Label = $Rows/Header/IndexLabel
@onready var verdict_label: Label = $Rows/Header/VerdictLabel
@onready var delete_button: Button = $Rows/Header/DeleteButton
@onready var condition_body: VBoxContainer = $Rows/ConditionBody
@onready var technique_slot: VBoxContainer = $Rows/TechniqueSlot

var _tooltip_layer: TooltipLayer

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

func set_tooltip_layer(layer: TooltipLayer) -> void:
	_tooltip_layer = layer

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
## combatant.gd's rule.technique.technique_name and not_condition.gd's
## wrapped_condition.is_met() -- so an incomplete segment is excluded from
## evaluation rather than handed to the evaluator.
## Also false for a block that is in the tree but not yet set up. A drop does
## add_child() then setup(), because setup() populates @onready containers --
## and add_child() fires child_entered_tree in between, which triggers a
## refresh that compiles this slot mid-construction. Treating a node-present
## -but-unconfigured block as complete produced a null technique and a null
## Condition in the compiled rule, crashing the probe on every drop.
func is_complete() -> bool:
	var holder: TechniqueBlock = technique_block()
	if holder == null or holder.technique == null:
		return false
	for block in condition_blocks():
		if not block.is_complete():
			return false
	return true

## Flattens this slot's block tree into one PriorityRule. Nesting means AND,
## which is already what PriorityRule.conditions means, so the tree collapses
## depth-first pre-order into that flat array.
func build_rule() -> PriorityRule:
	var rule := PriorityRule.new()

	var holder: TechniqueBlock = technique_block()
	rule.technique = holder.technique if holder != null else null

	var conditions: Array[Condition] = []
	for block in condition_blocks():
		_collect(block, conditions)
	rule.conditions = conditions

	return rule

func _collect(block: ConditionBlock, into: Array[Condition]) -> void:
	into.append(block.build_condition())

	# build_condition() already folded a wrapper's single body child into its
	# body_property, so a wrapper is appended without recursing. Recursing
	# would ALSO append that child unnegated, ANDing a condition alongside
	# its own negation -- never satisfiable. Verified by perturbation: with
	# this return removed, a NOT wrapping one condition compiles to 2.
	if block.is_wrapper():
		return

	for child in block.body_children():
		_collect(child, into)

## Only the header handle starts a reorder drag. Dragging anywhere on the
## segment would fight with dragging the blocks inside it.
func _get_drag_data(at_position: Vector2) -> Variant:
	if not _is_over(handle, at_position):
		return null
	var preview := Label.new()
	preview.text = "Priority %s" % index_label.text
	set_drag_preview(preview)
	return {"source": "build", "node": self}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false

	# A segment being dragged for reorder is the SegmentList's business, not
	# a slot's -- refusing here lets the query bubble up to the list.
	if data.get("node") is RuleSegment:
		return false

	if _is_over(technique_slot, at_position):
		return _accepts_technique(data)

	if _is_over(condition_body, at_position):
		return _is_condition_payload(data)

	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _is_over(technique_slot, at_position):
		_drop_technique(data)
	elif _is_over(condition_body, at_position):
		_drop_condition(data)

	structure_changed.emit()

## Global rects for the same reason as ConditionBlock._is_over_body() --
## these containers are nested under Rows, so their local positions are not
## in the same coordinate space as at_position.
func _is_over(container: Control, _at_position: Vector2) -> bool:
	return container.get_global_rect().has_point(get_global_mouse_position())

func _is_condition_payload(data: Dictionary) -> bool:
	if data.has("definition"):
		return true
	return data.get("source") == "build" and data.get("node") is ConditionBlock

## One technique per slot.
func _accepts_technique(data: Dictionary) -> bool:
	if technique_block() != null:
		return false
	if data.has("technique"):
		return true
	return data.get("source") == "build" and data.get("node") is TechniqueBlock

func _drop_technique(data: Dictionary) -> void:
	if data.get("source") == "palette":
		var block: TechniqueBlock = load(TECHNIQUE_BLOCK_SCENE).instantiate()
		technique_slot.add_child(block)
		block.setup(data["technique"], _tooltip_layer)
	else:
		var moved: TechniqueBlock = data["node"]
		moved.get_parent().remove_child(moved)
		technique_slot.add_child(moved)

func _drop_condition(data: Dictionary) -> void:
	if data.get("source") == "palette":
		var block: ConditionBlock = load(ConditionBlock.SCENE_PATH).instantiate()
		condition_body.add_child(block)
		block.setup(data["definition"])
		block.structure_changed.connect(_on_block_structure_changed)
	else:
		var moved: ConditionBlock = data["node"]
		moved.get_parent().remove_child(moved)
		condition_body.add_child(moved)
		if not moved.structure_changed.is_connected(_on_block_structure_changed):
			moved.structure_changed.connect(_on_block_structure_changed)

func _on_block_structure_changed() -> void:
	structure_changed.emit()

func set_index(index: int) -> void:
	index_label.text = str(index)

func set_verdict(badge: String, detail: String) -> void:
	verdict_label.text = badge if detail == "" else "%s — %s" % [badge, detail]
