extends Control

## Drives one 1v1 battle: builds both Combatants, alternates turns, resolves
## whichever Technique the player or enemy uses, and ends the battle on
## victory or defeat.
##
## Wiring this scene requires one manual step in the editor: assign
## player_familiar_data and enemy_familiar_data below. ActionPanel's buttons
## are generated at runtime from player_familiar_data.techniques (see
## populate_action_buttons()), not hand-wired in the scene.

enum Phase { PLAYER_TURN, ENEMY_UPKEEP, ENEMY_TURN, PLAYER_UPKEEP, BATTLE_OVER }

@export var player_familiar_data: Familiar
@export var enemy_familiar_data: Familiar

@onready var combat_log: CombatLog = $CombatLog

@onready var player_name_label: Label = $Panels/PlayerPanel/NameLabel
@onready var enemy_name_label: Label = $Panels/EnemyPanel/NameLabel

@onready var player_hp_bar: HPBar = $Panels/PlayerPanel/HPBar
@onready var enemy_hp_bar: HPBar = $Panels/EnemyPanel/HPBar
@onready var player_status_row: StatusRow = $Panels/PlayerPanel/StatusRow
@onready var enemy_status_row: StatusRow = $Panels/EnemyPanel/StatusRow

@onready var player_portrait: TextureRect = $Panels/PlayerPanel/Portrait
@onready var enemy_portrait: TextureRect = $Panels/EnemyPanel/Portrait

@onready var action_panel: HBoxContainer = $ActionPanel

var action_buttons: Array[Button] = []

var player: Combatant
var enemy: Combatant

var phase: Phase = Phase.PLAYER_TURN

func _ready() -> void:
	player = Combatant.new(player_familiar_data)
	enemy = Combatant.new(enemy_familiar_data)

	player_name_label.text = player.familiar.familiar_name
	enemy_name_label.text = enemy.familiar.familiar_name

	update_hp_display(player)
	update_hp_display(enemy)

	player_portrait.texture = player.familiar.sprite
	enemy_portrait.texture = enemy.familiar.sprite

	populate_action_buttons()

	combat_log.add_entry("A wild %s appears!" % enemy.familiar.familiar_name, CombatLog.Source.ENEMY)
	phase = Phase.PLAYER_TURN

## Builds one button per technique in the player's movepool, replacing the
## fixed five-button layout the manual test harness used previously. Each
## button calls the same handler, bound with the specific technique it
## represents -- the handler never needs to know which technique that is.
func populate_action_buttons() -> void:
	for technique in player_familiar_data.techniques:
		var button := Button.new()
		button.text = technique.technique_name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.theme = preload("res://assets/themes/button_font.tres")
		button.pressed.connect(_on_technique_button_pressed.bind(technique))

		action_panel.add_child(button)
		action_buttons.append(button)

func _on_technique_button_pressed(technique: Technique) -> void:
	if phase != Phase.PLAYER_TURN:
		return

	var message: String = technique.execute(player, enemy)

	combat_log.add_entry(message, CombatLog.Source.PLAYER)

	update_hp_display(enemy)

	await advance_turn()

## The one path for updating what a combatant's HPBar shows. The fill and
## the status-damage preview must always move together -- the preview's
## pixel position is computed from the bar's current value, so any HP
## change that skips refreshing the preview leaves it visually stuck at the
## old fill edge until something else happens to refresh it. Routing every
## HP change through here (instead of calling hp_bar.set_hp() directly)
## makes that impossible rather than relying on remembering to pair them.
func update_hp_display(combatant: Combatant) -> void:
	var hp_bar: HPBar = player_hp_bar if combatant == player else enemy_hp_bar
	var status_row: StatusRow = player_status_row if combatant == player else enemy_status_row

	hp_bar.set_hp(combatant.current_hp, combatant.familiar.max_hp)

	refresh_status_preview(combatant, hp_bar, status_row)

## Translates a Combatant's active statuses into the plain {color, amount}
## shape HPBar knows how to draw -- HPBar never needs to know what a
## Status or Combatant is.
func refresh_status_preview(combatant: Combatant, hp_bar: HPBar, status_row: StatusRow) -> void:
	var segments: Array[Dictionary] = []

	for status in combatant.statuses:
		var damage: int = status.next_tick_damage()
		var stacks: int = status.stacks
		if stacks > 0:
			segments.append({"color": status.preview_color(), "stacks": stacks, "damage": damage, "icon": status.icon()})

	hp_bar.set_status_preview_segments(segments)
	status_row.set_status_icons(segments)

func advance_turn() -> void:
	if await check_victory():
		return

	if phase == Phase.PLAYER_TURN:
		phase = Phase.ENEMY_UPKEEP

		set_action_buttons_enabled(false)

		await run_upkeep(enemy, enemy_hp_bar, CombatLog.Source.ENEMY)

		if phase != Phase.BATTLE_OVER:
			phase = Phase.ENEMY_TURN
			await enemy_turn()
	else:
		phase = Phase.PLAYER_UPKEEP

		await run_upkeep(player, player_hp_bar, CombatLog.Source.PLAYER)

		if phase != Phase.BATTLE_OVER:
			phase = Phase.PLAYER_TURN
			set_action_buttons_enabled(true)

## Ticks statuses for the side whose turn is about to begin (upkeep-style,
## before they can act). The caller checks `phase` afterward, not a return
## value here, to tell whether the tick itself ended the battle -- that's
## already covered by check_victory()'s side effect of setting `phase` to
## BATTLE_OVER, so there's nothing this function needs to report back.
func run_upkeep(combatant: Combatant, hp_bar: HPBar, source: CombatLog.Source) -> void:
	if combatant.statuses.is_empty():
		return

	await get_tree().create_timer(0.6).timeout

	for status in combatant.statuses.duplicate():
		var message: String = status.on_tick(combatant)
		if message != "":
			combat_log.add_entry(message, source)
		if status.is_expired():
			combatant.statuses.erase(status)

	update_hp_display(combatant)

	await check_victory()

func enemy_turn() -> void:
	await get_tree().create_timer(0.6).timeout

	# Guubal deliberately has just one technique in its movepool -- still
	# zero decision-making, per the enemy-behavior convention.
	var technique: Technique = enemy_familiar_data.techniques[0]
	var message: String = technique.execute(enemy, player)

	combat_log.add_entry(message, CombatLog.Source.ENEMY)

	update_hp_display(player)

	await advance_turn()

## get_tree().quit() only requests a quit at the end of the current frame --
## it does NOT stop this function from continuing to run. Each branch must
## `return true` explicitly, or the caller's "battle's over, stop here"
## guards never trigger and processing (and duplicate victory/defeat logs)
## continue for another full step before things settle.
func check_victory() -> bool:
	if enemy.is_defeated():
		phase = Phase.BATTLE_OVER

		set_action_buttons_enabled(false)

		combat_log.add_entry("Victory! %s is defeated." % enemy.familiar.familiar_name, CombatLog.Source.PLAYER)

		await get_tree().create_timer(1.0).timeout

		get_tree().quit()
		return true
	if player.is_defeated():
		phase = Phase.BATTLE_OVER

		set_action_buttons_enabled(false)

		combat_log.add_entry("Defeat! %s is defeated." % player.familiar.familiar_name, CombatLog.Source.ENEMY)

		await get_tree().create_timer(1.0).timeout

		get_tree().quit()
		return true

	return false

func set_action_buttons_enabled(enabled: bool) -> void:
	for button in action_buttons:
		button.disabled = not enabled
