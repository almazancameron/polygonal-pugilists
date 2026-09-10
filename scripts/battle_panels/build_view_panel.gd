class_name BuildViewPanel
extends Control

## Read-only look at the player's current build from the reward screen --
## the mockup's "[Z] INSPECT" hint, but as an actual button rather than a
## keyboard-only affordance. Reuses the same familiar-card and
## PaletteBlock-list patterns already established for the priority
## builder/prefight/stat-upgrade screens rather than the plain Labels a
## first pass might reach for.
##
## Fully self-contained: battle_controller.gd only ever calls show_for()
## and never reaches into this panel's own nodes -- CloseButton is wired
## and handled entirely inside this script.

const PALETTE_BLOCK_SCENE: PackedScene = preload("res://scenes/priority_builder/palette_block.tscn")
const CARD_HP_BAR_SCENE: PackedScene = preload("res://scenes/hp_bar.tscn")

@onready var close_button: Button = $CloseButton
@onready var name_label: Label = $Content/FamiliarCard/Content/NameLabel
@onready var portrait: TextureRect = $Content/FamiliarCard/Content/PortraitFrame/Center/Portrait
@onready var stat_list: VBoxContainer = $Content/FamiliarCard/Content/StatList
@onready var technique_list: VBoxContainer = $Content/RightColumn/TechniquesCard/TechniqueList
@onready var passive_list: VBoxContainer = $Content/RightColumn/PassivesCard/PassiveList


func _ready() -> void:
	close_button.pressed.connect(func() -> void: visible = false)


func show_for(familiar: Familiar, tooltip_layer: TooltipLayer) -> void:
	_populate_fighter_card(familiar)

	for child in technique_list.get_children():
		child.queue_free()
	for technique in familiar.techniques:
		var technique_block: PaletteBlock = PALETTE_BLOCK_SCENE.instantiate()
		technique_list.add_child(technique_block)
		technique_block.setup_technique(technique, tooltip_layer)

	for child in passive_list.get_children():
		child.queue_free()
	for passive in familiar.passives:
		var passive_block: PaletteBlock = PALETTE_BLOCK_SCENE.instantiate()
		passive_list.add_child(passive_block)
		passive_block.setup_passive(passive, tooltip_layer)

	visible = true


## Panel-local read-only fighter card: icon/label/value rows with an HPBar
## for max HP. BeginCombatPanel, BuildViewPanel and StatUpgradePanel each
## retain their own helper to keep their layouts owned by the screen.
func _populate_fighter_card(familiar: Familiar) -> void:
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

	var hp_bar: HPBar = CARD_HP_BAR_SCENE.instantiate()
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
