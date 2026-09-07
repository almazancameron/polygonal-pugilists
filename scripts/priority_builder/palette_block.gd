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

@onready var icon_rect: TextureRect = $Row/Icon
@onready var name_label: Label = $Row/Texts/NameLabel
@onready var subtitle_label: Label = $Row/Texts/SubtitleLabel

var definition: ConditionBlockDefinition
var technique: Technique
var passive: PassiveEffect

var _tooltip_layer: TooltipLayer

## One representative icon/color per condition palette category -- these
## are generic sentence-shape templates ("Status stacks vs value"), not one
## badge per specific status, so a single per-category look is honest about
## what the block actually is rather than implying a specific status.
const CATEGORY_ICONS: Dictionary = {
	"Status": preload("res://assets/sprites/icons/burn_icon.tres"),
	"HP": preload("res://assets/sprites/icons/max_hp_icon.tres"),
	"Stat": preload("res://assets/sprites/icons/focus_icon.tres"),
}
const CATEGORY_COLORS: Dictionary = {
	"Status": Color(0.976, 0.451, 0.086),
	"HP": Color(0.898, 0.224, 0.208),
	"Stat": Color(0.243, 0.812, 0.769),
	"Logic": Color(0.541, 0.561, 0.596),
}

const TECHNIQUE_ICON: Texture2D = preload("res://assets/sprites/icons/power_icon.tres")
const PASSIVE_ICON: Texture2D = preload("res://assets/sprites/icons/defense_icon.tres")

func setup_condition(block_definition: ConditionBlockDefinition) -> void:
	definition = block_definition
	name_label.text = definition.block_label

	var color: Color = CATEGORY_COLORS.get(definition.category, Palette.TEXT_MUTED)
	_style(color)

	var icon: Texture2D = CATEGORY_ICONS.get(definition.category)
	icon_rect.visible = icon != null
	if icon != null:
		icon_rect.texture = icon
		icon_rect.modulate = color

	subtitle_label.visible = false

func setup_technique(technique_data: Technique, layer: TooltipLayer) -> void:
	technique = technique_data
	_tooltip_layer = layer
	name_label.text = technique.technique_name

	_style(Palette.PLAYER_ACCENT)
	icon_rect.texture = TECHNIQUE_ICON
	icon_rect.modulate = Palette.PLAYER_ACCENT
	icon_rect.visible = true

	subtitle_label.visible = technique.has_scaling_hit()
	if subtitle_label.visible:
		subtitle_label.text = "Power ×%s" % _format_multiplier(technique.power_multiplier)

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
	name_label.text = passive.passive_name

	_style(Palette.GOLD_ACCENT)
	icon_rect.texture = PASSIVE_ICON
	icon_rect.modulate = Palette.GOLD_ACCENT
	icon_rect.visible = true

	subtitle_label.text = "Passive"
	subtitle_label.visible = true

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

## One shared look for every use: dark fill, a border in whatever color
## this instance's category/type is, notch-free corners (a plain small
## rectangle reads better than FramedPanel's notch at this size).
func _style(color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.BACKGROUND
	style.border_color = color
	style.set_border_width_all(2)
	style.set_content_margin_all(6)
	style.set_corner_radius_all(2)
	add_theme_stylebox_override("panel", style)
	name_label.add_theme_color_override("font_color", color)

## power_multiplier is authored from a fixed set of increments (see
## LEARNING_ROADMAP/DECISIONS on the power multiplier scale), not free
## decimals -- trims to e.g. "1" or "0.33" instead of "1.00"/"0.330000".
func _format_multiplier(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(round(value)))
	return ("%.2f" % value).rstrip("0").rstrip(".")

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
	preview.text = name_label.text
	set_drag_preview(preview)

	if definition != null:
		return {"source": "palette", "definition": definition}
	if technique != null:
		return {"source": "palette", "technique": technique}
	return null
