extends Control

## Drives one 1v1 battle, then a sequence of them across a run: builds both
## Combatants, lets the player pick a priority build, then alternates turns
## until one side is defeated -- both sides choose their own technique via
## Combatant.choose_technique(), with no manual clicking once a fight
## starts. A non-final win shows an upgrade choice and starts the next
## round against opponent_lineup's next entry; the final win or any loss
## ends the run.
##
## Manual Inspector wiring required: player_familiar_data, available_builds,
## upgrade_pool, opponent_lineup. enemy_familiar_data derives itself from
## opponent_lineup[0] -- no separate wiring needed for it.

enum Phase { PLAYER_TURN, ENEMY_UPKEEP, ENEMY_TURN, PLAYER_UPKEEP, BATTLE_OVER }

@export var player_familiar_data: Familiar

## The priority builds offered on the pre-fight build-select screen. The
## chosen build's priority_rules get assigned onto player_familiar_data.
@export var available_builds: Array[PriorityBuild] = []

## Upgrade offers shown after each non-final round. Currently the whole
## pool is offered every round rather than a random subset -- revisit
## once there's more than one upgrade authored.
@export var upgrade_pool: Array[UpgradeOption] = []

## Opponents in order of increasing difficulty.
@export var opponent_lineup: Array[Familiar] = []
@onready var enemy_familiar_data: Familiar = opponent_lineup[0] if opponent_lineup.size() > 0 else null

## Index into opponent_lineup for the fight currently in progress.
var current_round: int = 0

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

## Spawns a button on the shared choice panel (used for both build-select
## and upgrade-select) that calls on_pressed when clicked.
func add_choice_button(label: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.theme = preload("res://assets/themes/button_font.tres")
	button.pressed.connect(on_pressed)

	build_select_panel.add_child(button)

func populate_build_select_buttons() -> void:
	for build in available_builds:
		add_choice_button(build.build_name, _on_build_selected.bind(build))

func populate_upgrade_select_buttons() -> void:
	var available_upgrades: Array[UpgradeOption] = upgrade_pool.duplicate()
	available_upgrades.shuffle()  # Randomize the order of upgrades for variety
	available_upgrades = available_upgrades.slice(0, min(3, available_upgrades.size()))  # Limit to 3 upgrades

	for upgrade in available_upgrades:
		add_choice_button(upgrade.label, _on_upgrade_selected.bind(upgrade))

func _on_build_selected(build: PriorityBuild) -> void:
	player_familiar_data.priority_rules = build.priority_rules
	await begin_fight("A wild %s appears!" % enemy.familiar.familiar_name, CombatLog.Source.ENEMY)

func _on_upgrade_selected(upgrade: UpgradeOption) -> void:
	upgrade.apply(player_familiar_data)
	player.current_hp = player.familiar.max_hp  # Ensure current_hp matches if max_hp changed
	update_hp_display(player)  # Update the HP bar in case max_hp changed
	if upgrade.unique:
		upgrade_pool.erase(upgrade)
	await begin_fight("Upgrade applied: %s. Let the battle continue!" % upgrade.describe(), CombatLog.Source.PLAYER)

## Clears whichever choice screen is showing (build-select or
## upgrade-select) and starts the player's first turn of the fight.
func begin_fight(message: String, source: CombatLog.Source) -> void:
	for child in build_select_panel.get_children():
		child.queue_free()

	combat_log.add_entry(message, source)
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

		if await run_upkeep(enemy, enemy_hp_bar, CombatLog.Source.ENEMY):
			return

		phase = Phase.ENEMY_TURN
		await take_turn(enemy, player, CombatLog.Source.ENEMY)
	else:
		phase = Phase.PLAYER_UPKEEP

		if await run_upkeep(player, player_hp_bar, CombatLog.Source.PLAYER):
			return

		phase = Phase.PLAYER_TURN
		await take_turn(player, enemy, CombatLog.Source.PLAYER)

## Ticks statuses for the side about to act. Returns whatever
## check_victory() returns, so the caller can stop the turn loop whenever
## check_victory() says to -- not just when the battle is fully over, but
## also when paused for a mid-run upgrade choice.
func run_upkeep(combatant: Combatant, hp_bar: HPBar, source: CombatLog.Source) -> bool:
	if combatant.statuses.is_empty():
		return false

	await get_tree().create_timer(0.6).timeout

	for status in combatant.statuses.duplicate():
		var message: String = status.on_tick(combatant)
		if message != "":
			combat_log.add_entry(message, source)
		if status.is_expired():
			combatant.statuses.erase(status)

	update_hp_display(combatant)

	return await check_victory()

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
		if current_round < opponent_lineup.size() - 1:
			combat_log.add_entry("Victory! %s is defeated. Prepare for the next round!" % enemy.familiar.familiar_name, CombatLog.Source.PLAYER)

			start_next_round()
			return true

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

## Advances to the next opponent, resets both Combatants (full heal, no
## statuses -- see DECISIONS.md), and shows the upgrade-choice screen.
## take_turn() only resumes once the player picks one (_on_upgrade_selected).
func start_next_round() -> void:
	current_round += 1
	enemy_familiar_data = opponent_lineup[current_round]
	phase = Phase.PLAYER_UPKEEP

	populate_upgrade_select_buttons()

	player = Combatant.new(player_familiar_data)
	update_hp_display(player)

	enemy = Combatant.new(enemy_familiar_data)
	enemy_name_label.text = enemy.familiar.familiar_name
	enemy_portrait.texture = enemy.familiar.sprite
	update_hp_display(enemy)
