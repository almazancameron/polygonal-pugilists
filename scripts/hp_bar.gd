@tool
class_name HPBar
extends Control

@onready var label: Label = $Bar/Label
@onready var bar: ProgressBar = $Bar
@onready var status_preview: Control = $StatusPreview
@onready var heart_icon: TextureRect = $HeartIcon

const HEART_TEXTURE: Texture2D = preload("res://assets/sprites/icons/max_hp_icon.tres")


@export var bar_background_style: StyleBox:
	set(value):
		bar_background_style = value
		var target_bar = get_node_or_null("Bar") as ProgressBar
		if target_bar:
			target_bar.add_theme_stylebox_override("background", value)


@export var bar_fill_style: StyleBox:
	set(value):
		bar_fill_style = value
		var target_bar = get_node_or_null("Bar") as ProgressBar
		if target_bar:
			target_bar.add_theme_stylebox_override("fill", value)


func set_hp(current: int, max_hp: int) -> void:
	bar.max_value = max_hp
	bar.value = current
	label.text = "%d / %d" % [current, max_hp]

	var fill_style := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style == null:
		fill_style = StyleBoxFlat.new()
	var hp_fraction: float = float(current) / float(max_hp) if max_hp > 0 else 0.0
	fill_style.bg_color = Palette.HP_FULL if hp_fraction > 0.30 else Palette.HP_LOW
	bar.add_theme_stylebox_override("fill", fill_style)


## segments: each {"color": Color, "damage": int}, drawn back-to-back eating
## into the current fill's right edge -- one chunk per active status, sized
## to the damage it'll deal on its next tick. Purely visual: this function
## has no idea what a "status" is, it just draws colored amounts.
func set_status_preview_segments(segments: Array[Dictionary]) -> void:
	for child in status_preview.get_children():
		child.free()

	if bar.max_value <= 0:
		return

	var pixels_per_hp: float = status_preview.size.x / bar.max_value
	var remaining_edge_hp: float = bar.value

	for segment in segments:
		var seg_hp: float = clamp(float(segment.get("damage", 0)), 0.0, remaining_edge_hp)
		if seg_hp <= 0.0:
			continue
		remaining_edge_hp -= seg_hp

		var rect := ColorRect.new()
		rect.color = segment.get("color", Color.WHITE)
		rect.position = Vector2(remaining_edge_hp * pixels_per_hp, 0)
		rect.size = Vector2(seg_hp * pixels_per_hp, status_preview.size.y)
		status_preview.add_child(rect)


func _ready() -> void:
	# Null when instantiated without per-instance style overrides authored
	# (e.g. state_probe.gd's mock HP bars) -- add_theme_stylebox_override()
	# requires a non-null StyleBox, so skip rather than error; the bar just
	# falls back to the default theme in that case.
	if bar_background_style != null:
		bar.add_theme_stylebox_override("background", bar_background_style)
	if bar_fill_style != null:
		bar.add_theme_stylebox_override("fill", bar_fill_style)
	heart_icon.texture = HEART_TEXTURE
	heart_icon.modulate = Palette.HP_ICON
