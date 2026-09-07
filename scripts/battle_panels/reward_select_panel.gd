class_name RewardSelectPanel
extends Control

## Post-round reward sequence's Phase B screen (GAME_DESIGN.md §9.4):
## the winner/next-opponent/bracket-summary top area (shown every round
## regardless of cadence), the 3 tailored SPECIES/RUN/WILDCARD reward
## cards, and the round-4 sacrifice screen (a different card row, no
## named-slot framing) that precedes them on PASSIVE_TRADE rounds.
##
## battle_controller.gd stays the owner of reward_flow (the session that
## spans both this screen and the stat-allocation pass that follows it),
## player/enemy Combatants, and applying a confirmed reward -- this panel
## only ever receives what it needs to populate itself and signals outward
## what the player chose. Applying a reward also means healing the
## familiar and refreshing the battle HUD, both outside this panel's own
## remit; the sacrifice screen's own step-1-to-step-2 transition, by
## contrast, stays fully internal (nothing to apply yet -- see
## GiveUpPassiveOption's docstring).

signal skip_requested
signal reward_confirmed(option: UpgradeOption)
signal build_view_requested
signal next_opponent_requested

const REWARD_CARD_SCENE: PackedScene = preload("res://scenes/reward_card.tscn")
const WINNER_HP_BAR_SCENE: PackedScene = preload("res://scenes/hp_bar.tscn")

@onready var reward_title_label: Label = $Content/TopArea/TitleBlock/TitleLabel
@onready var reward_subtitle_label: Label = $Content/TopArea/TitleBlock/SubtitleLabel
@onready var winner_name_label: Label = $Content/TopArea/WinnerCard/Content/NameLabel
@onready var winner_content: HBoxContainer = $Content/TopArea/WinnerCard/Content/Row
@onready var winner_portrait: TextureRect = $Content/TopArea/WinnerCard/Content/Row/PortraitFrame/Center/Portrait
@onready var next_opponent_portrait: TextureRect = $Content/TopArea/RightColumn/NextOpponentCard/Content/PortraitFrame/Center/Portrait
@onready var next_opponent_name_label: Label = $Content/TopArea/RightColumn/NextOpponentCard/Content/NameLabel
@onready var bracket_summary_button: Button = $Content/TopArea/RightColumn/BracketSummaryCard
@onready var bracket_summary_round_label: Label = $Content/TopArea/RightColumn/BracketSummaryCard/Rows/RoundLabel
@onready var bracket_summary_remaining_label: Label = $Content/TopArea/RightColumn/BracketSummaryCard/Rows/RemainingLabel
@onready var choose_reward_label: Label = $Content/ChooseRewardLabel
@onready var card_row: HBoxContainer = $Content/CardRow
@onready var species_column: VBoxContainer = $Content/CardRow/SpeciesColumn/Content
@onready var run_column: VBoxContainer = $Content/CardRow/RunColumn/Content
@onready var pivot_column: VBoxContainer = $Content/CardRow/PivotColumn/Content
@onready var sacrifice_card_row: HBoxContainer = $Content/SacrificeCardRow
@onready var rerolls_remaining_label: Label = $Content/ActionRow/RerollsRemainingLabel
@onready var skip_button: Button = $Content/ActionRow/SkipButton
@onready var next_round_button: Button = $Content/ActionRow/NextRoundButton
@onready var build_view_button: Button = $Content/ActionRow/ViewBuildButton

## The 3 RewardCards share one ButtonGroup (exactly one selected at a
## time) but each column keeps its own separate RerollButton outside the
## group -- see the reward-screen plan's note on why ButtonGroup still
## fits despite per-slot rerolls.
var _reward_card_group: ButtonGroup = ButtonGroup.new()
var _reward_cards: Dictionary = {}  # RewardSelector.RewardSlot -> RewardCard
var _slot_columns: Dictionary = {}  # RewardSelector.RewardSlot -> VBoxContainer
var _selected_reward_option: UpgradeOption = null

## -- Sacrifice screen (round 4's PASSIVE_TRADE cadence, step 1 of 2) --
## Its own ButtonGroup/selection state rather than reusing the reward-card
## ones above: a genuinely separate screen and step, never shown at the
## same time, so there's no reason for one's stale selection to have any
## chance of bleeding into the other's.
var _sacrifice_card_group: ButtonGroup = ButtonGroup.new()
var _in_sacrifice_pick_step: bool = false
var _selected_sacrifice_passive: PassiveEffect = null

var _familiar: Familiar
var _reward_flow: RewardFlowController
var _tooltip_layer: TooltipLayer


func _ready() -> void:
	_slot_columns = {
		RewardSelector.RewardSlot.SPECIES: species_column,
		RewardSelector.RewardSlot.RUN: run_column,
		RewardSelector.RewardSlot.PIVOT: pivot_column,
	}
	for slot in _slot_columns:
		var column: VBoxContainer = _slot_columns[slot]
		column.get_node("RerollButton").pressed.connect(_on_reroll_pressed.bind(slot))

	skip_button.pressed.connect(func() -> void: skip_requested.emit())
	next_round_button.pressed.connect(_on_next_round_pressed)
	bracket_summary_button.pressed.connect(func() -> void: next_opponent_requested.emit())
	build_view_button.pressed.connect(func() -> void: build_view_requested.emit())


## Populates the top area (winner card, next-opponent preview, bracket
## summary) -- shown every round regardless of which cadence branch
## follows, so battle_controller.gd calls this once up front rather than
## duplicating it into both begin_reward_cards() and
## begin_sacrifice_screen(). rounds_remaining is only meaningful when
## not facing_boss (the champion fight has no "rounds remain" to show).
func show_top_area(player: Combatant, defeated_enemy_name: String, enemy_familiar_data: Familiar, current_round: int, facing_boss: bool, rounds_remaining: int) -> void:
	reward_title_label.text = "BOUT WON!"
	reward_subtitle_label.text = "%s defeated %s!" % [player.familiar.familiar_name, defeated_enemy_name]
	winner_name_label.text = player.familiar.familiar_name
	_populate_winner_card(player)

	next_opponent_portrait.texture = enemy_familiar_data.sprite
	next_opponent_name_label.text = enemy_familiar_data.familiar_name

	if facing_boss:
		bracket_summary_round_label.text = "Champion"
		bracket_summary_remaining_label.text = "Final bout"
	else:
		bracket_summary_round_label.text = Bracket.round_display_name(current_round)
		bracket_summary_remaining_label.text = "%d round%s remain" % [
			rounds_remaining, "s" if rounds_remaining != 1 else ""
		]


## Rebuilds the HPBar next to the static PortraitFrame -- built fresh each
## time rather than kept as a static scene child, same reasoning as every
## other "rebuild per round" list on these screens (a fresh HPBar needs its
## own StyleBoxFlat instances, per HPBar.set_hp()'s own documented quirk of
## only ever mutating whatever fill style it finds).
## No StatusRow here -- per the mockup, WinnerCard shows name + sprite + HP
## only, not the winner's lingering statuses.
func _populate_winner_card(player: Combatant) -> void:
	var portrait_frame: Control = winner_content.get_node("PortraitFrame")
	for child in winner_content.get_children():
		if child == portrait_frame:
			continue
		winner_content.remove_child(child)
		child.queue_free()

	var hp_bar: HPBar = WINNER_HP_BAR_SCENE.instantiate()
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


## Shared by both the sacrifice screen's step 2 (replacement passives) and
## every normal TECHNIQUE/PASSIVE round -- resets every bit of UI state
## the sacrifice screen's step 1 touches, so a fresh reward screen never
## silently inherits sacrifice-mode leftovers from a previous round.
func begin_reward_cards(familiar: Familiar, reward_flow: RewardFlowController, tooltip_layer: TooltipLayer, show_skip: bool) -> void:
	_familiar = familiar
	_reward_flow = reward_flow
	_tooltip_layer = tooltip_layer

	_in_sacrifice_pick_step = false
	choose_reward_label.text = "CHOOSE YOUR REWARD"
	sacrifice_card_row.visible = false
	card_row.visible = true

	_populate_reward_cards()
	skip_button.visible = show_skip
	visible = true


## Destroys and recreates all 3 slot cards for a fresh screen (a reroll
## instead reuses the existing card -- see _on_reroll_pressed()).
func _populate_reward_cards() -> void:
	_selected_reward_option = null
	next_round_button.disabled = true

	for slot in _slot_columns:
		var column: VBoxContainer = _slot_columns[slot]

		if _reward_cards.has(slot):
			var old_card: RewardCard = _reward_cards[slot]
			column.remove_child(old_card)
			old_card.queue_free()
			_reward_cards.erase(slot)

		var option: UpgradeOption = _reward_flow.candidate_for_slot(slot)
		if option == null:
			continue

		var card: RewardCard = REWARD_CARD_SCENE.instantiate()
		column.add_child(card)
		column.move_child(card, 0)  # before RerollButton -- the column's own FramedPanel tab is the slot label now
		card.button_group = _reward_card_group
		card.setup(option, _tooltip_layer)
		card.toggled.connect(_on_reward_card_toggled.bind(slot))
		_reward_cards[slot] = card

	_refresh_reroll_buttons()


func _on_reward_card_toggled(pressed: bool, slot: RewardSelector.RewardSlot) -> void:
	if not pressed:
		return
	_selected_reward_option = _reward_flow.candidate_for_slot(slot)
	next_round_button.disabled = _selected_reward_option == null


func _refresh_reroll_buttons() -> void:
	rerolls_remaining_label.text = "Rerolls left: %d" % _reward_flow.rerolls_remaining
	var available: bool = _reward_flow.rerolls_remaining > 0 and _reward_flow.has_unseen_candidates()
	for slot in _slot_columns:
		var column: VBoxContainer = _slot_columns[slot]
		column.get_node("RerollButton").disabled = not available


## Rerolls exactly one slot in place -- reuses the existing RewardCard
## node (re-setup() with the new candidate) rather than destroying and
## recreating it, so the shared ButtonGroup never needs re-registering.
func _on_reroll_pressed(slot: RewardSelector.RewardSlot) -> void:
	if not _reward_flow.reroll_slot(slot, _familiar):
		return

	var card: RewardCard = _reward_cards.get(slot)
	var option: UpgradeOption = _reward_flow.candidate_for_slot(slot)
	if card == null or option == null:
		return

	# The rerolled slot's previous content is gone -- clear its selection
	# state (through the ButtonGroup) rather than leave a stale choice
	# pointing at an option that's no longer offered.
	if card.button_pressed:
		_selected_reward_option = null
		next_round_button.disabled = true
	card.button_pressed = false
	card.setup(option, _tooltip_layer)

	_refresh_reroll_buttons()


## Sacrifice screen, step 1 of 2 (round 4's PASSIVE_TRADE cadence): pick
## which currently-held passive to give up. Styled like the normal
## reward-cards screen it shares a panel with (same TopArea/title-row
## shell, RewardCard-shaped options) but without the SPECIES/RUN/WILDCARD
## named-slot framing -- there's no fixed-slot concept here, just
## "however many passives are currently held". A selection is toggled,
## not immediate-fire -- the same misclick protection RewardCard's own
## toggle-then-confirm interaction already gives every other one-way
## reward pick applies here too, arguably more so: unlike a normal pick,
## there's no way to reconsider which passive got chosen once step 2
## (the replacement-passive cards) is showing. Confirming moves to that
## step 2 internally -- nothing to apply yet, so battle_controller.gd
## never needs to hear about it (see GiveUpPassiveOption's docstring).
func begin_sacrifice_screen(familiar: Familiar, reward_flow: RewardFlowController, tooltip_layer: TooltipLayer) -> void:
	_familiar = familiar
	_reward_flow = reward_flow
	_tooltip_layer = tooltip_layer

	_in_sacrifice_pick_step = true
	_selected_sacrifice_passive = null
	next_round_button.disabled = true

	choose_reward_label.text = "SACRIFICE A PASSIVE"
	# Blanked, not hidden -- RerollsRemainingLabel is the ActionRow's only
	# size_flags_horizontal=EXPAND_FILL child, so hiding it outright (as
	# opposed to leaving it present with empty text) removes it from the
	# HBoxContainer's layout entirely, collapsing the Skip/View
	# Build/Confirm buttons to the left edge instead of the right, unlike
	# every other reward screen.
	rerolls_remaining_label.text = ""
	card_row.visible = false
	sacrifice_card_row.visible = true

	_populate_sacrifice_cards()

	# The big Skip card in the row above now carries this same action,
	# more prominently -- keeping the small footer button too would just
	# be a confusing second way to do the identical thing.
	skip_button.visible = false
	visible = true


## One RewardCard per currently-held passive, sharing their own
## ButtonGroup (kept separate from the reward-cards screen's -- see
## _selected_sacrifice_passive's own declaration for why). See
## GiveUpPassiveOption's docstring for why these carry no real apply().
## A third card, Skip, always sits at the end of the row -- not part of
## that ButtonGroup (it fires immediately on click, like the reward-cards
## screen's own Skip button, not a toggle-then-confirm choice), so
## sacrifice is visibly just as valid an option as either passive.
func _populate_sacrifice_cards() -> void:
	for child in sacrifice_card_row.get_children():
		child.queue_free()

	for passive in _reward_flow.sacrifice_options(_familiar):
		var option := GiveUpPassiveOption.new()
		option.passive = passive
		option.label = "Give up %s" % passive.passive_name

		var card: RewardCard = REWARD_CARD_SCENE.instantiate()
		sacrifice_card_row.add_child(card)
		card.button_group = _sacrifice_card_group
		card.setup(option, _tooltip_layer)
		card.toggled.connect(_on_sacrifice_card_toggled.bind(passive))

	var skip_card: RewardCard = REWARD_CARD_SCENE.instantiate()
	sacrifice_card_row.add_child(skip_card)
	skip_card.setup(SkipSacrificeOption.new(), _tooltip_layer)
	skip_card.pressed.connect(func() -> void: skip_requested.emit())


func _on_sacrifice_card_toggled(pressed: bool, passive: PassiveEffect) -> void:
	if not pressed:
		return
	_selected_sacrifice_passive = passive
	next_round_button.disabled = false


## Confirm button shared by the sacrifice screen's step 1 (which passive
## to give up) and every other reward pick (step 2 included) -- dispatches
## on _in_sacrifice_pick_step rather than needing two separately-wired
## buttons for what the player experiences as one "confirm" action.
func _on_next_round_pressed() -> void:
	if _in_sacrifice_pick_step:
		_confirm_sacrifice_pick()
		return

	if _selected_reward_option == null:
		return
	reward_confirmed.emit(_selected_reward_option)


func _confirm_sacrifice_pick() -> void:
	if _selected_sacrifice_passive == null:
		return
	_in_sacrifice_pick_step = false
	_reward_flow.resolve_sacrifice(_selected_sacrifice_passive, _familiar)
	begin_reward_cards(_familiar, _reward_flow, _tooltip_layer, false)
