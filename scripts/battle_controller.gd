extends Control

## Drives one 1v1 battle: builds both Combatants, alternates turns, resolves
## Attack/Defend, and ends the battle on victory or defeat.
##
## Wiring this scene requires two manual steps in the editor (see
## LEARNING_ROADMAP.md / the exercise notes): assign player_familiar_data and
## enemy_familiar_data below, and connect AttackButton/DefendButton's
## pressed signal to _on_attack_button_pressed / _on_defend_button_pressed.

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

@onready var attack_button: Button = $ActionPanel/AttackButton
@onready var defend_button: Button = $ActionPanel/DefendButton
@onready var poison_button: Button = $ActionPanel/PoisonButton
@onready var burn_button: Button = $ActionPanel/BurnButton
@onready var acid_button: Button = $ActionPanel/AcidButton

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

	combat_log.add_entry("A wild %s appears!" % enemy.familiar.familiar_name, CombatLog.Source.ENEMY)
	phase = Phase.PLAYER_TURN

func _on_attack_button_pressed() -> void:
	if phase != Phase.PLAYER_TURN:
		return

	resolve_attack(player, enemy)

	await advance_turn()

func _on_defend_button_pressed() -> void:
	if phase != Phase.PLAYER_TURN:
		return

	player.is_defending = true
	
	combat_log.add_entry("%s braces to defend." % player.familiar.familiar_name, CombatLog.Source.PLAYER)

	await advance_turn()

func _on_poison_button_pressed() -> void:
	if phase != Phase.PLAYER_TURN:
		return

	var damage: int = max(player.familiar.power / 1.5 - enemy.effective_defense(), 1)

	combat_log.add_entry(
		"%s strikes %s with venom for %d damage, applying 2 stacks of poison!" % [player.familiar.familiar_name, enemy.familiar.familiar_name, damage],
		CombatLog.Source.PLAYER
	)

	enemy.take_damage(damage)

	apply_status(enemy, PoisonStatus.new(2))

	update_hp_display(enemy)

	await advance_turn()


func _on_burn_button_pressed() -> void: 
	if phase != Phase.PLAYER_TURN:
		return

	var damage: int = max(player.familiar.power / 1.5 - enemy.effective_defense(), 1)

	combat_log.add_entry(
		"%s spits fire at %s, dealing %d damage and applying a 5-turn burn!" % [player.familiar.familiar_name, enemy.familiar.familiar_name, damage],
		CombatLog.Source.PLAYER
	)

	enemy.take_damage(damage)

	apply_status(enemy, BurnStatus.new(5))

	update_hp_display(enemy)

	await advance_turn()


func _on_acid_button_pressed() -> void:
	if phase != Phase.PLAYER_TURN:
		return

	var damage: int = max(player.familiar.power / 1.5 - enemy.effective_defense(), 1)

	combat_log.add_entry(
		"%s soaks %s in acid, dealing %d damage and applying a stack of acid!" % [player.familiar.familiar_name, enemy.familiar.familiar_name, damage],
		CombatLog.Source.PLAYER
	)

	enemy.take_damage(damage)

	apply_status(enemy, AcidStatus.new(1))

	update_hp_display(enemy)

	await advance_turn()


func apply_status(combatant: Combatant, status: Status) -> void:
	var message: String = combatant.add_status(status)
	var source: CombatLog.Source = CombatLog.Source.ENEMY if combatant == player else CombatLog.Source.PLAYER
	if message != "":
		combat_log.add_entry(message, source)
		update_hp_display(combatant)

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

func resolve_attack(attacker: Combatant, defender: Combatant) -> void:
	var mitigation: int = defender.effective_defense() * (2 if defender.is_defending else 1)
	var damage: int = max(attacker.familiar.power - mitigation, 1)

	defender.is_defending = false
	defender.take_damage(damage)

	var source: CombatLog.Source = CombatLog.Source.PLAYER if attacker == player else CombatLog.Source.ENEMY
	combat_log.add_entry(
		"%s attacks %s for %d damage!" % [attacker.familiar.familiar_name, defender.familiar.familiar_name, damage],
		source
	)

	if defender == player:
		update_hp_display(player)
	else:
		update_hp_display(enemy)

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

	# acid based attack mirroring the player's acid button, for now. Later we'll add a more interesting AI.
	var damage: int = max(enemy.familiar.power / 1.5 - (player.effective_defense() * (2 if player.is_defending else 1)), 1)

	combat_log.add_entry(
		"%s soaks %s in acid, dealing %d damage and applying a stack of acid!" % [enemy.familiar.familiar_name, player.familiar.familiar_name, damage],
		CombatLog.Source.ENEMY
	)

	player.take_damage(damage)

	apply_status(player, AcidStatus.new(1))

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
	attack_button.disabled = not enabled
	defend_button.disabled = not enabled
	poison_button.disabled = not enabled
	burn_button.disabled = not enabled
	acid_button.disabled = not enabled
