class_name BracketScreen
extends VBoxContainer

## The bracket view, used in two modes:
##   selectable = true  -- round 1's character select, with a Select
##                         Fighter button that commits the player's draft
##   selectable = false -- every later round's scouting view, read-only
##
## selectable = false also covers a second, visually distinct case: a
## read-only popup opened from elsewhere (currently the reward screen's
## "next opponent" preview, battle_controller.gd's
## _on_next_opponent_panel_pressed()). That case passes is_popup = true,
## which swaps the bottom Continue button for a modal-style close "×" in
## the top-right corner instead -- a full-screen round transition reads
## right with a bottom Continue button, but a popup layered over another
## already-visible screen reads as something to close, not advance past.
##
## Hovering an entrant shows its odds and species tags through the shared
## TooltipLayer; clicking one pins the full detail panel.
##
## Later rounds also list the previous round's finished matches, so the
## player can just see who won rather than being told in a log line.

signal entrant_selected(familiar: Familiar)
signal dismissed

@onready var title_label: Label = $TitleLabel
@onready var entrant_list: VBoxContainer = $Body/Content/EntrantScroll/Content/EntrantList
@onready var detail_panel: Control = $Body/Content/DetailPanel
@onready var detail_name: Label = $Body/Content/DetailPanel/Content/DetailName
@onready var detail_portrait: TextureRect = $Body/Content/DetailPanel/Content/DetailPortrait
@onready var detail_tags: Label = $Body/Content/DetailPanel/Content/DetailTags
@onready var detail_stats: Label = $Body/Content/DetailPanel/Content/DetailStats
@onready var detail_techniques: Label = $Body/Content/DetailPanel/Content/DetailTechniques
@onready var detail_odds: Label = $Body/Content/DetailPanel/Content/DetailOdds
@onready var select_button: Button = $Body/Content/DetailPanel/Content/SelectButton
@onready var continue_button: Button = $ContinueButton
@onready var close_button: Button = $Body/CloseButton

var tooltip_layer: TooltipLayer

var _selected: Familiar
var _odds_by_name: Dictionary = {}   # familiar_name -> String

func _ready() -> void:
	select_button.pressed.connect(_on_select_pressed)
	continue_button.pressed.connect(func() -> void: dismissed.emit())
	close_button.pressed.connect(func() -> void: dismissed.emit())

## Rebuilds the whole screen for one round. Everything is torn down and
## rebuilt rather than diffed, since each row closes over a specific
## Familiar instance -- the same reasoning PriorityBuilder.setup() uses.
func setup(bracket: Bracket, round_index: int, selectable: bool, is_popup: bool = false) -> void:
	_selected = null
	_odds_by_name.clear()

	title_label.text = "Choose your familiar" if selectable else "Round %d" % (round_index + 1)
	select_button.visible = selectable
	continue_button.visible = not selectable and not is_popup
	close_button.visible = not selectable and is_popup

	for child in entrant_list.get_children():
		entrant_list.remove_child(child)
		child.queue_free()

	# Last round's finished matches first -- this is the reveal. No log
	# line needed for something the player can simply read here.
	if round_index > 0:
		_add_heading("Round %d results" % round_index)
		for bracket_match in bracket.rounds[round_index - 1].matches:
			if bracket_match.revealed:
				_add_result_row(bracket_match)
		_add_spacer(16)
		_add_heading("Round %d" % (round_index + 1))

	for bracket_match in bracket.rounds[round_index].matches:
		if not bracket_match.is_ready():
			continue
		_record_odds(bracket_match)
		_add_row(bracket_match.entrant_a, bracket_match)
		_add_row(bracket_match.entrant_b, bracket_match)
		_add_spacer(8)

	_clear_detail()

## Both entrants share the match's single label, mirrored: the label is
## stored from entrant_a's point of view, so entrant_b gets its opposite.
func _record_odds(bracket_match: BracketMatch) -> void:
	if bracket_match.odds_label == "":
		return
	_odds_by_name[bracket_match.entrant_a.familiar_name] = bracket_match.odds_label
	_odds_by_name[bracket_match.entrant_b.familiar_name] = _mirror_label(bracket_match.odds_label)

func _mirror_label(label: String) -> String:
	match label:
		BracketOdds.LABEL_HEAVY_FAVORITE:
			return BracketOdds.LABEL_HEAVY_UNDERDOG
		BracketOdds.LABEL_FAVORITE:
			return BracketOdds.LABEL_UNDERDOG
		BracketOdds.LABEL_UNDERDOG:
			return BracketOdds.LABEL_FAVORITE
		BracketOdds.LABEL_HEAVY_UNDERDOG:
			return BracketOdds.LABEL_HEAVY_FAVORITE
	return BracketOdds.LABEL_TOSS_UP

func _add_heading(text: String) -> void:
	var heading := Label.new()
	heading.text = text
	entrant_list.add_child(heading)

func _add_spacer(height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	entrant_list.add_child(spacer)

## A finished match, winner first, so scanning the column reads as a
## list of who advanced.
func _add_result_row(bracket_match: BracketMatch) -> void:
	if bracket_match.winner == null:
		return
	var beaten: Familiar = bracket_match.other_entrant(bracket_match.winner)
	var row := Label.new()
	row.text = "    %s def. %s" % [
		bracket_match.winner.familiar_name,
		beaten.familiar_name if beaten != null else "?",
	]
	entrant_list.add_child(row)

func _add_row(familiar: Familiar, bracket_match: BracketMatch) -> void:
	var row := Button.new()
	row.text = "%s   %s" % [familiar.familiar_name, _odds_for(familiar)]
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if bracket_match.is_player_match:
		row.text += "   (your match)"

	row.pressed.connect(_on_row_pressed.bind(familiar))
	if tooltip_layer != null:
		row.mouse_entered.connect(func() -> void: tooltip_layer.hover_started(row, _tooltip_text(familiar)))
		row.mouse_exited.connect(func() -> void: tooltip_layer.hover_ended(row))

	entrant_list.add_child(row)

func _odds_for(familiar: Familiar) -> String:
	return _odds_by_name.get(familiar.familiar_name, "")

func _tooltip_text(familiar: Familiar) -> String:
	var odds: String = _odds_for(familiar)
	var lines: Array[String] = [familiar.familiar_name]
	if odds != "":
		lines.append(odds)
	lines.append(_tag_text(familiar))
	return "\n".join(lines)

func _tag_text(familiar: Familiar) -> String:
	if familiar.species_affinities.is_empty():
		return "No known affinities"
	var names: Array[String] = []
	for affinity in familiar.species_affinities:
		names.append(String(RewardTag.Tag.keys()[affinity.tag]).capitalize())
	return ", ".join(names)

func _on_row_pressed(familiar: Familiar) -> void:
	_selected = familiar
	detail_name.text = familiar.familiar_name
	detail_portrait.texture = familiar.sprite
	detail_tags.text = "Playstyle: %s" % _tag_text(familiar)
	detail_stats.text = "HP %d   Power %d   Defense %d   Speed %d   Focus %d" % [
		familiar.max_hp, familiar.power, familiar.defense, familiar.speed, familiar.focus
	]

	var technique_names: Array[String] = []
	for technique in familiar.techniques:
		technique_names.append(technique.technique_name)
	detail_techniques.text = "Techniques: %s" % ", ".join(technique_names)

	var odds: String = _odds_for(familiar)
	if odds == "":
		detail_odds.text = ""
	else:
		detail_odds.text = "Matchup: %s" % odds

	select_button.disabled = false
	detail_panel.visible = true

## Also hides the panel entirely rather than leaving an empty frame sitting
## next to the entrant list -- EntrantScroll's own EXPAND_FILL size flags
## mean it just grows into the freed column once DetailPanel is hidden,
## Content being an HBoxContainer.
func _clear_detail() -> void:
	detail_name.text = ""
	detail_portrait.texture = null
	detail_tags.text = ""
	detail_stats.text = ""
	detail_techniques.text = ""
	detail_odds.text = ""
	select_button.disabled = true
	detail_panel.visible = false

func _on_select_pressed() -> void:
	if _selected == null:
		return
	entrant_selected.emit(_selected)
