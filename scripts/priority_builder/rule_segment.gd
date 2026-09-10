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
## probe skips it with a badge, but it does not itself disable Add Slot.
## Add stays disabled only while an actually empty slot exists.

signal structure_changed
signal delete_requested(segment: RuleSegment)

const TECHNIQUE_BLOCK_SCENE: String = "res://scenes/priority_builder/technique_block.tscn"

@onready var handle: Label = $Rows/Header/Handle
@onready var index_label: Label = $Rows/Header/IndexLabel
@onready var verdict_label: Label = $Rows/Header/VerdictLabel
@onready var delete_button: Button = $Rows/Header/DeleteButton
@onready var condition_body: DropZone = $Rows/ConditionBody
@onready var technique_slot: DropZone = $Rows/TechniqueSlot

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

## Reconstructs this slot's block tree from an already-authored PriorityRule
## -- the reverse of build_rule(), used to reopen the editor with a
## familiar's existing priority_rules already shown rather than blank.
## Conditions are added as flat, top-level, un-nested blocks regardless of
## how the rule's original author might have grouped them -- a flat ANDed
## array can't distinguish a grouping from any other, since nesting was
## always presentation only (see build_rule()/_collect()'s own comment).
## Requires set_tooltip_layer() to have already been called, same ordering
## _on_add_slot_pressed() already relies on.
func load_rule(rule: PriorityRule, all_condition_definitions: Array[ConditionBlockDefinition]) -> void:
	if rule.technique != null:
		var block: TechniqueBlock = load(TECHNIQUE_BLOCK_SCENE).instantiate()
		technique_slot.add_child(block)
		block.setup(rule.technique, _tooltip_layer)

	for condition in rule.conditions:
		var definition: ConditionBlockDefinition = ConditionBlockDefinition.find_matching(condition, all_condition_definitions)
		if definition == null:
			push_warning("No palette definition matches a condition (%s) on rule for %s -- skipped reconstructing it in the editor." % [condition.get_script().resource_path, rule.technique.technique_name if rule.technique != null else "?"])
			continue

		var block: ConditionBlock = load(ConditionBlock.SCENE_PATH).instantiate()
		condition_body.add_child(block)
		block.setup(definition, condition)
		block.structure_changed.connect(_on_block_structure_changed)

	structure_changed.emit()

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

	# A reorder is the list's business, but it has to be forwarded rather
	# than refused: Godot does not reliably bubble _can_drop_data past a
	# MOUSE_FILTER_STOP ancestor, and this node is STOP, so returning false
	# here meant the list was never asked and reordering never worked.
	var list: SegmentList = SegmentList.find_enclosing(self)
	if list != null and list.is_reorder_payload(data):
		list.show_insert_indicator(get_global_transform() * at_position, data["node"])
		return true

	if _is_over(technique_slot, at_position):
		return accepts_technique_drop(data)

	if _is_over(condition_body, at_position):
		return _is_condition_payload(data)

	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var list: SegmentList = SegmentList.find_enclosing(self)
	if list != null and list.is_reorder_payload(data):
		list.reorder_to_global_point(data["node"], get_global_transform() * at_position)
		return

	if _is_over(technique_slot, at_position):
		receive_technique_drop(data)
	elif _is_over(condition_body, at_position):
		_drop_condition(data)

	structure_changed.emit()

## Same approach as ConditionBlock._is_over_body(): transform the event's own
## position to global space rather than doing local rect math (these
## containers are nested under Rows, so their positions are in a different
## space than at_position) and rather than reading the live cursor.
func _is_over(container: Control, at_position: Vector2) -> bool:
	return container.get_global_rect().has_point(get_global_transform() * at_position)

func _is_condition_payload(data: Dictionary) -> bool:
	if data.has("definition"):
		return true
	return data.get("source") == "build" and data.get("node") is ConditionBlock

## One technique per slot -- but landing on an already-filled slot is never
## refused outright. A technique already placed in *another* slot swaps
## with whatever's here (see receive_technique_drop); a fresh palette pick
## just replaces it, discarding the old occupant, since a palette drag has
## no "other slot" to send a displaced technique back to. Public (not
## Godot-virtual-underscore-private) because TechniqueBlock forwards to it
## directly -- see that script's own _can_drop_data for why.
func accepts_technique_drop(data: Dictionary) -> bool:
	if data.has("technique"):
		return true
	if not (data.get("source") == "build" and data.get("node") is TechniqueBlock):
		return false
	return data["node"] != technique_block()

## A dropped technique that lands on an already-filled slot displaces
## whatever's there rather than being refused. A placed technique swaps
## into wherever the dragged one came from (never silently lost); a
## palette pick has nowhere to send the displaced one back to, so it's
## simply replaced.
func receive_technique_drop(data: Dictionary) -> void:
	if data.get("source") == "palette":
		var old: TechniqueBlock = technique_block()
		if old != null:
			technique_slot.remove_child(old)
			old.queue_free()

		var block: TechniqueBlock = load(TECHNIQUE_BLOCK_SCENE).instantiate()
		technique_slot.add_child(block)
		block.setup(data["technique"], _tooltip_layer)
		return

	var dragged: TechniqueBlock = data["node"]
	var origin_slot: Node = dragged.get_parent()
	var existing: TechniqueBlock = technique_block()

	origin_slot.remove_child(dragged)

	if existing != null:
		technique_slot.remove_child(existing)
		origin_slot.add_child(existing)

	technique_slot.add_child(dragged)

func _drop_condition(data: Dictionary) -> void:
	if data.get("source") == "palette":
		var block: ConditionBlock = load(ConditionBlock.SCENE_PATH).instantiate()
		condition_body.add_child(block)
		block.setup(data["definition"])
		block.structure_changed.connect(_on_block_structure_changed)
	else:
		var moved: ConditionBlock = data["node"]
		moved.get_parent().remove_child(moved)
		receive_condition_block(moved)

## Accepts a top-level ConditionBlock at a specific index (or appended, if
## at_index is left negative), connecting its structure_changed the same
## way a normal drop already does. Shared by the drag-drop "moved" path
## above and by ConditionBlock._remove_and_promote_children(), which needs
## to insert promoted children exactly where the block they were nested
## under used to sit, not just at the end.
func receive_condition_block(block: ConditionBlock, at_index: int = -1) -> void:
	condition_body.add_child(block)
	if at_index >= 0:
		condition_body.move_child(block, at_index)
	if not block.structure_changed.is_connected(_on_block_structure_changed):
		block.structure_changed.connect(_on_block_structure_changed)

func _on_block_structure_changed() -> void:
	structure_changed.emit()

## Matches state_probe.gd's own StateProbe.Verdict enum values -- FIRES
## reads cyan (matching the mockup's own "FIRES" state), INCOMPLETE gold,
## UNREACHED/SKIPPED both a muted gray (SKIPPED has no separate mockup
## reference state to match, so it shares UNREACHED's "not happening right
## now" read rather than inventing a fifth color).
const VERDICT_COLORS: Dictionary = {
	StateProbe.Verdict.FIRES: Color(0.243, 0.812, 0.769),
	StateProbe.Verdict.INCOMPLETE: Color(1.0, 0.714, 0.282),
	StateProbe.Verdict.UNREACHED: Color(0.541, 0.561, 0.596),
	StateProbe.Verdict.SKIPPED: Color(0.541, 0.561, 0.596),
}

func set_index(index: int) -> void:
	index_label.text = str(index)

func set_verdict(verdict: StateProbe.Verdict, badge: String, detail: String) -> void:
	verdict_label.text = badge if detail == "" else "%s — %s" % [badge, detail]

	var color: Color = VERDICT_COLORS.get(verdict, Color(0.541, 0.561, 0.596))
	verdict_label.add_theme_color_override("font_color", color)

	var style := StyleBoxFlat.new()
	style.bg_color = Palette.BACKGROUND
	style.border_color = color
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(2)
	add_theme_stylebox_override("panel", style)
