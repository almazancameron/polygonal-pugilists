class_name BracketTree
extends Control

## Literal bracket-tree visualization (assets/ui_mockup/bracket_mockup.png):
## 16 entrant leaf slots at the outer edges (8 per side, seeded straight
## from bracket.rounds[0]), converging inward through Preliminary ->
## Quarterfinal -> Semifinal connector nodes to a single centered Final
## box.
##
## Every still-alive entrant has exactly one "live" position -- their full
## interactive card (sprite, name, seed, odds) -- which is their original
## leaf slot until they win round 0, at which point it moves inward to
## round 0's own connector node, then to round 1's, and so on: each win
## promotes the card one tier further in, never further than the tier
## whose next round hasn't been decided yet (see _current_slot_key()).
## Every tier a still-alive entrant has already passed through downgrades
## from the full card to a small box showing just their sprite; an
## eliminated entrant's small box additionally gets a red X (drawn at
## whichever tier they actually lost at, not retroactively at earlier
## ones). A connector node whose match hasn't been decided yet is a plain
## "?" box, same as before.
##
## Hardcodes Bracket's fixed shape (ENTRANT_COUNT == 16, always 4 rounds)
## rather than generalizing over an arbitrary bracket size -- this project
## only ever has one.

signal entrant_hovered(familiar: Familiar, control: Control)
signal entrant_unhovered(control: Control)
signal entrant_clicked(familiar: Familiar)

const LEAVES_PER_SIDE: int = 8
const ROUND_COUNT: int = 4

## Reference proportions only -- _compute_layout() scales every dimension
## below to whatever rect this control is actually given (Body/Content's
## HBoxContainer grows EntrantScroll to fill the screen when DetailPanel
## is hidden, shrinks it back when DetailPanel reappears), so the tree
## always fills its space exactly rather than sitting at a fixed pixel
## size inside a scroll view.
const LEAF_WIDTH: float = 150.0
const LEAF_HEIGHT: float = 38.0
const LEAF_GAP: float = 12.0
const CONNECTOR_SIZE: float = 44.0
const FINAL_SIZE: float = 64.0
const COLUMN_GAP: float = 26.0
const SPRITE_SIZE: float = 22.0
const LINE_WIDTH: float = 2.0

## Fixed (not scaled) -- a small, constant breathing room above the
## topmost and below the bottommost leaf row, so they don't sit flush
## against the panel's own edge or get clipped by it.
const VERTICAL_PADDING: float = 32.0

## How far the Final box sits above true vertical center, as a fraction of
## the distance from center to the very top of the padded content area --
## 0.0 would be dead-center (halfway between the topmost and bottommost
## leaf), 1.0 would put it flush against the top padding. 0.5 lands it
## halfway in between, matching the mockup's crown reading as "above the
## middle" rather than exactly centered.
const FINAL_Y_LIFT: float = 0.5

const BOX_FILL: Color = Color(0.09, 0.10, 0.13, 1.0)
const LOSER_X_COLOR: Color = Palette.HP_LOW

var _bracket: Bracket
var _selected: Familiar

## familiar_name -> BracketOdds label String, as computed by
## BracketScreen._record_odds() -- read here only to color/label each live
## card's own odds line, never mutated.
var _odds_by_name: Dictionary = {}

## Familiar -> Panel for each currently drawn live entrant card, at any tier.
var _entrant_panels: Dictionary = {}

## "leaf_<i>" / "match_<round>_<index>" -> Rect2, populated by
## _compute_layout(), read by both _build_leaf_cards() (live entrant cards)
## and _draw() (connector lines/boxes, every round).
var _box_rects: Dictionary = {}

## This layout pass's actual (scaled-to-fit) dimensions -- see the
## constants above for what each corresponds to at reference scale.
var _leaf_width: float
var _leaf_height: float
var _leaf_gap: float
var _connector_width: float
var _connector_height: float
var _final_width: float
var _final_height: float
var _column_gap: float

func _ready() -> void:
	resized.connect(_relayout)

func setup(bracket: Bracket, selected: Familiar = null, odds_by_name: Dictionary = {}) -> void:
	_bracket = bracket
	_selected = selected
	_odds_by_name = odds_by_name
	_relayout()

## Recomputes the whole layout against this control's current size and
## rebuilds every live entrant card -- called on setup() and whenever the parent
## Container resizes us (DetailPanel showing/hiding). A no-op if we don't
## have a real size yet (e.g. one frame before the parent Container has
## laid out): resized will fire again once we do.
func _relayout() -> void:
	if _bracket == null:
		return
	_compute_layout()
	if _box_rects.is_empty():
		return
	_build_leaf_cards()
	queue_redraw()

## Repaints just the highlight border -- used by round-1 draft as the
## player clicks between candidates, without tearing down every card
## (which would drop hover state mid-interaction). _selected has to move
## to its new value BEFORE either panel is restyled -- _style_leaf_panel()
## decides gold-or-not by comparing its familiar against _selected, so
## restyling the previous card while _selected still pointed at it would
## just paint it gold again instead of clearing it.
func set_selected(familiar: Familiar) -> void:
	var previous: Familiar = _selected
	_selected = familiar
	if previous != null and _entrant_panels.has(previous):
		_style_leaf_panel(_entrant_panels[previous], previous)
	if _entrant_panels.has(_selected):
		_style_leaf_panel(_entrant_panels[_selected], _selected)

## ---- Layout ----

## Bottom-up midpoint layout, identical for both halves (they're mirror
## images of each other vertically, only x differs) -- see the recursive
## comment on _local_y() for why round_index alone (no left/right) is
## enough to compute every connector's y.
func _local_y(round_index: int, local_index: int) -> float:
	if round_index == 0:
		var leaf_a: float = _leaf_local_y(local_index * 2)
		var leaf_b: float = _leaf_local_y(local_index * 2 + 1)
		return (leaf_a + leaf_b) / 2.0
	var child_a: float = _local_y(round_index - 1, local_index * 2)
	var child_b: float = _local_y(round_index - 1, local_index * 2 + 1)
	return (child_a + child_b) / 2.0

func _leaf_local_y(local_index: int) -> float:
	return local_index * (_leaf_height + _leaf_gap) + _leaf_height / 2.0

## Reference total width used by scale_x = size.x / _reference_total_width().
## Includes both mirrored halves and the shared Final once. This calibrates
## the initial leaf-card layout; _compute_layout() assigns full card widths
## to the active tier and small box widths to the others.
func _reference_total_width() -> float:
	var half_to_final: float = LEAF_WIDTH + COLUMN_GAP
	for _r in range(ROUND_COUNT - 1):
		half_to_final += CONNECTOR_SIZE + COLUMN_GAP
	return half_to_final * 2.0 + FINAL_SIZE

## Which connector tier (0..ROUND_COUNT-1, with the last being the Final) is
## currently hosting the live, leaf-width cards -- -1 if round 0 isn't
## even fully decided yet, meaning every still-alive entrant is still at
## leaf level. Every still-alive entrant advances together (a whole round
## resolves as one batch, see _current_slot_key()), so there's only ever
## one such column at a time, never a mix.
func _live_connector_tier() -> int:
	var tier: int = -1
	for r in range(ROUND_COUNT):
		var round_fully_decided: bool = true
		for bracket_match in _bracket.rounds[r].matches:
			if bracket_match.winner == null:
				round_fully_decided = false
				break
		if round_fully_decided:
			tier = r
		else:
			break
	return tier

func _compute_layout() -> void:
	_box_rects.clear()
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var design_content_height: float = LEAVES_PER_SIDE * (LEAF_HEIGHT + LEAF_GAP) - LEAF_GAP
	var available_height: float = max(size.y - VERTICAL_PADDING * 2.0, 1.0)
	var scale_y: float = available_height / design_content_height
	_leaf_height = LEAF_HEIGHT * scale_y
	_leaf_gap = LEAF_GAP * scale_y
	_connector_height = CONNECTOR_SIZE * scale_y
	_final_height = FINAL_SIZE * scale_y

	var scale_x: float = size.x / _reference_total_width()
	_leaf_width = LEAF_WIDTH * scale_x
	_connector_width = CONNECTOR_SIZE * scale_x
	_final_width = FINAL_SIZE * scale_x
	_column_gap = COLUMN_GAP * scale_x

	# col_widths[0] is the Leaf column's actual width this pass;
	# col_widths[1..ROUND_COUNT-1] are Conn0.. Conn(ROUND_COUNT-2)'s.
	# Exactly one of these (or the Final, tracked separately) is ever the
	# live column -- see _live_connector_tier() -- and gets _leaf_width;
	# every other column is small (_connector_width, or _final_width for
	# the Final specifically while it's still undecided). Gaps between
	# columns stay uniform at _column_gap regardless -- only the column
	# widths themselves change, which is what keeps a small icon box's
	# edges flush with the connector line drawn to it (both now agree on
	# the same, correctly-small box_rect) instead of the icon floating,
	# centered, inside a leftover leaf-sized rect.
	var col_widths: Array[float] = []
	for _i in range(ROUND_COUNT):
		col_widths.append(_connector_width)
	var final_width_actual: float = _final_width

	var live_tier: int = _live_connector_tier()
	if live_tier == ROUND_COUNT - 1:
		final_width_actual = _leaf_width
	else:
		col_widths[live_tier + 1] = _leaf_width  # index 0 == Leaf when live_tier == -1

	# Heights mirror the widths above exactly: only the live column's
	# slots are leaf-height, everything else shrinks to connector-height
	# (or final-height for an undecided Final) -- but note this only
	# changes each box_rect's own height, never the Y each row sits at
	# (_leaf_local_y()/_local_y() below are fixed regardless), so rows
	# don't visually shift as entrants downgrade or get promoted.
	var col_heights: Array[float] = []
	for _i in range(ROUND_COUNT):
		col_heights.append(_connector_height)
	var final_height_actual: float = _final_height
	if live_tier == ROUND_COUNT - 1:
		final_height_actual = _leaf_height
	else:
		col_heights[live_tier + 1] = _leaf_height

	var left_col_x: Array[float] = []
	var x: float = col_widths[0] + _column_gap
	for r in range(ROUND_COUNT - 1):
		left_col_x.append(x)
		x += col_widths[r + 1] + _column_gap
	var final_x: float = x
	var total_width: float = final_x * 2.0 + final_width_actual

	# Leaves (round 0's entrant_a/entrant_b endpoints, not a BracketRound
	# of their own).
	for global_leaf in range(LEAVES_PER_SIDE * 2):
		var is_left: bool = global_leaf < LEAVES_PER_SIDE
		var local_index: int = global_leaf if is_left else global_leaf - LEAVES_PER_SIDE
		var box_w: float = col_widths[0]
		var box_h: float = col_heights[0]
		var box_x: float = 0.0 if is_left else total_width - box_w
		var y: float = _leaf_local_y(local_index) + VERTICAL_PADDING
		_box_rects["leaf_%d" % global_leaf] = Rect2(
			box_x, y - box_h / 2.0, box_w, box_h
		)

	for round_index in range(ROUND_COUNT):
		var matches_this_round: int = _bracket.rounds[round_index].matches.size()
		for match_index in range(matches_this_round):
			var is_left: bool = round_index < ROUND_COUNT - 1 and match_index < matches_this_round / 2
			var local_index: int = match_index if is_left else match_index - matches_this_round / 2

			var y: float
			if round_index == ROUND_COUNT - 1:
				# The Final's two children are the LEFT half's semifinal and
				# the RIGHT half's semifinal -- two different halves, not
				# local indices 0 and 1 of one half the way every other
				# round's pairing works. _local_y()'s doubling recursion
				# only makes sense within a single half's own sub-tree, so
				# calling it here would recurse into out-of-range local
				# indices for round ROUND_COUNT-2 (which only ever has
				# local index 0 per half) and land on a bogus, skewed-low
				# result. Both halves' semifinal y are identical by
				# symmetry, so read it directly instead of recursing.
				# FINAL_Y_LIFT then pulls it up 50% of the way from that
				# true center toward the very top of the padded content
				# area, rather than sitting dead-center.
				var center_y: float = _local_y(round_index - 1, 0)
				y = center_y * (1.0 - FINAL_Y_LIFT) + VERTICAL_PADDING
			else:
				y = _local_y(round_index, local_index) + VERTICAL_PADDING

			var box_w: float = final_width_actual if round_index == ROUND_COUNT - 1 else col_widths[round_index + 1]
			var box_h: float = final_height_actual if round_index == ROUND_COUNT - 1 else col_heights[round_index + 1]
			var box_x: float
			if round_index == ROUND_COUNT - 1:
				box_x = final_x
			elif is_left:
				box_x = left_col_x[round_index]
			else:
				box_x = total_width - left_col_x[round_index] - box_w

			_box_rects[_match_key(round_index, match_index)] = Rect2(
				box_x, y - box_h / 2.0, box_w, box_h
			)

func _match_key(round_index: int, match_index: int) -> String:
	return "match_%d_%d" % [round_index, match_index]

## ---- Live entrant cards (the interactive child nodes at the active tier;
## everything else is drawn directly in _draw()) ----

func _build_leaf_cards() -> void:
	for panel in _entrant_panels.values():
		panel.queue_free()
	_entrant_panels.clear()

	for match_index in range(LEAVES_PER_SIDE):
		var bracket_match: BracketMatch = _bracket.rounds[0].matches[match_index]
		_maybe_build_entrant_card(bracket_match.entrant_a, match_index * 2)
		_maybe_build_entrant_card(bracket_match.entrant_b, match_index * 2 + 1)

## Where `familiar`'s live, interactive full card currently belongs --
## "leaf_<i>" (hasn't won round 0 yet) or "match_<r>_<m>" (has won up
## through round r, but hasn't yet won -- or lost -- round r+1). Returns
## "" once they've lost anywhere; a loss never gets a live card, only the
## small crossed-out box _draw() paints at whichever tier they lost.
func _current_slot_key(familiar: Familiar, global_leaf: int) -> String:
	var round0_match: BracketMatch = _bracket.rounds[0].matches[global_leaf / 2]
	if round0_match.winner == null:
		return "leaf_%d" % global_leaf
	if round0_match.winner != familiar:
		return ""

	var cur_round: int = 0
	var cur_match_index: int = global_leaf / 2
	for _step in range(ROUND_COUNT):
		if cur_round == ROUND_COUNT - 1:
			return _match_key(cur_round, cur_match_index)

		var next_round: int = cur_round + 1
		var next_match_index: int = cur_match_index / 2
		var next_match: BracketMatch = _bracket.rounds[next_round].matches[next_match_index]
		if next_match.winner == null:
			return _match_key(cur_round, cur_match_index)
		if next_match.winner != familiar:
			return ""

		cur_round = next_round
		cur_match_index = next_match_index

	return _match_key(cur_round, cur_match_index)  # unreachable -- ROUND_COUNT steps always hits the round-1 case above first

func _maybe_build_entrant_card(familiar: Familiar, global_leaf: int) -> void:
	if familiar == null:
		return

	var slot_key: String = _current_slot_key(familiar, global_leaf)
	if slot_key == "":
		return

	# _compute_layout() sizes every live card in the active tier at full card
	# dimensions. There can be many live cards in that tier; this entrant's
	# box_rect already has the required size and position.
	var rect: Rect2 = _box_rects[slot_key]

	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(func() -> void: entrant_hovered.emit(familiar, panel))
	panel.mouse_exited.connect(func() -> void: entrant_unhovered.emit(panel))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			entrant_clicked.emit(familiar)
	)
	add_child(panel)
	_entrant_panels[familiar] = panel
	_style_leaf_panel(panel, familiar)

	var card_sprite_size: float = min(rect.size.y * (SPRITE_SIZE / LEAF_HEIGHT), rect.size.y - 4.0)

	var sprite := TextureRect.new()
	sprite.texture = familiar.sprite
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.position = Vector2(6, (rect.size.y - card_sprite_size) / 2.0)
	sprite.size = Vector2(card_sprite_size, card_sprite_size)
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sprite)

	var seed_label := Label.new()
	seed_label.text = str(global_leaf + 1)
	seed_label.add_theme_color_override("font_color", Palette.ENEMY_ACCENT)
	seed_label.add_theme_font_size_override("font_size", 12)
	seed_label.position = Vector2(4, 2)
	seed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(seed_label)

	var text_x: float = card_sprite_size + 12
	var text_width: float = rect.size.x - card_sprite_size - 16

	var name_label := Label.new()
	name_label.text = familiar.familiar_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.position = Vector2(text_x, 0)
	name_label.size = Vector2(text_width, rect.size.y * 0.55)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(name_label)

	var odds_text: String = _odds_by_name.get(familiar.familiar_name, "")
	if odds_text != "":
		var odds_label := Label.new()
		odds_label.text = odds_text
		odds_label.add_theme_font_size_override("font_size", 10)
		odds_label.add_theme_color_override("font_color", BracketOdds.label_color(odds_text))
		odds_label.position = Vector2(text_x, rect.size.y * 0.5)
		odds_label.size = Vector2(text_width, rect.size.y * 0.5)
		odds_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		odds_label.clip_text = true
		odds_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(odds_label)

func _style_leaf_panel(panel: Panel, familiar: Familiar) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BOX_FILL
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)

	if familiar == _selected:
		style.border_color = Palette.GOLD_ACCENT
	elif _is_player_familiar(familiar):
		style.border_color = Palette.PLAYER_ACCENT
	else:
		style.border_color = Palette.PANEL_BORDER

	panel.add_theme_stylebox_override("panel", style)

func _is_player_familiar(familiar: Familiar) -> bool:
	for bracket_round in _bracket.rounds:
		for bracket_match in bracket_round.matches:
			if bracket_match.is_player_match and bracket_match.has_entrant(familiar):
				return true
	return false

## ---- Decorative boxes and connecting lines; live cards are child Panels ----
func _draw() -> void:
	if _bracket == null:
		return

	# Leaves: only decided ones need drawing at all here (an undecided
	# leaf's full card is the interactive Panel _build_leaf_cards() already
	# built there). A decided leaf always downgrades to a small box --
	# plain for the winner (their live card has moved on to round 0's
	# connector), crossed out for the loser.
	for global_leaf in range(LEAVES_PER_SIDE * 2):
		var round0_match: BracketMatch = _bracket.rounds[0].matches[global_leaf / 2]
		if round0_match.winner == null:
			continue
		var entrant: Familiar = round0_match.entrant_a if global_leaf % 2 == 0 else round0_match.entrant_b
		if entrant == null:
			continue
		_draw_small_sprite_box(entrant, _box_rects["leaf_%d" % global_leaf], entrant != round0_match.winner)

	for round_index in range(ROUND_COUNT):
		var matches_this_round: int = _bracket.rounds[round_index].matches.size()
		for match_index in range(matches_this_round):
			var bracket_match: BracketMatch = _bracket.rounds[round_index].matches[match_index]
			var box_rect: Rect2 = _box_rects[_match_key(round_index, match_index)]
			var is_left: bool = round_index < ROUND_COUNT - 1 and match_index < matches_this_round / 2

			_draw_connector_lines(round_index, match_index, box_rect, is_left)
			_draw_connector_box(round_index, match_index, bracket_match, box_rect)

func _draw_connector_lines(round_index: int, match_index: int, box_rect: Rect2, is_left: bool) -> void:
	var child_a_rect: Rect2
	var child_b_rect: Rect2
	if round_index == 0:
		child_a_rect = _box_rects["leaf_%d" % (match_index * 2)]
		child_b_rect = _box_rects["leaf_%d" % (match_index * 2 + 1)]
	else:
		child_a_rect = _box_rects[_match_key(round_index - 1, match_index * 2)]
		child_b_rect = _box_rects[_match_key(round_index - 1, match_index * 2 + 1)]

	var line_color: Color = Palette.PLAYER_ACCENT if is_left else Palette.ENEMY_ACCENT
	if round_index == ROUND_COUNT - 1:
		# The Final is centered, fed by one connector from each side --
		# color each incoming line for the half it comes from.
		_draw_elbow(child_a_rect, box_rect, true, Palette.PLAYER_ACCENT)
		_draw_elbow(child_b_rect, box_rect, false, Palette.ENEMY_ACCENT)
		return

	_draw_elbow(child_a_rect, box_rect, is_left, line_color)
	_draw_elbow(child_b_rect, box_rect, is_left, line_color)

## One elbow connector: a horizontal stub out of the child box, a vertical
## bus halfway to the parent box, then a horizontal stub into the parent.
## child_is_left describes which side of the PARENT the child feeds from
## (true = child sits to the parent's left, so the connector runs
## left-to-right) -- not which half of the whole tree either box is in.
func _draw_elbow(child_rect: Rect2, parent_rect: Rect2, child_is_left: bool, color: Color) -> void:
	var child_x: float = child_rect.end.x if child_is_left else child_rect.position.x
	var parent_x: float = parent_rect.position.x if child_is_left else parent_rect.end.x
	var bus_x: float = (child_x + parent_x) / 2.0
	var child_y: float = child_rect.get_center().y
	var parent_y: float = parent_rect.get_center().y

	draw_line(Vector2(child_x, child_y), Vector2(bus_x, child_y), color, LINE_WIDTH)
	draw_line(Vector2(bus_x, child_y), Vector2(bus_x, parent_y), color, LINE_WIDTH)
	draw_line(Vector2(bus_x, parent_y), Vector2(parent_x, parent_y), color, LINE_WIDTH)

## True once round[round_index].matches[match_index]'s winner has ALSO had
## their next-round match decided (won or lost it) -- either way, their
## live full card has moved off this box, which should downgrade to a
## small box instead. Always false for the Final (round_index ==
## ROUND_COUNT - 1): there's no round beyond it in this tree to check.
func _connector_is_superseded(round_index: int, match_index: int) -> bool:
	if round_index == ROUND_COUNT - 1:
		return false
	var next_match: BracketMatch = _bracket.rounds[round_index + 1].matches[match_index / 2]
	return next_match.winner != null

func _connector_winner_lost_next(round_index: int, match_index: int) -> bool:
	var winner: Familiar = _bracket.rounds[round_index].matches[match_index].winner
	var next_match: BracketMatch = _bracket.rounds[round_index + 1].matches[match_index / 2]
	return next_match.winner != winner

func _draw_connector_box(round_index: int, match_index: int, bracket_match: BracketMatch, box_rect: Rect2) -> void:
	if bracket_match.winner == null:
		_draw_question_box(box_rect)
		return

	if _connector_is_superseded(round_index, match_index):
		var lost_next: bool = _connector_winner_lost_next(round_index, match_index)
		_draw_small_sprite_box(bracket_match.winner, box_rect, lost_next)
	# Otherwise this box is where _build_leaf_cards() already placed the
	# winner's live, interactive full card (see _current_slot_key()) --
	# nothing more to draw here, the Panel covers it.

func _draw_question_box(box_rect: Rect2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BOX_FILL
	style.set_border_width_all(2)
	style.border_color = Palette.PANEL_BORDER
	style.set_corner_radius_all(3)
	draw_style_box(style, box_rect)

	var font: Font = ThemeDB.fallback_font
	var text := "?"
	var font_size: int = int(box_rect.size.y * 0.6)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, box_rect.get_center() - text_size / 2.0 + Vector2(0, text_size.y * 0.35),
			text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Palette.TEXT_MUTED)

## A downgraded slot an entrant has passed through -- their own sprite
## alone, crossed out if show_x is true (they lost the match that moved
## them past this slot). box_rect is already sized correctly small by
## _compute_layout() for slots outside the active tier, so
## this draws it directly rather than centering an artificially-small box
## inside a leftover leaf-sized rect -- which is also why the elbow lines
## (drawn separately, from these same box_rects) touch its edges exactly,
## with no floating gap between an icon and the line leading to it.
func _draw_small_sprite_box(familiar: Familiar, box_rect: Rect2, show_x: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BOX_FILL
	style.set_border_width_all(2)
	style.border_color = Palette.PANEL_BORDER
	style.set_corner_radius_all(3)
	draw_style_box(style, box_rect)

	if familiar == null:
		return

	var bounds_size: float = min(box_rect.size.x, box_rect.size.y) - 8.0
	var bounds_rect := Rect2(box_rect.get_center() - Vector2.ONE * bounds_size / 2.0, Vector2.ONE * bounds_size)

	var sprite_rect: Rect2 = bounds_rect
	if familiar.sprite != null:
		sprite_rect = _fit_aspect(familiar.sprite, bounds_rect)
		draw_texture_rect(familiar.sprite, sprite_rect, false)

	if show_x:
		draw_line(sprite_rect.position, sprite_rect.end, LOSER_X_COLOR, 3.0)
		draw_line(Vector2(sprite_rect.position.x, sprite_rect.end.y), Vector2(sprite_rect.end.x, sprite_rect.position.y), LOSER_X_COLOR, 3.0)

## Fits a texture's own aspect ratio within bounds, centered and
## letterboxed if it isn't square -- draw_texture_rect() itself has no
## "keep aspect" mode (unlike TextureRect's STRETCH_KEEP_ASPECT_CENTERED),
## it always stretches to exactly fill whatever rect it's given.
func _fit_aspect(texture: Texture2D, bounds: Rect2) -> Rect2:
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return bounds
	var fit_scale: float = min(bounds.size.x / tex_size.x, bounds.size.y / tex_size.y)
	var fitted_size: Vector2 = tex_size * fit_scale
	return Rect2(bounds.get_center() - fitted_size / 2.0, fitted_size)
