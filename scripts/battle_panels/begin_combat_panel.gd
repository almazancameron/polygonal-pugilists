class_name BeginCombatPanel
extends Control

## Pre-fight screen (GAME_DESIGN.md §9.2 step 4's entry point): both
## fighters' name/portrait/stats side by side, a round label, and
## "Open Priority Builder" (only when there's something to open it into)
## alongside "Begin Combat". battle_controller.gd keeps ownership of the
## actual pre-fight choice flow -- including the "you haven't edited your
## priorities" confirmation dialog -- since that depends on cross-round
## priority-editor state this screen has no reason to know about; this
## panel only ever needs to say *which* button was pressed.

signal begin_requested
signal priority_builder_requested

const PREFIGHT_HP_BAR_SCENE: PackedScene = preload("res://scenes/hp_bar.tscn")

@onready var round_label: Label = $Content/TitleBlock/RoundLabel
@onready var player_name_label: Label = $Content/CardsRow/PlayerCard/Content/NameLabel
@onready var player_portrait: TextureRect = $Content/CardsRow/PlayerCard/Content/StatsRow/PortraitFrame/Center/Portrait
@onready var player_stat_list: VBoxContainer = $Content/CardsRow/PlayerCard/Content/StatsRow/StatList
@onready var opponent_name_label: Label = $Content/CardsRow/OpponentCard/Content/NameLabel
@onready var opponent_portrait: TextureRect = $Content/CardsRow/OpponentCard/Content/StatsRow/PortraitFrame/Center/Portrait
@onready var opponent_stat_list: VBoxContainer = $Content/CardsRow/OpponentCard/Content/StatsRow/StatList
@onready var priority_builder_button: Button = $Content/ButtonsRow/PriorityBuilderButton
@onready var begin_button: Button = $Content/ButtonsRow/BeginButton


func _ready() -> void:
	priority_builder_button.pressed.connect(func() -> void: priority_builder_requested.emit())
	begin_button.pressed.connect(func() -> void: begin_requested.emit())


func show_for(player_familiar: Familiar, opponent_familiar: Familiar, round_text: String, show_priority_option: bool) -> void:
	round_label.text = round_text
	_populate_fighter_card(player_familiar, player_name_label, player_portrait, player_stat_list)
	_populate_fighter_card(opponent_familiar, opponent_name_label, opponent_portrait, opponent_stat_list)
	priority_builder_button.visible = show_priority_option
	visible = true


func priority_option_visible() -> bool:
	return priority_builder_button.visible


## Mirrors battle_controller.gd's own _populate_fighter_card() (icon +
## label + value rows, Max HP shown as an actual HPBar rather than a plain
## number) -- duplicated here rather than shared, following this
## codebase's existing convention for this exact read-only card layout
## (see that function's own docstring, and BuildViewPanel's identical copy).
func _populate_fighter_card(familiar: Familiar, name_label: Label, portrait: TextureRect, stat_list: VBoxContainer) -> void:
	name_label.text = familiar.familiar_name
	portrait.texture = familiar.sprite

	for child in stat_list.get_children():
		stat_list.remove_child(child)
		child.queue_free()

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	stat_list.add_child(hp_row)

	var hp_icon := TextureRect.new()
	hp_icon.texture = Familiar.stat_icon(Familiar.Stat.MAX_HP)
	hp_icon.custom_minimum_size = Vector2(24, 24)
	hp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	hp_icon.modulate = Palette.HP_ICON
	hp_row.add_child(hp_icon)

	var hp_name_label := Label.new()
	hp_name_label.text = Familiar.stat_name(Familiar.Stat.MAX_HP)
	hp_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_name_label.add_theme_font_size_override("font_size", 22)
	hp_row.add_child(hp_name_label)

	var hp_bar: HPBar = PREFIGHT_HP_BAR_SCENE.instantiate()
	hp_bar.custom_minimum_size = Vector2(110, 24)
	hp_row.add_child(hp_bar)

	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Palette.HP_TRACK
	hp_bar.bar_background_style = background_style
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Palette.HP_FULL
	hp_bar.bar_fill_style = fill_style
	hp_bar.heart_icon.visible = false
	hp_bar.set_hp(familiar.max_hp, familiar.max_hp)

	for stat in Familiar.Stat.values():
		if stat == Familiar.Stat.MAX_HP:
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		stat_list.add_child(row)

		var icon := TextureRect.new()
		icon.texture = Familiar.stat_icon(stat)
		icon.custom_minimum_size = Vector2(24, 24)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		icon.modulate = Palette.TEXT_MUTED
		row.add_child(icon)

		var row_name_label := Label.new()
		row_name_label.text = Familiar.stat_name(stat)
		row_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_name_label.add_theme_font_size_override("font_size", 22)
		row.add_child(row_name_label)

		var value_label := Label.new()
		value_label.text = str(familiar.get_stat(stat))
		value_label.add_theme_font_size_override("font_size", 22)
		row.add_child(value_label)
