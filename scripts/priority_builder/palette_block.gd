class_name PaletteBlock
extends PanelContainer

## A draggable entry in either palette. Never leaves the palette -- dragging
## it hands over a *description* of what to build (a definition, or a
## technique reference), and the drop target constructs the real block.
##
## That indirection is what keeps a shared ConditionBlockDefinition from
## ever being handed out as a live editable Condition. See DECISIONS.md on
## the fallback_attack.tres incident, where editing a resource shared
## between two owners silently changed both.

@onready var label: Label = $Label

var definition: ConditionBlockDefinition
var technique: Technique
var passive: PassiveEffect

var _tooltip_layer: TooltipLayer

func setup_condition(block_definition: ConditionBlockDefinition) -> void:
	definition = block_definition
	label.text = definition.block_label

func setup_technique(technique_data: Technique, layer: TooltipLayer) -> void:
	technique = technique_data
	_tooltip_layer = layer
	label.text = technique.technique_name
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

## Read-only reference display -- a familiar's passives aren't picked or
## arranged, just shown so the player can see and hover what they have.
## Deliberately not draggable: _get_drag_data() below only returns a
## payload for definition/technique, so a passive-configured block simply
## never produces a drag, no separate "is this draggable" flag needed.
func setup_passive(passive_data: PassiveEffect, layer: TooltipLayer) -> void:
	passive = passive_data
	_tooltip_layer = layer
	label.text = passive.passive_name
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if _tooltip_layer == null:
		return
	if technique != null:
		_tooltip_layer.hover_started(self, technique.describe())
	elif passive != null:
		_tooltip_layer.hover_started(self, passive.describe())

func _on_mouse_exited() -> void:
	if _tooltip_layer != null:
		_tooltip_layer.hover_ended(self)

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = label.text
	set_drag_preview(preview)

	if definition != null:
		return {"source": "palette", "definition": definition}
	if technique != null:
		return {"source": "palette", "technique": technique}
	return null
