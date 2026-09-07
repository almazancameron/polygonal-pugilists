extends Control

## Drives one 1v1 battle, then a sequence of them across a run: builds both
## Combatants, lets the player pick a priority build, then alternates turns
## until one side is defeated -- both sides choose their own technique via
## Combatant.choose_technique(), with no manual clicking once a fight
## starts. A non-final win shows an upgrade choice and starts the next
## round against the bracket's next opponent; the final win or any loss
## ends the run.
##
## Manual Inspector wiring required: full_roster, stat_upgrade_pool,
## technique_reward_pool, passive_reward_pool. full_roster must hold
## exactly 16 familiars -- Bracket.generate() shuffles them into a real
## single-elimination tree at the start of every run (see _build_bracket()),
## replacing the random gauntlet that used to stand in for it. Matches the
## player isn't in are simulated and scouted before their own fight, then
## rolled to a true winner afterward (BracketResolver). The player's
## familiar starts on whatever priority_rules are already authored directly
## on its own Familiar resource -- same as any enemy -- there is no pre-fight
## build picker any more.

enum Phase { PLAYER_TURN, ENEMY_UPKEEP, ENEMY_TURN, PLAYER_UPKEEP, BATTLE_OVER }

## Every familiar _randomize_matchup() can draw from -- exported and authored
## rather than directory-scanned at runtime, since a runtime scan of
## resources/familiars/ works from the editor but not from an exported .pck
## (see _randomize_matchup()'s doc comment).
@export var full_roster: Array[Familiar] = []

## The fixed final encounter after the bracket's four rounds. Placeholder
## content for now -- a real authored "absurd showdown" kit is its own
## later pass. Kept out of resources/familiars/ deliberately: that folder
## is directory-scanned by balance_test.gd and bracket_test.gd, and the
## boss is not a bracket entrant.
@export var final_boss: Familiar

## True once the bracket is won and the boss fight is the active match.
var facing_boss: bool = false

## Overwritten by _randomize_matchup() every time _ready() runs -- any value
## authored here in the Inspector is just a fallback for a context that
## somehow skips _ready() (none currently do).
@export var player_familiar_data: Familiar

## The 5 mandatory-stat-upgrade offers shown at the start of every reward
## sequence (Phase A) -- expected to hold exactly one ModifyStatUpgrade
## per Familiar.Stat value.
@export var stat_upgrade_pool: Array[ModifyStatUpgrade] = []

## Reward-screen content pools (Phase B) -- see RewardProgression for
## which pool a given round's cadence draws from, and RewardSelector for
## how a specific candidate gets chosen from whichever pool is active.
@export var technique_reward_pool: Array[Technique] = []
@export var passive_reward_pool: Array[PassiveEffect] = []

## Seeds the reward screen's RNG for reproducible testing. 0 means
## "randomize instead" (see _ready()) -- real play shouldn't want a fixed
## reward sequence every run.
@export var reward_seed: int = 0

## Assigned by _build_bracket()/start_next_round() from the bracket's own
## pairings. No longer derived from a pre-authored lineup.
var enemy_familiar_data: Familiar

## The run's whole tournament tree. Replaces the old opponent_lineup
## gauntlet -- see docs/superpowers/specs/2026-09-06-tournament-bracket-design.md.
var bracket: Bracket

## Round the player is currently in, as a 0-indexed index into
## bracket.rounds (was previously an index into opponent_lineup).
var current_round: int = 0

## Seeded per run so a round's upsets are reproducible when reward_seed is set.
var _bracket_rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Logs the enemy's skipped-rule reasoning to the combat log. Off by
## default since it's debug noise for normal play; flip on in the
## Inspector to see why the enemy did or didn't pick each technique.
@export var show_priority_skip_log: bool = false

@onready var combat_log: CombatLog = $CombatLog

@onready var tooltip_layer: TooltipLayer = $TooltipLayer/TooltipContainer

@onready var panels: HBoxContainer = $Panels
@onready var arena: HBoxContainer = $Arena
@onready var footer: MarginContainer = $Footer
@onready var log_scroll: ScrollContainer = $LogScroll
@onready var log_view: CombatLogView = $LogScroll/LogView
@onready var log_background: Control = $LogBackground
@onready var log_outer_frame: Control = $LogOuterFrame

@onready var player_frame: FramedPanel = $Panels/PlayerPanel/Background
@onready var enemy_frame: FramedPanel = $Panels/EnemyPanel/Background

@onready var player_hp_bar: HPBar = $Panels/PlayerPanel/Content/HPBar
@onready var enemy_hp_bar: HPBar = $Panels/EnemyPanel/Content/HPBar
@onready var player_status_row: StatusRow = $Panels/PlayerPanel/Content/StatusRow
@onready var enemy_status_row: StatusRow = $Panels/EnemyPanel/Content/StatusRow

@onready var player_portrait: TextureRect = $Arena/PlayerArena/Center/Portrait
@onready var enemy_portrait: TextureRect = $Arena/EnemyArena/Center/Portrait

@onready var build_select_panel: HBoxContainer = $BuildSelectPanel

@onready var speed_toggle_button: Button = $Footer/ButtonRow/SpeedToggleButton
@onready var auto_toggle_button: Button = $Footer/ButtonRow/AutoToggleButton
@onready var advance_button: Button = $Footer/ButtonRow/AdvanceButton

@onready var priority_builder: PriorityBuilder = $PriorityBuilder

@onready var game_over_panel: Control = $GameOverPanel
@onready var game_over_message_label: Label = $GameOverPanel/Content/MessageLabel
@onready var restart_button: Button = $GameOverPanel/Content/RestartButton

@onready var begin_combat_panel: Control = $BeginCombatPanel
@onready var begin_combat_round_label: Label = $BeginCombatPanel/Content/TitleBlock/RoundLabel
@onready var begin_combat_player_name_label: Label = $BeginCombatPanel/Content/CardsRow/PlayerCard/Content/NameLabel
@onready var begin_combat_player_portrait: TextureRect = $BeginCombatPanel/Content/CardsRow/PlayerCard/Content/StatsRow/PortraitFrame/Center/Portrait
@onready var begin_combat_player_stat_list: VBoxContainer = $BeginCombatPanel/Content/CardsRow/PlayerCard/Content/StatsRow/StatList
@onready var begin_combat_opponent_name_label: Label = $BeginCombatPanel/Content/CardsRow/OpponentCard/Content/NameLabel
@onready var begin_combat_opponent_portrait: TextureRect = $BeginCombatPanel/Content/CardsRow/OpponentCard/Content/StatsRow/PortraitFrame/Center/Portrait
@onready var begin_combat_opponent_stat_list: VBoxContainer = $BeginCombatPanel/Content/CardsRow/OpponentCard/Content/StatsRow/StatList
@onready var priority_builder_button: Button = $BeginCombatPanel/Content/ButtonsRow/PriorityBuilderButton
@onready var begin_combat_button: Button = $BeginCombatPanel/Content/ButtonsRow/BeginButton

@onready var bracket_screen: BracketScreen = $BracketScreen

## Emitted once the player picks a path off the pre-fight screen -- true for
## "open the priority builder", false for "begin the fight as-is". A plain
## signal rather than reusing priority_builder.confirm_requested since this
## fires from either of two different buttons on a different screen.
signal pre_fight_choice_made(open_priority_builder: bool)

## Warns before beginning a fight with nothing actually edited this round --
## moved here from priority_builder.gd's own Confirm button. Covers both
## "never opened the editor" and "opened it (maybe more than once) but
## never made an edit" -- see _priority_rules_edited_this_round, which is
## what actually distinguishes those two cases from "opened it and edited
## something," and is what decides whether this dialog fires at all.
var _no_priority_changes_dialog: ConfirmationDialog

## True once the priority builder has reported at least one real edit
## since this round's pre-fight loop began -- accumulates across however
## many times the player opens/closes the editor in one round (see
## advance_to_priority_editor()), since priority_builder.has_unsaved_changes
## itself only ever reflects a single open/close session. Reset at the
## start of every pre-fight loop.
var _priority_rules_edited_this_round: bool = false

## -- Reward sequence (Phase A stat allocation + Phase B reward cards) --
const REWARD_CARD_SCENE: PackedScene = preload("res://scenes/reward_card.tscn")
const STAT_UPGRADE_ROW_SCENE: PackedScene = preload("res://scenes/stat_upgrade_row.tscn")

## Same technique/passive card look the priority builder's palette uses
## (icon + colored name + subtitle) -- reused as-is rather than rebuilt,
## since nothing about it is priority-builder-specific.
const PALETTE_BLOCK_SCENE: PackedScene = preload("res://scenes/priority_builder/palette_block.tscn")

@onready var stat_upgrade_panel: Control = $StatUpgradePanel
@onready var stat_name_label: Label = $StatUpgradePanel/Content/LeftColumn/Content/NameLabel
@onready var stat_portrait: TextureRect = $StatUpgradePanel/Content/LeftColumn/Content/PortraitFrame/Center/Portrait
@onready var stat_stat_list: VBoxContainer = $StatUpgradePanel/Content/LeftColumn/Content/StatList
@onready var stat_header_label: Label = $StatUpgradePanel/Content/CenterColumn/HeaderLabel
@onready var stat_rows_container: VBoxContainer = $StatUpgradePanel/Content/CenterColumn/RowsContainer
@onready var stat_confirm_button: Button = $StatUpgradePanel/Content/CenterColumn/ConfirmButton
@onready var stat_technique_list: VBoxContainer = $StatUpgradePanel/Content/RightColumn/TechniquesCard/TechniqueList
@onready var stat_passive_list: VBoxContainer = $StatUpgradePanel/Content/RightColumn/PassivesCard/PassiveList

@onready var reward_select_panel: Control = $RewardSelectPanel
@onready var reward_title_label: Label = $RewardSelectPanel/Content/TopArea/TitleBlock/TitleLabel
@onready var reward_subtitle_label: Label = $RewardSelectPanel/Content/TopArea/TitleBlock/SubtitleLabel
@onready var winner_frame: FramedPanel = $RewardSelectPanel/Content/TopArea/WinnerCard/Background
@onready var winner_content: HBoxContainer = $RewardSelectPanel/Content/TopArea/WinnerCard/Content
@onready var winner_portrait: TextureRect = $RewardSelectPanel/Content/TopArea/WinnerCard/Content/PortraitFrame/Center/Portrait
@onready var next_opponent_portrait: TextureRect = $RewardSelectPanel/Content/TopArea/RightColumn/NextOpponentCard/Content/PortraitFrame/Center/Portrait
@onready var next_opponent_name_label: Label = $RewardSelectPanel/Content/TopArea/RightColumn/NextOpponentCard/Content/NameLabel
@onready var bracket_summary_button: Button = $RewardSelectPanel/Content/TopArea/RightColumn/BracketSummaryCard
@onready var bracket_summary_round_label: Label = $RewardSelectPanel/Content/TopArea/RightColumn/BracketSummaryCard/Rows/RoundLabel
@onready var bracket_summary_remaining_label: Label = $RewardSelectPanel/Content/TopArea/RightColumn/BracketSummaryCard/Rows/RemainingLabel
@onready var species_column: VBoxContainer = $RewardSelectPanel/Content/CardRow/SpeciesColumn/Content
@onready var run_column: VBoxContainer = $RewardSelectPanel/Content/CardRow/RunColumn/Content
@onready var pivot_column: VBoxContainer = $RewardSelectPanel/Content/CardRow/PivotColumn/Content
@onready var rerolls_remaining_label: Label = $RewardSelectPanel/Content/ActionRow/RerollsRemainingLabel
@onready var skip_button: Button = $RewardSelectPanel/Content/ActionRow/SkipButton
@onready var next_round_button: Button = $RewardSelectPanel/Content/ActionRow/NextRoundButton
@onready var build_view_button: Button = $RewardSelectPanel/Content/ActionRow/ViewBuildButton

@onready var build_view_panel: Control = $BuildViewPanel
@onready var build_view_close_button: Button = $BuildViewPanel/CloseButton
@onready var build_view_name_label: Label = $BuildViewPanel/Content/FamiliarCard/Content/NameLabel
@onready var build_view_portrait: TextureRect = $BuildViewPanel/Content/FamiliarCard/Content/PortraitFrame/Center/Portrait
@onready var build_view_stat_list: VBoxContainer = $BuildViewPanel/Content/FamiliarCard/Content/StatList
@onready var build_view_technique_list: VBoxContainer = $BuildViewPanel/Content/RightColumn/TechniquesCard/TechniqueList
@onready var build_view_passive_list: VBoxContainer = $BuildViewPanel/Content/RightColumn/PassivesCard/PassiveList

## The 3 RewardCards share one ButtonGroup (exactly one selected at a
## time) but each column keeps its own separate RerollButton outside the
## group -- see the reward-screen plan's note on why ButtonGroup still
## fits despite per-slot rerolls.
var _reward_card_group: ButtonGroup = ButtonGroup.new()
var _reward_cards: Dictionary = {}  # RewardSelector.RewardSlot -> RewardCard
var _slot_columns: Dictionary = {}  # RewardSelector.RewardSlot -> VBoxContainer
var selected_reward_option: UpgradeOption = null

var reward_flow: RewardFlowController = RewardFlowController.new()

## Cycles battle pacing 1x -> 2x -> 4x -> 1x. Every pause between turn/upkeep
## steps goes through get_tree().create_timer(), which already scales with
## Engine.time_scale by default -- nothing else needed to change for this.
const SPEED_MULTIPLIERS: Array[int] = [1, 2, 4]
var speed_index: int = 0

## True = existing always-on pacing (every paced entry/tick waits on a fixed
## timer, scaled by the speed multiplier). False = every one of those same
## paced points instead waits for a single manual advance (see run_upkeep()
## and take_turn()'s turn_gate_opened waits) -- one click reveals exactly
## one entry, not a whole turn.
var auto_enabled: bool = true

## Wakes up run_upkeep()/take_turn()'s per-entry gates when auto is off --
## fired by AdvanceButton, and also by switching Auto back on, since a gate
## already suspended on advance_button.pressed would otherwise never notice
## auto_enabled flipped back to true and stay frozen forever (the button
## that could unstick it is itself hidden the moment Auto turns on).
signal turn_gate_opened

var player: Combatant
var enemy: Combatant

var phase: Phase = Phase.PLAYER_TURN

## Owns turn order, upkeep, and technique resolution for the fight currently in
## progress -- see scripts/battle_engine.gd. Rebuilt in _ready() and again in
## start_next_round(), since it wraps those two specific Combatant references.
var engine: BattleEngine

func _ready() -> void:
	player_status_row.tooltip_layer = tooltip_layer
	enemy_status_row.tooltip_layer = tooltip_layer

	speed_toggle_button.pressed.connect(_on_speed_toggle_pressed)
	auto_toggle_button.pressed.connect(_on_auto_toggle_pressed)
	advance_button.pressed.connect(turn_gate_opened.emit)
	advance_button.visible = false

	_slot_columns = {
		RewardSelector.RewardSlot.SPECIES: species_column,
		RewardSelector.RewardSlot.RUN: run_column,
		RewardSelector.RewardSlot.PIVOT: pivot_column,
	}

	for slot in _slot_columns:
		var column: VBoxContainer = _slot_columns[slot]
		column.get_node("RerollButton").pressed.connect(_on_reroll_pressed.bind(slot))

	skip_button.pressed.connect(_on_skip_pressed)
	next_round_button.pressed.connect(_on_next_round_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	bracket_summary_button.pressed.connect(_on_next_opponent_panel_pressed)
	build_view_button.pressed.connect(_on_build_view_pressed)
	build_view_close_button.pressed.connect(_on_build_view_closed_pressed)

	priority_builder_button.pressed.connect(func() -> void: pre_fight_choice_made.emit(true))
	begin_combat_button.pressed.connect(_on_begin_fight_pressed)

	bracket_screen.tooltip_layer = tooltip_layer

	_no_priority_changes_dialog = ConfirmationDialog.new()
	_no_priority_changes_dialog.dialog_text = "You haven't edited your priorities this round. Begin anyway?"
	_no_priority_changes_dialog.confirmed.connect(func() -> void: pre_fight_choice_made.emit(false))
	add_child(_no_priority_changes_dialog)

	await _start_new_run()

## Begin Fight always proceeds immediately when the priority builder isn't
## even offered (the very first fight of a run, nothing to arrange yet).
## When it is offered, the warning fires unless an actual edit happened
## this round -- not merely opening the editor and looking. A technique
## picked as this round's reward but never dragged into a rule will never
## fire in battle regardless of the developer's intent when picking it, so
## "I opened it but didn't change anything" is exactly as worth confirming
## as "I never opened it at all."
func _on_begin_fight_pressed() -> void:
	if priority_builder_button.visible and not _priority_rules_edited_this_round:
		_no_priority_changes_dialog.popup_centered()
	else:
		pre_fight_choice_made.emit(false)

## Resets every piece of per-run state -- a fresh matchup, a fresh
## RewardFlowController (RNG, reroll charges, build snapshot), the round
## counter, the combat log -- and starts the opening fight. Called once from
## _ready() and again by _on_restart_pressed(), so Restart is a genuinely new
## run rather than a full-health replay of whatever matchup just ended.
func _start_new_run() -> void:
	# Clear every screen the previous run could have left up *before*
	# showing character select -- Restart is reached from the Game Over
	# panel, which would otherwise sit there for the whole bracket screen.
	stat_confirm_button.disabled = true
	stat_upgrade_panel.visible = false
	reward_select_panel.visible = false
	game_over_panel.visible = false
	priority_builder.visible = false
	log_view.clear()

	_build_bracket()
	await _select_entrant()
	current_round = 0
	_priority_rules_edited_this_round = false

	player = Combatant.new(player_familiar_data)
	enemy = Combatant.new(enemy_familiar_data)
	player.opponent = enemy
	enemy.opponent = player
	engine = BattleEngine.new(player, enemy)

	player_frame.header_text = player.familiar.familiar_name
	enemy_frame.header_text = enemy.familiar.familiar_name
	log_view.player_name = player.familiar.familiar_name
	log_view.enemy_name = enemy.familiar.familiar_name

	update_hp_display(player)
	update_hp_display(enemy)

	player_portrait.texture = player.familiar.sprite
	enemy_portrait.texture = enemy.familiar.sprite

	reward_flow = RewardFlowController.new()
	if reward_seed != 0:
		reward_flow.seed_rng(reward_seed)
	else:
		reward_flow.randomize_rng()

	await _wait_for_pre_fight_screen(enemy, false)
	await begin_fight("%s prepares for battle!" % enemy.familiar.familiar_name, CombatLog.Source.ENEMY)

## Builds this run's bracket and puts the player in one of its round-1
## matches. Bracket.generate() duplicates every entrant, so builds can
## mutate in place over the run without corrupting the base .tres files.
##
## full_roster is an authored, exported list rather than a runtime directory
## scan of resources/familiars/ (an earlier version of this method did that,
## the same way balance_test.gd's _load_familiars() still does) --
## DirAccess.list_dir_begin()/get_next() can enumerate a res:// folder when
## Godot is reading loose project files (the editor, or a --script run), but
## not against a packed, exported .pck, where it silently returns nothing.
## balance_test.gd is fine relying on it since it only ever runs against the
## loose project; anything that has to work in an exported build (this file)
## can't.
##
## The entrant choice is temporary: the character-select screen replaces
## _auto_pick_entrant() with a real player decision.
func _build_bracket() -> void:
	if full_roster.size() != Bracket.ENTRANT_COUNT:
		push_error("full_roster must hold exactly %d familiars, holds %d" % [Bracket.ENTRANT_COUNT, full_roster.size()])
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	if reward_seed != 0:
		_bracket_rng.seed = reward_seed
	else:
		_bracket_rng.randomize()

	bracket = Bracket.generate(full_roster, rng, final_boss)
	facing_boss = false

	# Scouted before anyone has picked a side, so all 8 round-1 matches get
	# odds -- character select shows them while choosing. Whichever match
	# the player then joins keeps its label but never reads it again.
	BracketResolver.scout_round(bracket.rounds[0])

## Read-only view of the round the player is about to fight: every other
## match's odds and each entrant's species tags, plus last round's
## finished results, free and always available (GAME_DESIGN.md §9.3).
func _show_scouting() -> void:
	panels.visible = false
	arena.visible = false
	footer.visible = false
	speed_toggle_button.visible = false
	auto_toggle_button.visible = false
	advance_button.visible = false
	log_scroll.visible = false
	log_background.visible = false
	log_outer_frame.visible = false

	bracket_screen.setup(bracket, current_round, false)
	bracket_screen.visible = true

	await bracket_screen.dismissed

	bracket_screen.visible = false

## Round 1's character select. Every round-1 match is already scouted by
## the time this shows, so the player can weigh each pairing's odds while
## choosing -- the pick's own match then stops being scouting material and
## becomes a real fight.
func _select_entrant() -> void:
	panels.visible = false
	arena.visible = false
	footer.visible = false
	speed_toggle_button.visible = false
	auto_toggle_button.visible = false
	advance_button.visible = false
	log_scroll.visible = false
	log_background.visible = false
	log_outer_frame.visible = false

	bracket_screen.setup(bracket, 0, true)
	bracket_screen.visible = true

	var chosen: Familiar = await bracket_screen.entrant_selected

	bracket_screen.visible = false

	for bracket_match in bracket.rounds[0].matches:
		if bracket_match.has_entrant(chosen):
			bracket_match.is_player_match = true
			bracket_match.odds_label = ""
			player_familiar_data = chosen
			enemy_familiar_data = bracket_match.other_entrant(chosen)
			break

## The match the player is fighting this round.
func player_bracket_match() -> BracketMatch:
	return bracket.rounds[current_round].player_match()

func _on_speed_toggle_pressed() -> void:
	speed_index = (speed_index + 1) % SPEED_MULTIPLIERS.size()
	Engine.time_scale = SPEED_MULTIPLIERS[speed_index]
	speed_toggle_button.text = "%dx" % SPEED_MULTIPLIERS[speed_index]

func _on_auto_toggle_pressed() -> void:
	auto_enabled = not auto_enabled
	auto_toggle_button.text = "AUTO: %s" % ("ON" if auto_enabled else "OFF")
	speed_toggle_button.visible = auto_enabled
	advance_button.visible = not auto_enabled
	if auto_enabled:
		turn_gate_opened.emit()

## Spawns a button on the shared choice panel (used for the round-4
## sacrifice screen) that calls on_pressed when clicked.
func add_choice_button(label: String, on_pressed: Callable, tooltip: String="") -> void:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tooltip != "":
		button.mouse_entered.connect(func() -> void: tooltip_layer.hover_started(button, tooltip))
		button.mouse_exited.connect(func() -> void: tooltip_layer.hover_ended(button))

	button.pressed.connect(on_pressed)

	build_select_panel.add_child(button)

## ---- Reward sequence: Phase B (tailored reward cards) comes first, ----
## ---- then Phase A (mandatory stat allocation) ----

## Every reward sequence starts here: the tailored reward cards (Phase B)
## show first. Only once that's resolved (a reward picked, or explicitly
## skipped) does the mandatory stat allocation (Phase A) run -- once per
## round either way, never twice. Skipping the reward grants 2 stat
## points on that single pass instead of 1, rather than showing the stat
## screen a second, separate time.
func begin_reward_sequence() -> void:
	# player/enemy are still the just-finished fight's Combatants here --
	# start_next_round()/start_boss_fight() both reconstruct them only
	# *after* this call returns, so this is the one place that can read
	# the winner's actual post-battle HP/statuses and the name of whoever
	# was just defeated (enemy_familiar_data has already moved on to the
	# *next* opponent by this point -- see DECISIONS.md).
	reward_title_label.text = "BOUT WON!"
	reward_subtitle_label.text = "%s defeated %s!" % [player.familiar.familiar_name, enemy.familiar.familiar_name]
	winner_frame.header_text = player.familiar.familiar_name
	_populate_winner_card()

	next_opponent_portrait.texture = enemy_familiar_data.sprite
	next_opponent_name_label.text = enemy_familiar_data.familiar_name

	if facing_boss:
		bracket_summary_round_label.text = "Champion"
		bracket_summary_remaining_label.text = "Final bout"
	else:
		bracket_summary_round_label.text = Bracket.round_display_name(current_round)
		var rounds_remaining: int = bracket.rounds.size() - current_round
		bracket_summary_remaining_label.text = "%d round%s remain" % [
			rounds_remaining, "s" if rounds_remaining != 1 else ""
		]

	# Hidden for the whole reward sequence (Phase B and whichever Phase A
	# pass follows it) -- shown again once begin_fight() resumes the next
	# fight. Nothing re-shows them in between, so hiding all three once
	# here, at the sequence's actual single entry point, covers every
	# reward path regardless of which screen it starts or ends on. The
	# speed toggle and combat log only mean anything while a fight is
	# actually playing out.
	panels.visible = false
	arena.visible = false
	footer.visible = false
	speed_toggle_button.visible = false
	auto_toggle_button.visible = false
	advance_button.visible = false
	log_scroll.visible = false
	log_background.visible = false
	log_outer_frame.visible = false

	begin_phase_b()

## Rebuilds the HPBar to the left of the static PortraitFrame -- built
## fresh each time rather than kept as a static scene child, same reasoning
## as every other "rebuild per round" list on these screens (a fresh HPBar
## needs its own StyleBoxFlat instances, per HPBar.set_hp()'s own
## documented quirk of only ever mutating whatever fill style it finds).
## No StatusRow here -- per the mockup, WinnerCard shows name (in the
## header flag) + sprite + HP only, not the winner's lingering statuses.
func _populate_winner_card() -> void:
	var portrait_frame: Control = winner_content.get_node("PortraitFrame")
	for child in winner_content.get_children():
		if child == portrait_frame:
			continue
		winner_content.remove_child(child)
		child.queue_free()

	var hp_bar: HPBar = PREFIGHT_HP_BAR_SCENE.instantiate()
	hp_bar.custom_minimum_size = Vector2(0, 24)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Appended after the scene's static PortraitFrame -- sprite on the
	# left, HP bar on the right.
	winner_content.add_child(hp_bar)

	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Palette.HP_TRACK
	hp_bar.bar_background_style = background_style
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Palette.HP_FULL
	hp_bar.bar_fill_style = fill_style
	hp_bar.set_hp(player.current_hp, player.familiar.max_hp)

	winner_portrait.texture = player.familiar.sprite

## Builds one StatUpgradeRow per stat_upgrade_pool entry and shows the
## panel. on_confirmed is called once the player commits their
## allocation -- parameterized so this same screen serves both the
## post-reward-pick pass (1 point) and the skip-triggered pass (2 points).
func populate_stat_upgrade_rows(points: int, on_confirmed: Callable) -> void:
	reward_flow.begin_stat_phase(points)

	_populate_fighter_card(player_familiar_data, stat_name_label, stat_portrait, stat_stat_list)

	for child in stat_rows_container.get_children():
		child.queue_free()

	for upgrade in stat_upgrade_pool:
		var row: StatUpgradeRow = STAT_UPGRADE_ROW_SCENE.instantiate()
		stat_rows_container.add_child(row)
		row.setup(upgrade, player_familiar_data.get_stat(upgrade.stat))
		row.allocate_requested.connect(_on_stat_allocate_requested)

	if stat_confirm_button.pressed.is_connected(_on_stat_confirm_pressed):
		stat_confirm_button.pressed.disconnect(_on_stat_confirm_pressed)
	stat_confirm_button.pressed.connect(_on_stat_confirm_pressed.bind(on_confirmed))

	for child in stat_technique_list.get_children():
		child.queue_free()
	for technique in player_familiar_data.techniques:
		var technique_block: PaletteBlock = PALETTE_BLOCK_SCENE.instantiate()
		stat_technique_list.add_child(technique_block)
		technique_block.setup_technique(technique, tooltip_layer)

	for child in stat_passive_list.get_children():
		child.queue_free()
	for passive in player_familiar_data.passives:
		var passive_block: PaletteBlock = PALETTE_BLOCK_SCENE.instantiate()
		stat_passive_list.add_child(passive_block)
		passive_block.setup_passive(passive, tooltip_layer)

	_refresh_stat_rows()
	stat_upgrade_panel.visible = true

func _on_stat_allocate_requested(stat: Familiar.Stat, delta: int) -> void:
	if not reward_flow.try_allocate(stat, delta):
		return

	for row in stat_rows_container.get_children():
		if row.upgrade.stat == stat:
			row.set_allocated_count(reward_flow.allocated.get(stat, 0))

	_refresh_stat_rows()

func _refresh_stat_rows() -> void:
	for row in stat_rows_container.get_children():
		row.refresh_availability(reward_flow.available_points)
	stat_confirm_button.disabled = reward_flow.available_points > 0
	stat_header_label.text = "%d stat upgrade%s to apply" % [
		reward_flow.available_points, "s" if reward_flow.available_points != 1 else ""
	]

func _on_stat_confirm_pressed(on_confirmed: Callable) -> void:
	reward_flow.confirm_stat_phase(player_familiar_data, stat_upgrade_pool)
	player.current_hp = player.familiar.max_hp  # Ensure current_hp matches if max_hp changed
	update_hp_display(player)
	stat_upgrade_panel.visible = false
	on_confirmed.call()

## Dispatches on this round's cadence (RewardProgression) -- a normal
## technique/passive grant shows the 3 cards immediately; a passive-trade
## round shows the sacrifice screen first. Nothing past the authored
## cadence has a reward to offer at all, so it goes straight to the
## (1-point) stat allocation instead.
func begin_phase_b() -> void:
	var kind: RewardProgression.RewardKind = reward_flow.begin_reward_screen(
		current_round, player_familiar_data, technique_reward_pool, passive_reward_pool
	)

	match kind:
		RewardProgression.RewardKind.NONE:
			populate_stat_upgrade_rows(1, advance_to_priority_editor)
		RewardProgression.RewardKind.PASSIVE_TRADE:
			begin_sacrifice_screen()
		_:
			_show_reward_cards(true)

## Reuses the build-select panel's plain button-list convention -- one
## button per currently-held passive, plus a Skip that leads straight to
## the stat-allocation pass with 2 points (skipping the trade entirely).
## Skip lives ONLY here, not on the reward-cards screen that follows.
func begin_sacrifice_screen() -> void:
	for child in build_select_panel.get_children():
		child.queue_free()

	for passive in reward_flow.sacrifice_options(player_familiar_data):
		add_choice_button("Give up: %s" % passive.passive_name, _on_sacrifice_selected.bind(passive), passive.describe())

	add_choice_button("Skip", _on_skip_pressed)

func _on_sacrifice_selected(passive: PassiveEffect) -> void:
	for child in build_select_panel.get_children():
		child.queue_free()

	reward_flow.resolve_sacrifice(passive, player_familiar_data)
	_show_reward_cards(false)

func _show_reward_cards(show_skip: bool) -> void:
	_populate_reward_cards()
	skip_button.visible = show_skip
	reward_select_panel.visible = true

## Destroys and recreates all 3 slot cards for a fresh screen (a reroll
## instead reuses the existing card -- see _on_reroll_pressed()).
func _populate_reward_cards() -> void:
	selected_reward_option = null
	next_round_button.disabled = true

	for slot in _slot_columns:
		var column: VBoxContainer = _slot_columns[slot]

		if _reward_cards.has(slot):
			var old_card: RewardCard = _reward_cards[slot]
			column.remove_child(old_card)
			old_card.queue_free()
			_reward_cards.erase(slot)

		var option: UpgradeOption = reward_flow.candidate_for_slot(slot)
		if option == null:
			continue

		var card: RewardCard = REWARD_CARD_SCENE.instantiate()
		column.add_child(card)
		column.move_child(card, 0)  # before RerollButton -- the column's own FramedPanel tab is the slot label now
		card.button_group = _reward_card_group
		card.setup(option, tooltip_layer)
		card.toggled.connect(_on_reward_card_toggled.bind(slot))
		_reward_cards[slot] = card

	_refresh_reroll_buttons()

func _on_reward_card_toggled(pressed: bool, slot: RewardSelector.RewardSlot) -> void:
	if not pressed:
		return
	selected_reward_option = reward_flow.candidate_for_slot(slot)
	next_round_button.disabled = selected_reward_option == null

func _refresh_reroll_buttons() -> void:
	rerolls_remaining_label.text = "Rerolls left: %d" % reward_flow.rerolls_remaining
	var available: bool = reward_flow.rerolls_remaining > 0 and reward_flow.has_unseen_candidates()
	for slot in _slot_columns:
		var column: VBoxContainer = _slot_columns[slot]
		column.get_node("RerollButton").disabled = not available

## Rerolls exactly one slot in place -- reuses the existing RewardCard
## node (re-setup() with the new candidate) rather than destroying and
## recreating it, so the shared ButtonGroup never needs re-registering.
func _on_reroll_pressed(slot: RewardSelector.RewardSlot) -> void:
	if not reward_flow.reroll_slot(slot, player_familiar_data):
		return

	var card: RewardCard = _reward_cards.get(slot)
	var option: UpgradeOption = reward_flow.candidate_for_slot(slot)
	if card == null or option == null:
		return

	# The rerolled slot's previous content is gone -- clear its selection
	# state (through the ButtonGroup) rather than leave a stale choice
	# pointing at an option that's no longer offered.
	if card.button_pressed:
		selected_reward_option = null
		next_round_button.disabled = true
	card.button_pressed = false
	card.setup(option, tooltip_layer)

	_refresh_reroll_buttons()

## Declining the reward grants 2 stat points on the single allocation
## pass that follows, instead of running that screen a second time.
func _on_skip_pressed() -> void:
	reward_select_panel.visible = false
	for child in build_select_panel.get_children():
		child.queue_free()
	populate_stat_upgrade_rows(2, advance_to_priority_editor)

func _on_next_round_pressed() -> void:
	if selected_reward_option == null:
		return
	selected_reward_option.apply(player_familiar_data)
	player.current_hp = player.familiar.max_hp
	update_hp_display(player)
	reward_select_panel.visible = false
	populate_stat_upgrade_rows(1, advance_to_priority_editor)

## Shows a "get ready" screen with the upcoming opponent's portrait/name and
## waits for the player to choose a path, before begin_fight() actually
## starts the fight -- both the run's opening fight and every subsequent
## round's fight go through this first. panels/speed_toggle_button/log_scroll
## are hidden the same way the reward/game-over screens already hide them
## while shown; begin_fight() unconditionally shows them again right after,
## so nothing here needs to restore them.
##
## show_priority_option is false for the run's opening fight (no reward has
## happened yet, nothing to arrange) and true for every round transition.
## Returns true if the player chose to open the priority builder, false if
## they chose to begin the fight as-is.
func _wait_for_pre_fight_screen(opponent: Combatant, show_priority_option: bool) -> bool:
	panels.visible = false
	arena.visible = false
	footer.visible = false
	speed_toggle_button.visible = false
	auto_toggle_button.visible = false
	advance_button.visible = false
	log_scroll.visible = false
	log_background.visible = false
	log_outer_frame.visible = false

	begin_combat_round_label.text = Bracket.round_display_name(current_round)
	_populate_fighter_card(player.familiar, begin_combat_player_name_label, begin_combat_player_portrait, begin_combat_player_stat_list)
	_populate_fighter_card(opponent.familiar, begin_combat_opponent_name_label, begin_combat_opponent_portrait, begin_combat_opponent_stat_list)
	priority_builder_button.visible = show_priority_option
	begin_combat_panel.visible = true

	var open_priority_builder: bool = await pre_fight_choice_made

	begin_combat_panel.visible = false
	return open_priority_builder

## Mirrors priority_builder.gd's own _add_max_hp_row() approach (icon +
## label + value rows, Max HP shown as an actual HPBar rather than a plain
## number) -- duplicated here rather than shared, since this is a
## read-only pre-fight display, not an editable build, and the only other
## user of that pattern is a different screen entirely.
const PREFIGHT_HP_BAR_SCENE: PackedScene = preload("res://scenes/hp_bar.tscn")

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

## Shows the pre-fight screen first (GAME_DESIGN.md §9.2 step 4's entry
## point), looping back to it after every priority-editor session rather
## than proceeding straight into the fight -- the player can open/close the
## editor as many times as they like (looking without editing, then going
## back in to actually make a change) before finally choosing to begin.
## setup() re-populates the whole editor every time it's actually opened --
## including reconstructing segments for whatever priority_rules the
## familiar already has -- since both the opponent and the player's own
## techniques/rules can differ from the last time this ran.
func advance_to_priority_editor() -> void:
	# Nothing to scout before the boss -- it isn't in the bracket, and the
	# bracket itself is already finished by then.
	if not facing_boss:
		await _show_scouting()

	_priority_rules_edited_this_round = false

	while true:
		var open_priority_builder: bool = await _wait_for_pre_fight_screen(enemy, true)
		if not open_priority_builder:
			break

		priority_builder.visible = true
		priority_builder.setup(player_familiar_data, enemy_familiar_data)

		await priority_builder.confirm_requested

		if priority_builder.has_unsaved_changes:
			_priority_rules_edited_this_round = true
		player_familiar_data.priority_rules = priority_builder.compiled_rules()
		priority_builder.visible = false

	await begin_fight("Prepare for the next bout!", CombatLog.Source.PLAYER)

func _other(combatant: Combatant) -> Combatant:
	return enemy if combatant == player else player

## Clears the sacrifice screen's buttons if any are showing, re-shows the
## HUD, and starts the fight's opening turn. No upkeep before this first
## turn -- both Combatants are freshly created with no statuses yet, same
## as before Speed-based ordering existed.
func begin_fight(message: String, source: CombatLog.Source) -> void:
	panels.visible = true
	arena.visible = true
	footer.visible = true
	speed_toggle_button.visible = auto_enabled
	log_scroll.visible = true
	log_background.visible = true
	log_outer_frame.visible = true
	auto_toggle_button.visible = true
	advance_button.visible = not auto_enabled

	for child in build_select_panel.get_children():
		child.queue_free()

	combat_log.add_entry(message, source)

	engine.begin_battle()
	if engine.battle_start_player_message != "":
		combat_log.add_entry(engine.battle_start_player_message, CombatLog.Source.PLAYER)
	if engine.battle_start_enemy_message != "":
		combat_log.add_entry(engine.battle_start_enemy_message, CombatLog.Source.ENEMY)
	update_hp_display(player)
	update_hp_display(enemy)

	# A beat between clicking Begin Combat and the first actual move, so the
	# player actually sees both HP bars sitting at full before either one
	# starts moving -- without this the first hit lands the same frame the
	# button gets clicked.
	await get_tree().create_timer(1.0).timeout

	var current_first_actor: Combatant = engine.current_first_actor
	var opening_source: CombatLog.Source = CombatLog.Source.PLAYER if current_first_actor == player else CombatLog.Source.ENEMY

	phase = Phase.PLAYER_TURN if current_first_actor == player else Phase.ENEMY_TURN
	await take_turn(current_first_actor, _other(current_first_actor), opening_source)

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
			segments.append({"id": status.status_id(), "color": status.preview_color(), "stacks": stacks, "damage": damage, "icon": status.icon(), "description": status.describe()})

	hp_bar.set_status_preview_segments(segments)
	status_row.set_status_icons(segments)

## actor is whoever just finished their turn. engine.advance_turn() decides who's
## next -- the other side, unless actor's exchange just completed, in which case
## whoever's still faster (or still holds an override) opens the next one, which
## is what lets one side take two turns in a row.
func advance_turn(actor: Combatant) -> void:
	if await check_victory():
		return

	var next_actor: Combatant = engine.advance_turn(actor)

	var next_source: CombatLog.Source = CombatLog.Source.PLAYER if next_actor == player else CombatLog.Source.ENEMY
	var next_hp_bar: HPBar = player_hp_bar if next_actor == player else enemy_hp_bar

	next_actor.reset_turn_passive_limits()

	phase = Phase.PLAYER_UPKEEP if next_actor == player else Phase.ENEMY_UPKEEP
	if await run_upkeep(next_actor, next_hp_bar, next_source):
		return

	phase = Phase.PLAYER_TURN if next_actor == player else Phase.ENEMY_TURN
	await take_turn(next_actor, _other(next_actor), next_source)

## Ticks statuses for the side about to act. Returns whatever
## check_victory() returns, so the caller can stop the turn loop whenever
## check_victory() says to -- not just when the battle is fully over, but
## also when paused for a mid-run upgrade choice.
func run_upkeep(combatant: Combatant, hp_bar: HPBar, source: CombatLog.Source) -> bool:
	# Engine returns one entry per status ticked, not per message -- a "" entry
	# still gets its own display update and pause below in auto mode, matching
	# how live play paced every tick before this refactor regardless of
	# whether it had anything to log. Manual mode skips that pause instead of
	# spending a click on a tick with nothing to show.
	for message in engine.run_upkeep(combatant):
		if message != "":
			combat_log.add_entry(message, source)

		update_hp_display(combatant)

		if combatant.is_defeated():
			return await check_victory()

		if auto_enabled:
			await get_tree().create_timer(0.6).timeout
		elif message != "":
			await turn_gate_opened

	return await check_victory()

## The one path for either side's turn -- both player and enemy pick their
## technique the same way now (Combatant.choose_technique()), so there's no
## reason left for a player-specific and an enemy-specific version of this.
func take_turn(actor: Combatant, target: Combatant, source: CombatLog.Source) -> void:
	# show_priority_skip_log logs the reasons after this turn's own messages now
	# instead of interleaved right after choose_technique() -- a one-time ordering
	# change to this off-by-default debug toggle, traded for engine.take_turn()
	# being one call instead of the live UI re-implementing its sequencing.
	for entry in engine.take_turn(actor, target):
		combat_log.add_entry(entry.message, source)
		update_hp_display(actor)
		update_hp_display(target)

		if entry.paced:
			if auto_enabled:
				await get_tree().create_timer(0.6).timeout
			else:
				await turn_gate_opened

	if show_priority_skip_log:
		for reason in engine.last_skip_reasons:
			combat_log.add_entry(reason, source)

	await advance_turn(actor)

## Each branch must `return true` explicitly, or the caller's "battle's over,
## stop here" guards never trigger and processing (and duplicate victory/
## defeat logs) continue for another full step before things settle.
##
## engine.check_victory() is guarded the same way engine's own doc comment
## describes: once it returns true here, this function always returns before
## anything could call it again on the same (now-replaced) pair.
func check_victory() -> bool:
	if not engine.check_victory():
		return false

	if engine.battle_end_player_message != "":
		combat_log.add_entry(engine.battle_end_player_message, CombatLog.Source.PLAYER)
	if engine.battle_end_enemy_message != "":
		combat_log.add_entry(engine.battle_end_enemy_message, CombatLog.Source.ENEMY)

	if engine.winner == player:
		if current_round < bracket.rounds.size() - 1:
			combat_log.add_entry("Victory! %s is defeated. Prepare for the next round!" % enemy.familiar.familiar_name, CombatLog.Source.PLAYER)

			await get_tree().create_timer(1.5).timeout
			start_next_round()
			return true

		# Bracket won -- the fixed final encounter follows, once.
		if not facing_boss and bracket.boss_familiar != null:
			combat_log.add_entry("Victory! %s is defeated. The champion awaits." % enemy.familiar.familiar_name, CombatLog.Source.PLAYER)

			await get_tree().create_timer(1.5).timeout
			start_boss_fight()
			return true

		phase = Phase.BATTLE_OVER
		combat_log.add_entry("Victory! %s is defeated." % enemy.familiar.familiar_name, CombatLog.Source.PLAYER)
		await get_tree().create_timer(2.5).timeout
		show_game_over("You win! %s has been defeated." % enemy.familiar.familiar_name)
		return true

	phase = Phase.BATTLE_OVER

	# Record the elimination in the bracket before the run ends. Nothing
	# else in this round needs resolving -- single elimination means the
	# run is over the moment the player loses (GAME_DESIGN.md §9.5).
	var lost_match: BracketMatch = player_bracket_match()
	if lost_match != null:
		lost_match.winner = enemy_familiar_data
		lost_match.revealed = true

	combat_log.add_entry("Defeat! %s is defeated." % player.familiar.familiar_name, CombatLog.Source.ENEMY)
	await get_tree().create_timer(2.5).timeout
	show_game_over("Defeat! %s has fallen." % player.familiar.familiar_name)
	return true

## Hides the in-fight HUD (same set begin_reward_sequence() hides -- none of
## it means anything once the run is decided) and shows the game-over panel.
## _on_restart_pressed() is the only way out of it.
func show_game_over(message: String) -> void:
	panels.visible = false
	arena.visible = false
	footer.visible = false
	speed_toggle_button.visible = false
	auto_toggle_button.visible = false
	advance_button.visible = false
	log_scroll.visible = false
	log_background.visible = false
	log_outer_frame.visible = false

	game_over_message_label.text = message
	game_over_panel.visible = true

func _on_restart_pressed() -> void:
	await _start_new_run()

## Read-only look at the player's current build from the reward screen --
## the mockup's "[Z] INSPECT" hint, but as an actual button rather than a
## keyboard-only affordance (per the developer's explicit "avoid all
## keyboard prompts" direction). Reuses the same familiar-card and
## PaletteBlock-list patterns already established for the priority
## builder/prefight/stat-upgrade screens rather than the plain Labels a
## first pass might reach for.
func _on_build_view_pressed() -> void:
	_populate_fighter_card(player_familiar_data, build_view_name_label, build_view_portrait, build_view_stat_list)

	for child in build_view_technique_list.get_children():
		child.queue_free()
	for technique in player_familiar_data.techniques:
		var technique_block: PaletteBlock = PALETTE_BLOCK_SCENE.instantiate()
		build_view_technique_list.add_child(technique_block)
		technique_block.setup_technique(technique, tooltip_layer)

	for child in build_view_passive_list.get_children():
		child.queue_free()
	for passive in player_familiar_data.passives:
		var passive_block: PaletteBlock = PALETTE_BLOCK_SCENE.instantiate()
		build_view_passive_list.add_child(passive_block)
		passive_block.setup_passive(passive, tooltip_layer)

	build_view_panel.visible = true

func _on_build_view_closed_pressed() -> void:
	build_view_panel.visible = false

## Read-only look at the bracket from the reward screen, reusing
## BracketScreen exactly as the between-round scouting screen already
## does (selectable = false) -- BracketScreen draws after RewardSelectPanel
## in the scene tree, so it fully covers the reward screen underneath
## without needing to hide it first.
func _on_next_opponent_panel_pressed() -> void:
	bracket_screen.setup(bracket, current_round, false, true)
	bracket_screen.visible = true
	await bracket_screen.dismissed
	bracket_screen.visible = false

## Advances to the next opponent, resets both Combatants (full heal, no
## statuses -- see DECISIONS.md), and starts the reward sequence (Phase A
## stat allocation, then Phase B's tailored reward cards). take_turn()
## only resumes once that whole sequence resolves into
## advance_to_priority_editor()/begin_fight().
## The fixed encounter after the bracket itself is won. No scouting and no
## off-screen resolution -- there is no rest of the round to resolve --
## and no reward follows it, win or lose (GAME_DESIGN.md §9.2 step 7).
## The reward sequence that runs here is round 4's, earned by winning the
## final bracket match, not a reward for the boss.
func start_boss_fight() -> void:
	facing_boss = true

	var winning_match: BracketMatch = player_bracket_match()
	if winning_match != null:
		winning_match.winner = player_familiar_data
		winning_match.revealed = true

	enemy_familiar_data = bracket.boss_familiar.duplicate_for_run()

	begin_reward_sequence()

	player = Combatant.new(player_familiar_data)
	update_hp_display(player)

	enemy = Combatant.new(enemy_familiar_data)
	enemy_frame.header_text = enemy.familiar.familiar_name
	log_view.enemy_name = enemy.familiar.familiar_name
	enemy_portrait.texture = enemy.familiar.sprite
	update_hp_display(enemy)

	player.opponent = enemy
	enemy.opponent = player
	engine = BattleEngine.new(player, enemy)

func start_next_round() -> void:
	# Record the player's own win, then roll every other match in this
	# round to its true winner (which may upset the simulated favourite)
	# before advancing -- advance_round() needs every match resolved.
	var finished_match: BracketMatch = player_bracket_match()
	if finished_match != null:
		finished_match.winner = player_familiar_data
		finished_match.revealed = true

	# The returned summaries go unused: the bracket itself now records every
	# winner, and the scouting screen shows them -- no log line needed for
	# something the player can simply read off the bracket.
	BracketResolver.resolve_round(
		bracket.rounds[current_round], current_round + 1,
		technique_reward_pool, passive_reward_pool, _bracket_rng)

	bracket.advance_round(current_round)
	current_round += 1

	# The player advances into whichever next-round match now holds them.
	for bracket_match in bracket.rounds[current_round].matches:
		if bracket_match.has_entrant(player_familiar_data):
			bracket_match.is_player_match = true
			break

	var next_match: BracketMatch = bracket.rounds[current_round].player_match()
	enemy_familiar_data = next_match.other_entrant(player_familiar_data)

	BracketResolver.scout_round(bracket.rounds[current_round])

	begin_reward_sequence()

	player = Combatant.new(player_familiar_data)
	update_hp_display(player)

	enemy = Combatant.new(enemy_familiar_data)
	enemy_frame.header_text = enemy.familiar.familiar_name
	log_view.enemy_name = enemy.familiar.familiar_name
	enemy_portrait.texture = enemy.familiar.sprite
	update_hp_display(enemy)

	player.opponent = enemy
	enemy.opponent = player
	engine = BattleEngine.new(player, enemy)
