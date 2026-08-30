extends Control

## Drives one 1v1 battle: builds both Combatants, lets the player pick a
## priority build, then alternates turns -- both sides now choose their own
## technique via Combatant.choose_technique(), with no manual clicking once
## the fight starts -- resolving whichever Technique is chosen, and ending
## the battle on victory or defeat.
##
## Wiring this scene requires manual steps in the editor: assign
## player_familiar_data, enemy_familiar_data, and available_builds below.
## BuildSelectPanel's buttons are generated at runtime from available_builds
## (see populate_build_select_buttons()), not hand-wired in the scene.

enum Phase { PLAYER_TURN, ENEMY_UPKEEP, ENEMY_TURN, PLAYER_UPKEEP, BATTLE_OVER }

@export var player_familiar_data: Familiar
@export var enemy_familiar_data: Familiar

## The priority builds offered on the pre-fight build-select screen. The
## chosen build's priority_rules get assigned onto player_familiar_data.
@export var available_builds: Array[PriorityBuild] = []

## Logs the enemy's skipped-rule reasoning to the combat log. Off by
## default since it's debug noise for normal play; flip on in the
## Inspector to see why the enemy did or didn't pick each technique.
@export var show_priority_skip_log: bool = false

@onready var combat_log: CombatLog = $CombatLog

@onready var player_name_label: Label = $Panels/PlayerPanel/NameLabel
@onready var enemy_name_label: Label = $Panels/EnemyPanel/NameLabel

@onready var player_hp_bar: HPBar = $Panels/PlayerPanel/HPBar
@onready var enemy_hp_bar: HPBar = $Panels/EnemyPanel/HPBar
@onready var player_status_row: StatusRow = $Panels/PlayerPanel/StatusRow
@onready var enemy_status_row: StatusRow = $Panels/EnemyPanel/StatusRow

@onready var player_portrait: TextureRect = $Panels/PlayerPanel/Portrait
@onready var enemy_portrait: TextureRect = $Panels/EnemyPanel/Portrait

@onready var build_select_panel: HBoxContainer = $BuildSelectPanel

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

	populate_build_select_buttons()

## Builds one button per available build, letting the player pick which
## priority_rules Twerpent fights with before the battle actually starts --
## the smallest possible slice of buildcrafting, not a full round/reward
## loop, just enough to make "two meaningfully different builds" something
## the player chooses rather than something only authored in the Inspector.
func populate_build_select_buttons() -> void:
	for build in available_builds:
		var button := Button.new()
		button.text = build.build_name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.theme = preload("res://assets/themes/button_font.tres")
		button.pressed.connect(_on_build_selected.bind(build))

		build_select_panel.add_child(button)

func _on_build_selected(build: PriorityBuild) -> void:
	player_familiar_data.priority_rules = build.priority_rules
	build_select_panel.queue_free()

	combat_log.add_entry("A wild %s appears!" % enemy.familiar.familiar_name, CombatLog.Source.ENEMY)
	phase = Phase.PLAYER_TURN
	await take_turn(player, enemy, CombatLog.Source.PLAYER)

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

		await run_upkeep(enemy, enemy_hp_bar, CombatLog.Source.ENEMY)

		if phase != Phase.BATTLE_OVER:
			phase = Phase.ENEMY_TURN
			await take_turn(enemy, player, CombatLog.Source.ENEMY)
	else:
		phase = Phase.PLAYER_UPKEEP

		await run_upkeep(player, player_hp_bar, CombatLog.Source.PLAYER)

		if phase != Phase.BATTLE_OVER:
			phase = Phase.PLAYER_TURN
			await take_turn(player, enemy, CombatLog.Source.PLAYER)

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

## The one path for either side's turn -- both player and enemy pick their
## technique the same way now (Combatant.choose_technique()), so there's no
## reason left for a player-specific and an enemy-specific version of this.
func take_turn(actor: Combatant, target: Combatant, source: CombatLog.Source) -> void:
	await get_tree().create_timer(0.6).timeout

	var decision: Dictionary = actor.choose_technique(target)
	if show_priority_skip_log:
		for reason in decision.skip_reasons:
			combat_log.add_entry(reason, source)

	var technique: Technique = decision.technique
	var message: String = technique.execute(actor, target)

	combat_log.add_entry(message, source)

	update_hp_display(target)

	await advance_turn()

## get_tree().quit() only requests a quit at the end of the current frame --
## it does NOT stop this function from continuing to run. Each branch must
## `return true` explicitly, or the caller's "battle's over, stop here"
## guards never trigger and processing (and duplicate victory/defeat logs)
## continue for another full step before things settle.
func check_victory() -> bool:
	if enemy.is_defeated():
		phase = Phase.BATTLE_OVER

		combat_log.add_entry("Victory! %s is defeated." % enemy.familiar.familiar_name, CombatLog.Source.PLAYER)

		await get_tree().create_timer(1.0).timeout

		get_tree().quit()
		return true
	if player.is_defeated():
		phase = Phase.BATTLE_OVER

		combat_log.add_entry("Defeat! %s is defeated." % player.familiar.familiar_name, CombatLog.Source.ENEMY)

		await get_tree().create_timer(1.0).timeout

		get_tree().quit()
		return true

	return false
