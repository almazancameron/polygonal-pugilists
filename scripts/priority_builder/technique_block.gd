class_name TechniqueBlock
extends PanelContainer

## A technique placed in a rule slot. Unlike ConditionBlock this holds a
## reference to the shared Technique .tres rather than a fresh copy: the
## builder only ever references a technique, never edits one, so there is
## nothing to alias. Conditions differ because their fields get written by
## the block's own widgets.

@onready var name_label: Label = $NameLabel

var technique: Technique

var _tooltip_layer: TooltipLayer

func setup(technique_data: Technique, layer: TooltipLayer) -> void:
	technique = technique_data
	_tooltip_layer = layer
	name_label.text = technique.technique_name

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

## Dragging a placed technique carries the node itself, so dragging out of a
## slot and dragging between slots are one path.
func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = technique.technique_name if technique != null else "technique"
	set_drag_preview(preview)
	return {"source": "build", "node": self}
