class_name PriorityBuilder
extends Control

## The priority-rule editor. Playable standalone (builder_familiar/
## opponent_familiar assigned via the Inspector, as originally built) and
## embedded live in battle.tscn, shown once per round from
## battle_controller.gd's advance_to_priority_editor() -- setup() is what
## makes the second case possible, since the opponent (and the player's own
## techniques/priority_rules) change every round, not just once at startup.
##
## Produces an Array[PriorityRule] via SegmentList.compile()/compiled_rules();
## confirm_requested signals a caller that the player is done.

signal confirm_requested

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
@onready var passive_palette: BlockPalette = $Columns/LeftColumn/PassiveScroll/PassivePalette

@onready var add_slot_button: Button = $Columns/BuildColumn/Header/AddSlotButton
@onready var confirm_button: Button = $Columns/BuildColumn/Header/ConfirmButton
@onready var segment_list: SegmentList = $Columns/BuildColumn/BuildScroll/SegmentList

@onready var condition_palette: BlockPalette = $Columns/RightColumn/ConditionScroll/ConditionPalette
@onready var state_probe: StateProbe = $Columns/RightColumn/StateProbe
@onready var probe_controls: VBoxContainer = $Columns/RightColumn/StateProbe/Rows/Controls
@onready var probe_message: Label = $Columns/RightColumn/StateProbe/Rows/Message

## True once anything has structurally changed since the last setup() call
## -- i.e. the player actually touched the build area this session (not
## just the mock probe, which doesn't affect what gets saved). Public so
## battle_controller.gd's pre-fight screen can tell "opened and edited"
## apart from "opened and just looked" across possibly several open/close
## cycles in one round -- it accumulates its own round-level flag from
## this, since this one resets on every setup() call and a single session
## is all it can see. Reset to false at the end of every setup(), after
## that call's own reconstruction has already (harmlessly) flipped it true
## via the same signal a real edit would use.
var has_unsaved_changes: bool = false

func _ready() -> void:
	state_probe.state_changed.connect(_refresh)
	segment_list.structure_changed.connect(_on_build_structure_changed)
	add_slot_button.pressed.connect(_on_add_slot_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)

	# Only true when opened as the standalone scene, with both exports
	# already assigned in the Inspector -- battle_controller.gd instead
	# calls setup() itself once it has a real familiar/opponent to hand over.
	if builder_familiar != null:
		setup(builder_familiar, opponent_familiar)

func _on_build_structure_changed() -> void:
	has_unsaved_changes = true
	state_probe.reset_simulation(segment_list.compile()["rules"])
	_refresh()

## No "did anything actually change" gate here any more -- battle_controller.gd's
## pre-fight screen now owns that question (a player who skips the editor
## entirely, or opens and confirms it without editing, gets asked there).
func _on_confirm_pressed() -> void:
	confirm_requested.emit()

## Rebuilds every familiar-dependent part of the screen from scratch: the
## familiar panel, both palettes, the mock-state probe, and one segment per
## already-authored priority_rules entry (reconstructed via
## RuleSegment.load_rule()) so reopening the editor shows what the player
## already has, not a blank canvas -- required by GAME_DESIGN.md §9.2 step 4.
## Called once from _ready() for the standalone scene, and again by
## battle_controller.gd every round, since the opponent (and the player's
## own techniques/priority_rules) both change round to round.
func setup(familiar: Familiar, opponent: Familiar) -> void:
	builder_familiar = familiar
	opponent_familiar = opponent

	# remove_child immediately, queue_free to actually release afterward --
	# same reasoning as BlockPalette._clear(): queue_free() alone leaves the
	# outgoing segments still counted as children for the rest of this frame,
	# which would double up with the freshly-loaded ones added below.
	for segment in segment_list.segments():
		segment_list.remove_child(segment)
		segment.queue_free()

	state_probe.setup(builder_familiar, opponent_familiar)
	state_probe.build_controls(probe_controls, tooltip_layer)

	familiar_name_label.text = builder_familiar.familiar_name
	portrait.texture = builder_familiar.sprite

	condition_palette.populate_conditions(_definitions())
	technique_palette.populate_techniques(builder_familiar.techniques, tooltip_layer)
	passive_palette.populate_passives(builder_familiar.passives, tooltip_layer)

	for rule in builder_familiar.priority_rules:
		var segment: RuleSegment = segment_list.add_segment()
		segment.set_tooltip_layer(tooltip_layer)
		segment.load_rule(rule, _definitions())

	# No auto-added trailing empty slot: the screen shows exactly what the
	# familiar already has. "+ Add slot" is right there whenever the player
	# actually wants a new one -- an empty slot nobody asked for on every
	# single reopen just reads as clutter.
	_refresh()

	# The reconstruction above legitimately flows through the same
	# structure_changed path a real edit does (loading segments, connecting
	# blocks) -- consume that now so has_unsaved_changes accurately reflects
	# only what happens after setup() returns.
	has_unsaved_changes = false

## The single accessor battle_controller.gd needs once the player confirms --
## keeps it from reaching through priority_builder.segment_list.compile()
## itself.
func compiled_rules() -> Array[PriorityRule]:
	return segment_list.compile()["rules"]

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
