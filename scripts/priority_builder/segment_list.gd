class_name SegmentList
extends VBoxContainer

## The ordered list of rule slots, and the single place the block tree turns
## into Array[PriorityRule]. Display order is priority order.

signal structure_changed

const RULE_SEGMENT_SCENE: PackedScene = preload("res://scenes/priority_builder/rule_segment.tscn")

var _indicator: ColorRect

func _ready() -> void:
	# Drop-position indicator for reordering. A child of this list, but
	# segments() filters on `child is RuleSegment`, so it never counts as one.
	_indicator = ColorRect.new()
	_indicator.name = "InsertIndicator"
	_indicator.color = Color(1, 1, 1, 0.6)
	_indicator.custom_minimum_size = Vector2(0, 2)
	_indicator.visible = false
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_indicator)

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
	# wait until it actually leaves the tree before recomputing.
	await segment.tree_exited
	_refresh_indices()
	structure_changed.emit()

func _refresh_indices() -> void:
	var rank: int = 1
	for segment in segments():
		segment.set_index(rank)
		rank += 1

## True while any slot is entirely empty. Gates the Add Slot button, so
## there is never more than one empty slot at a time.
func has_empty_segment() -> bool:
	for segment in segments():
		if segment.is_empty():
			return true
	return false

## Compiles complete slots to rules, in display order, and reports the
## incomplete ones separately so they can be badged rather than crashing
## the evaluator.
##
## rules[i] corresponds to segments[i] by construction. That pairing is
## built here, in one function, rather than inferred from
## choose_technique()'s flat skip_reasons array -- which would couple the UI
## to that loop's internal append order.
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
## each existing segment's vertical midpoint.
func insert_index_for_y(y: float) -> int:
	var index: int = 0
	for segment in segments():
		if y < segment.position.y + segment.size.y * 0.5:
			return index
		index += 1
	return index

## Walks ancestors to find the enclosing list.
##
## Drop targets nested inside a segment need this to hand a reorder off.
## Godot's _can_drop_data does not reliably bubble past a MOUSE_FILTER_STOP
## ancestor, and RuleSegment is STOP -- so the original design, where a
## segment returned false for a reorder payload and expected the query to
## reach this list, meant the list was simply never asked and reordering
## silently did nothing.
static func find_enclosing(from: Node) -> SegmentList:
	var node: Node = from
	while node != null:
		if node is SegmentList:
			return node
		node = node.get_parent()
	return null

func is_reorder_payload(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	return data.get("source") == "build" and data.get("node") is RuleSegment

## Positions and shows the insertion line for a point in global space.
func show_insert_indicator(global_point: Vector2) -> void:
	var local: Vector2 = get_global_transform().affine_inverse() * global_point
	move_child(_indicator, insert_index_for_y(local.y))
	_indicator.visible = true

func hide_insert_indicator() -> void:
	if _indicator != null:
		_indicator.visible = false

func reorder_to_global_point(segment: RuleSegment, global_point: Vector2) -> void:
	hide_insert_indicator()

	if segment.get_parent() != self:
		return

	var local: Vector2 = get_global_transform().affine_inverse() * global_point
	move_child(segment, clampi(insert_index_for_y(local.y), 0, get_child_count() - 1))
	_refresh_indices()
	structure_changed.emit()

## Handles drops that land in the gaps between segments; a drop on a segment
## itself is forwarded here by RuleSegment.
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not is_reorder_payload(data):
		hide_insert_indicator()
		return false

	# _can_drop_data runs every frame while a drag hovers, which is what
	# makes it the right place to move the insertion indicator.
	show_insert_indicator(get_global_transform() * at_position)
	return true

func _drop_data(at_position: Vector2, data: Variant) -> void:
	reorder_to_global_point(data["node"], get_global_transform() * at_position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		hide_insert_indicator()
