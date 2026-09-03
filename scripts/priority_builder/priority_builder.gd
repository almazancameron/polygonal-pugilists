class_name PriorityBuilder
extends Control

## The priority builder screen. Standalone by design -- it touches neither
## battle.tscn nor battle_controller.gd. It produces an in-memory
## Array[PriorityRule] via SegmentList.compile(); nothing consumes it yet.
##
## This is the prototype for the in-run priority-rule editor that
## GAME_DESIGN.md names as the replacement for the PriorityBuild stopgap.

const BLOCK_DIR: String = "res://resources/priority_builder/blocks"

## Authored palette order, matching the order the definitions were written
## in. Left empty, _definitions() falls back to a fixed list so the scene
## works the moment it is opened.
const DEFINITION_ORDER: Array[String] = [
	"status_vs_value", "status_vs_status", "all_stacks_vs_value",
	"hp_vs_percent", "hp_vs_value", "hp_vs_hp",
	"stat_vs_value", "stat_vs_stat", "not",
]

@export var builder_familiar: Familiar
@export var opponent_familiar: Familiar

## Exported rather than directory-scanned so the palette's order is
## authored, the same way battle_controller.gd exports available_builds.
@export var block_definitions: Array[ConditionBlockDefinition] = []

@onready var tooltip_layer: TooltipLayer = $TooltipLayer/TooltipContainer

@onready var familiar_name_label: Label = $Columns/LeftColumn/FamiliarPanel/Rows/NameLabel
@onready var portrait: TextureRect = $Columns/LeftColumn/FamiliarPanel/Rows/Portrait
@onready var stat_grid: GridContainer = $Columns/LeftColumn/FamiliarPanel/Rows/StatGrid
@onready var technique_palette: BlockPalette = $Columns/LeftColumn/TechniqueScroll/TechniquePalette

@onready var add_slot_button: Button = $Columns/BuildColumn/Header/AddSlotButton
@onready var segment_list: SegmentList = $Columns/BuildColumn/BuildScroll/SegmentList

@onready var condition_palette: BlockPalette = $Columns/RightColumn/ConditionScroll/ConditionPalette
@onready var state_probe: StateProbe = $Columns/RightColumn/StateProbe
@onready var probe_controls: VBoxContainer = $Columns/RightColumn/StateProbe/Rows/Controls
@onready var probe_message: Label = $Columns/RightColumn/StateProbe/Rows/Message

func _ready() -> void:
	state_probe.setup(builder_familiar, opponent_familiar)
	state_probe.build_controls(probe_controls)
	state_probe.state_changed.connect(_refresh)

	familiar_name_label.text = builder_familiar.familiar_name
	portrait.texture = builder_familiar.sprite

	condition_palette.populate_conditions(_definitions())
	technique_palette.populate_techniques(builder_familiar.techniques, tooltip_layer)

	segment_list.structure_changed.connect(_refresh)
	add_slot_button.pressed.connect(_on_add_slot_pressed)

	# Start with one empty slot so the screen is never a blank canvas with
	# no obvious first move.
	_on_add_slot_pressed()

## Clicking anywhere outside a focused input releases it.
##
## Godot keeps focus on a LineEdit until something else focusable takes it,
## and almost nothing on this screen is focusable -- so without this the
## caret stays parked in a spin box while you go on dragging blocks around.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null:
		return

	# A SpinBox's LineEdit is a child of the SpinBox, and the up/down arrows
	# sit outside the LineEdit's own rect -- measure against the SpinBox so
	# that clicking its arrows doesn't drop focus mid-edit.
	var region: Control = focused
	if focused.get_parent() is SpinBox:
		region = focused.get_parent()

	if not region.get_global_rect().has_point(event.global_position):
		focused.release_focus()

func _definitions() -> Array[ConditionBlockDefinition]:
	if not block_definitions.is_empty():
		return block_definitions

	var found: Array[ConditionBlockDefinition] = []
	for definition_name in DEFINITION_ORDER:
		var definition: ConditionBlockDefinition = load("%s/%s.tres" % [BLOCK_DIR, definition_name])
		if definition != null:
			found.append(definition)
	return found

func _on_add_slot_pressed() -> void:
	var segment: RuleSegment = segment_list.add_segment()
	segment.set_tooltip_layer(tooltip_layer)
	_refresh()

func _refresh() -> void:
	# Never more than one empty slot at a time.
	add_slot_button.disabled = segment_list.has_empty_segment()

	state_probe.evaluate(segment_list.compile())

	_refresh_stats()

	var messages: Array[String] = []
	if state_probe.no_match_message() != "":
		messages.append(state_probe.no_match_message())
	if state_probe.mismatch_message() != "":
		messages.append("EVALUATOR MISMATCH: %s" % state_probe.mismatch_message())
	probe_message.text = "\n".join(messages)

## Base stats, plus the effective value when a declared status changes it
## (Hone, Fortify, Enlarge, Ruin). stat_vs_value conditions read the
## effective one, so showing only the base would mislead.
func _refresh_stats() -> void:
	# remove_child as well as queue_free: queue_free is deferred, so
	# rebuilding in the same frame would otherwise append alongside the
	# outgoing labels.
	for child in stat_grid.get_children():
		stat_grid.remove_child(child)
		child.queue_free()

	for stat in Familiar.Stat.values():
		var name_label := Label.new()
		name_label.text = Familiar.stat_name(stat)
		stat_grid.add_child(name_label)

		var base: int = builder_familiar.get_stat(stat)
		var effective: int = state_probe.user.effective_stat(stat)

		var value_label := Label.new()
		value_label.text = str(base) if base == effective else "%d → %d" % [base, effective]
		stat_grid.add_child(value_label)
