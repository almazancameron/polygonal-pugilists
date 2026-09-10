class_name StatUpgradePanel
extends Control

## Mandatory stat-allocation pass (Phase A) that follows every reward
## round -- battle_controller.gd hands this panel the RewardFlowController
## already tracking the current allocation session (it owns begin_stat_phase()/
## try_allocate()/confirm_stat_phase() -- this panel only ever reads
## available_points/allocated off it and calls try_allocate()) rather than
## this panel owning that state itself, since the same session also spans
## the reward-cards screen elsewhere. Confirming is signalled outward
## rather than applied here, since applying it also means healing the
## familiar back to full and refreshing the battle HUD -- both outside
## this panel's own remit.

signal confirmed

const STAT_UPGRADE_ROW_SCENE: PackedScene = preload("res://scenes/stat_upgrade_row.tscn")
const PALETTE_BLOCK_SCENE: PackedScene = preload("res://scenes/priority_builder/palette_block.tscn")
const PREFIGHT_HP_BAR_SCENE: PackedScene = preload("res://scenes/hp_bar.tscn")

@onready var name_label: Label = $Content/LeftColumn/Content/NameLabel
@onready var portrait: TextureRect = $Content/LeftColumn/Content/PortraitFrame/Center/Portrait
@onready var stat_list: VBoxContainer = $Content/LeftColumn/Content/StatList
@onready var header_label: Label = $Content/CenterColumn/HeaderLabel
@onready var rows_container: VBoxContainer = $Content/CenterColumn/RowsContainer
@onready var confirm_button: Button = $Content/CenterColumn/ConfirmButton
@onready var technique_list: VBoxContainer = $Content/RightColumn/TechniquesCard/TechniqueList
@onready var passive_list: VBoxContainer = $Content/RightColumn/PassivesCard/PassiveList

var _reward_flow: RewardFlowController


func _ready() -> void:
	confirm_button.pressed.connect(func() -> void: confirmed.emit())


func show_for(familiar: Familiar, reward_flow: RewardFlowController, stat_upgrade_pool: Array, tooltip_layer: TooltipLayer) -> void:
	_reward_flow = reward_flow

	_populate_fighter_card(familiar, name_label, portrait, stat_list)

	for child in rows_container.get_children():
		child.queue_free()
	for upgrade in stat_upgrade_pool:
		var row: StatUpgradeRow = STAT_UPGRADE_ROW_SCENE.instantiate()
		rows_container.add_child(row)
		row.setup(upgrade, familiar.get_stat(upgrade.stat))
		row.allocate_requested.connect(_on_allocate_requested)

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

	_refresh_rows()
	visible = true


func _on_allocate_requested(stat: Familiar.Stat, delta: int) -> void:
	if not _reward_flow.try_allocate(stat, delta):
		return

	for row in rows_container.get_children():
		if row.upgrade.stat == stat:
			row.set_allocated_count(_reward_flow.allocated.get(stat, 0))

	_refresh_rows()


func _refresh_rows() -> void:
	for row in rows_container.get_children():
		row.refresh_availability(_reward_flow.available_points)
	confirm_button.disabled = _reward_flow.available_points > 0
	header_label.text = "%d stat upgrade%s to apply" % [
		_reward_flow.available_points, "s" if _reward_flow.available_points != 1 else ""
	]


## Panel-local read-only fighter card: icon/label/value rows with an HPBar
## for max HP. BeginCombatPanel, BuildViewPanel and StatUpgradePanel each
## retain their own helper to keep their layouts owned by the screen.
func _populate_fighter_card(familiar: Familiar, name_label_ref: Label, portrait_ref: TextureRect, stat_list_ref: VBoxContainer) -> void:
	name_label_ref.text = familiar.familiar_name
	portrait_ref.texture = familiar.sprite

	for child in stat_list_ref.get_children():
		stat_list_ref.remove_child(child)
		child.queue_free()

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	stat_list_ref.add_child(hp_row)

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
		stat_list_ref.add_child(row)

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
