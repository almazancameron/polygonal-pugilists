class_name TechniqueBlock
extends PanelContainer

## A technique placed in a rule slot. Unlike ConditionBlock this holds a
## reference to the shared Technique .tres rather than a fresh copy: the
## builder only ever references a technique, never edits one, so there is
## nothing to alias. Conditions differ because their fields get written by
## the block's own widgets.

@onready var icon_rect: TextureRect = $Row/Icon
@onready var name_label: Label = $Row/NameLabel

const ICON: Texture2D = preload("res://assets/sprites/icons/power_icon.tres")

var technique: Technique

var _tooltip_layer: TooltipLayer

func setup(technique_data: Technique, layer: TooltipLayer) -> void:
	technique = technique_data
	_tooltip_layer = layer
	name_label.text = technique.technique_name
	name_label.add_theme_color_override("font_color", Palette.PLAYER_ACCENT)
	icon_rect.texture = ICON
	icon_rect.modulate = Palette.PLAYER_ACCENT

	var style := StyleBoxFlat.new()
	style.bg_color = Palette.BACKGROUND
	style.border_color = Palette.PLAYER_ACCENT
	style.set_border_width_all(2)
	style.set_content_margin_all(6)
	style.set_corner_radius_all(2)
	add_theme_stylebox_override("panel", style)

	# Same wiring battle_controller.gd uses for upgrade buttons --
	# TooltipLayer replaces Godot's built-in tooltip_text entirely, since the
	# built-in popup's timing can't be paused or persisted.
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if _tooltip_layer != null and technique != null:
		_tooltip_layer.hover_started(self, technique.describe())

func _on_mouse_exited() -> void:
	if _tooltip_layer != null:
		_tooltip_layer.hover_ended(self)

## Right-click removes this technique from whatever slot holds it. The
## slot's own DropZone (technique_slot) already listens for
## child_exiting_tree, so removing self here is enough to notify the
## owning RuleSegment -- no signal to emit by hand.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		return
	accept_event()
	if _tooltip_layer != null:
		_tooltip_layer.hover_ended(self)
	var parent: Node = get_parent()
	if parent != null:
		parent.remove_child(self)
	queue_free()

## Dragging a placed technique carries the node itself, so dragging out of a
## slot and dragging between slots are one path.
func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = technique.technique_name if technique != null else "technique"
	set_drag_preview(preview)
	return {"source": "build", "node": self}

## Forwards to the enclosing RuleSegment's own technique-drop handling.
## Needed because this block's own (default STOP) mouse filter is what
## Godot's drag-drop dispatch hits first once a slot is occupied -- an
## unimplemented _can_drop_data here silently refuses without bubbling any
## further, making the technique's own name (the most obvious place to aim
## a drop at) a dead zone, leaving only whatever thin sliver of the
## surrounding DropZone happens to still be exposed. Same class of gap
## ConditionBlock/RuleSegment already forward reorder payloads around.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var segment: RuleSegment = _enclosing_segment()
	return segment != null and segment.accepts_technique_drop(data)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var segment: RuleSegment = _enclosing_segment()
	if segment != null:
		segment.receive_technique_drop(data)
		# RuleSegment._drop_data() always re-emits structure_changed as its
		# own last step, which is what re-evaluates completeness *after*
		# the new block's setup() has actually run -- add_child() alone
		# fires an earlier, transient evaluation while the block is still
		# unconfigured (technique == null), same gap already documented on
		# RuleSegment.is_complete(). Forwarding straight to
		# receive_technique_drop() bypasses that trailing emit entirely,
		# so it has to be repeated here or a replace-in-place drop is left
		# showing stale "no technique" -- found live, not from reading the
		# code alone.
		segment.structure_changed.emit()

func _enclosing_segment() -> RuleSegment:
	var node: Node = get_parent()
	while node != null:
		if node is RuleSegment:
			return node
		node = node.get_parent()
	return null
