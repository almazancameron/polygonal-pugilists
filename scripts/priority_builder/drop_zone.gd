class_name DropZone
extends VBoxContainer

## A visibly-marked drop target: tinted fill, dashed border, a minimum height
## so it is always hittable, and a placeholder message while empty.
##
## The minimum height is not cosmetic. An empty Container has zero size, so
## before this existed a fresh condition block's body was a nought-pixel drop
## target and nesting was impossible with a mouse.
##
## Purely presentational -- mouse_filter stays IGNORE so the enclosing
## ConditionBlock / RuleSegment remains the hit target and keeps receiving the
## drag virtuals with positions in its own coordinate space.

@export var empty_text: String = "drop here":
	set(value):
		empty_text = value
		if _placeholder != null:
			_placeholder.text = value

@export var empty_height: float = 38.0:
	set(value):
		empty_height = value
		custom_minimum_size.y = value

@export var fill_color: Color = Color(1, 1, 1, 0.04)
@export var border_color: Color = Color(1, 1, 1, 0.28)
@export var dash_length: float = 6.0

var _placeholder: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = empty_height

	_placeholder = Label.new()
	_placeholder.name = "Placeholder"
	_placeholder.text = empty_text
	_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placeholder.modulate = Color(1, 1, 1, 0.4)
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_placeholder)

	child_entered_tree.connect(_on_children_changed)
	child_exiting_tree.connect(_on_children_changed)
	resized.connect(queue_redraw)

	_refresh_placeholder()

func _on_children_changed(_node: Node) -> void:
	# child_exiting_tree fires *before* the child is actually gone, so defer
	# the recount rather than reading a stale child list.
	_refresh_placeholder.call_deferred()

## Anything that is not the placeholder itself counts as content. Blocks are
## matched by absence rather than by type so this script needs to know
## nothing about ConditionBlock or TechniqueBlock.
func has_content() -> bool:
	for child in get_children():
		if child != _placeholder:
			return true
	return false

func _refresh_placeholder() -> void:
	if _placeholder == null or not is_instance_valid(_placeholder):
		return
	# An invisible child is skipped by VBoxContainer's layout, so hiding it
	# also reclaims its space once a real block lands here.
	_placeholder.visible = not has_content()
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, fill_color, true)

	# Godot has no dashed-rect primitive, so draw the four edges as dashed
	# lines, inset half a pixel so the stroke lands inside the rect.
	var inset := 1.0
	var top_left := Vector2(inset, inset)
	var top_right := Vector2(size.x - inset, inset)
	var bottom_right := Vector2(size.x - inset, size.y - inset)
	var bottom_left := Vector2(inset, size.y - inset)

	draw_dashed_line(top_left, top_right, border_color, 1.0, dash_length)
	draw_dashed_line(top_right, bottom_right, border_color, 1.0, dash_length)
	draw_dashed_line(bottom_right, bottom_left, border_color, 1.0, dash_length)
	draw_dashed_line(bottom_left, top_left, border_color, 1.0, dash_length)
