class_name StateProbe
extends PanelContainer

## Mini-battle-simulator, plus a per-rule verdict for the current build.
##
## Rather than the player hand-declaring a hypothetical state, this drives
## the player's currently-edited (not yet saved) priority rules for real
## against a passive "dummy" enemy that never takes its own turn -- one
## round at a time, manually stepped or auto-played -- by reusing
## BattleEngine (scripts/battle_engine.gd), the same class the headless
## balance-test harness drives. Real resolution means Ward absorption,
## Retaliation, DoT ticks, etc. all behave exactly as they would in a real
## fight.

signal state_changed

enum Verdict { FIRES, SKIPPED, UNREACHED, INCOMPLETE }

## Hard cap on auto-Play only -- manual Step stays uncapped, since a human
## clicking it is self-limiting. Cheap insurance against a build with no
## real damage output looping forever.
const MAX_AUTO_STEPS: int = 50
const PLAY_INTERVAL: float = 0.6

## Matches the flat, cornerless StyleBoxFlat battle.tscn's own HPBar
## instances already use (Panels/PlayerPanel|EnemyPanel/HPBar) -- left null,
## HPBar falls back to the default theme's ProgressBar style, which has
## rounded corners. Fill color isn't set here: HPBar.set_hp() recolors it
## every call based on HP fraction (Palette.HP_FULL/HP_LOW).
const HP_BAR_BACKGROUND_COLOR: Color = Palette.HP_TRACK

var user: Combatant
var dummy: Combatant

## The real, undisturbed opponent -- kept only so the Reset button can
## re-derive a fresh dummy from it (discarding any custom max-HP edit),
## distinct from _dummy_familiar below which the player can freely tweak.
var _opponent_familiar: Familiar

## Private duplicates: a shallow Resource.duplicate() is safe here since
## only a single top-level field on each ever gets reassigned afterward
## (priority_rules / max_hp), never a nested resource -- see the
## fallback_attack.tres incident in DECISIONS.md for why a *shared*
## resource being mutated this way would be a real bug.
var _user_familiar: Familiar
var _dummy_familiar: Familiar

var _engine: BattleEngine

var _current_rules: Array[PriorityRule] = []
var _step_count: int = 0
var _max_hp_locked: bool = false
var _playing: bool = false

var _tooltip_layer: TooltipLayer
var _play_timer: Timer

var _user_hp_bar: HPBar
var _user_status_row: StatusRow
var _dummy_hp_bar: HPBar
var _dummy_status_row: StatusRow
var _dummy_max_hp_spin: SpinBox
var _prev_button: Button
var _play_button: Button
var _reset_button: Button
var _next_button: Button

var _verdicts: Dictionary = {}
var _mismatch: String = ""
var _no_match: String = ""

func _ready() -> void:
	_play_timer = Timer.new()
	_play_timer.wait_time = PLAY_INTERVAL
	_play_timer.timeout.connect(_on_play_tick)
	add_child(_play_timer)

func setup(builder: Familiar, opponent: Familiar) -> void:
	_opponent_familiar = opponent
	_user_familiar = builder.duplicate()
	_dummy_familiar = opponent.duplicate()
	reset_simulation(builder.priority_rules)

## Restarts the fight from full HP/no statuses using whatever `rules` is
## currently compiled. Called on every build edit (preserving any custom
## dummy max HP already dialed in, since editing a rotation shouldn't
## silently discard a "what if this enemy had 200 HP" test setup) and
## internally by setup() / _on_reset_pressed() (which re-derives a fresh
## _dummy_familiar first, for a full default-state reset).
func reset_simulation(rules: Array[PriorityRule]) -> void:
	_play_timer.stop()
	_playing = false
	_step_count = 0
	_max_hp_locked = false
	_current_rules = rules

	_user_familiar.priority_rules = rules
	user = Combatant.new(_user_familiar)
	dummy = Combatant.new(_dummy_familiar)
	# _matching_passives() reads self.opponent directly (for trigger_target ==
	# TARGET matching, and for every passive's conditions -- e.g. "if user's
	# HP < 50%, gain X" -- regardless of trigger_target), so passives silently
	# never match without this, same as the real battle_controller.gd/
	# BattleEngine callers always wire it.
	user.opponent = dummy
	dummy.opponent = user
	_engine = BattleEngine.new(user, dummy)
	_engine.begin_battle()

	_refresh_display()
	_sync_buttons()
	state_changed.emit()

## One playback round: the player's turn (per-turn passive limits reset,
## TURN_START, choose_technique()+execute against dummy, TURN_END -- all via
## BattleEngine.take_turn(), which also fires dummy's own reactive passives
## like Ward/Retaliation, since those hooks live in the hit-resolution path
## itself, not in whoever's "turn" it technically is) followed by upkeep for
## both sides, so DoT/self-sustain still ticks every round even though
## dummy never acts on its own.
func advance_step() -> void:
	if is_over():
		return

	_step_count += 1
	_max_hp_locked = true

	user.reset_turn_passive_limits()
	_engine.take_turn(user, dummy)
	_engine.run_upkeep(user)
	_engine.run_upkeep(dummy)

	_refresh_display()
	_sync_buttons()
	state_changed.emit()

	if is_over():
		_playing = false
		_play_timer.stop()

func is_over() -> bool:
	return user.is_defeated() or dummy.is_defeated()

func _on_play_tick() -> void:
	advance_step()
	if is_over() or _step_count >= MAX_AUTO_STEPS:
		_playing = false
		_play_timer.stop()
		_sync_buttons()

func _on_next_pressed() -> void:
	advance_step()

## Replays from scratch up to _step_count - 1 -- simpler and more robust
## than maintaining a parallel undo/snapshot stack, since advance_step() is
## already cheap and the sim is deterministic for any build that doesn't
## itself rely on Array.pick_random() (Cleanse and similar; see DECISIONS.md
## on that one known non-determinism). Replaying back to step 0 correctly
## re-enables the dummy max-HP spinbox too, for free -- _max_hp_locked only
## ever gets set true by advance_step(), never independently.
func _on_prev_pressed() -> void:
	if _step_count <= 0:
		return

	var target: int = _step_count - 1
	reset_simulation(_current_rules)
	for i in target:
		advance_step()

func _on_play_pressed() -> void:
	if is_over():
		return

	_playing = not _playing
	if _playing:
		_play_timer.start()
	else:
		_play_timer.stop()
	_sync_buttons()

## An explicit "back to the default preview state" request -- unlike the
## lighter build-edit auto-reset, this also re-derives _dummy_familiar from
## the real opponent, discarding any custom max-HP edit.
func _on_reset_pressed() -> void:
	_dummy_familiar = _opponent_familiar.duplicate()
	reset_simulation(_current_rules)

## Only reachable pre-lock, since the control itself is disabled once
## _max_hp_locked -- dummy is always still full-health at this point, so
## snapping current_hp to match is exactly correct.
func _on_dummy_max_hp_changed(value: float) -> void:
	_dummy_familiar.max_hp = int(value)
	dummy.current_hp = int(value)
	_refresh_display()

## Walks the compiled rules against the current simulated state and records
## a verdict per segment.
##
## The walk is restated here rather than read out of choose_technique(),
## which returns skip_reasons as a flat Array[String] -- badging rule i from
## skip_reasons[i] would couple this UI to that loop's internal append
## order. Only the loop is restated; the primitive that matters,
## condition.is_met(), is the real one. _cross_check() is what keeps the
## restatement from drifting away from the evaluator combat actually uses.
func evaluate(compiled: Dictionary) -> void:
	_verdicts.clear()
	_mismatch = ""
	_no_match = ""

	var rules: Array[PriorityRule] = compiled["rules"]
	var segments: Array[RuleSegment] = compiled["segments"]

	for segment in compiled["incomplete"]:
		_verdicts[segment] = Verdict.INCOMPLETE
		segment.set_verdict("⚠ incomplete", _incomplete_reason(segment))

	var winner: int = -1

	for i in rules.size():
		var segment: RuleSegment = segments[i]

		if winner != -1:
			_verdicts[segment] = Verdict.UNREACHED
			segment.set_verdict("– unreached", "an earlier rule fired")
			continue

		var failed: Condition = null
		for condition in rules[i].conditions:
			if not condition.is_met(user, dummy):
				failed = condition
				break

		if failed == null:
			winner = i
			_verdicts[segment] = Verdict.FIRES
			segment.set_verdict("✓ FIRES", rules[i].technique.technique_name)
		else:
			_verdicts[segment] = Verdict.SKIPPED
			segment.set_verdict("✗ skipped", failed.describe())

	if winner == -1:
		_no_match = "No rule matched — add a slot with a technique and no conditions."

	_cross_check(rules, winner)

## Runs the real evaluator on the same compiled list and compares winners.
## Cheap insurance that evaluate()'s restated loop still agrees with
## Combatant.choose_technique(). Normally silent.
func _cross_check(rules: Array[PriorityRule], winner: int) -> void:
	var probe_familiar := Familiar.new()
	probe_familiar.familiar_name = user.familiar.familiar_name
	probe_familiar.max_hp = user.familiar.max_hp
	probe_familiar.power = user.familiar.power
	probe_familiar.defense = user.familiar.defense
	probe_familiar.speed = user.familiar.speed
	probe_familiar.focus = user.familiar.focus
	probe_familiar.priority_rules = rules

	var shadow := Combatant.new(probe_familiar)
	shadow.current_hp = user.current_hp
	shadow.statuses = user.statuses

	var decision: Dictionary = shadow.choose_technique(dummy)
	var expected: Technique = rules[winner].technique if winner != -1 else null

	if decision["technique"] != expected:
		var got: String = decision["technique"].technique_name if decision["technique"] != null else "none"
		var want: String = expected.technique_name if expected != null else "none"
		_mismatch = "probe says %s, choose_technique() says %s" % [want, got]

func _incomplete_reason(segment: RuleSegment) -> String:
	if segment.is_empty():
		return "empty slot"

	var holder: TechniqueBlock = segment.technique_block()
	if holder == null or holder.technique == null:
		return "no technique"

	return "a NOT block has an empty body"

func verdict_for(segment: RuleSegment) -> Verdict:
	return _verdicts.get(segment, Verdict.INCOMPLETE)

func mismatch_message() -> String:
	return _mismatch

func no_match_message() -> String:
	return _no_match

## Builds the player/dummy rows and playback controls. The probe owns the
## combatants but not its own layout, so PriorityBuilder hands it a
## container to fill. Clears first: each row's controls close over the
## specific Combatant instances live when this runs, so a re-setup() with
## fresh Combatants needs fresh rows too, not just a second set appended
## alongside ones still pointing at now-orphaned Combatants.
func build_controls(into: VBoxContainer, tooltip_layer: TooltipLayer) -> void:
	_tooltip_layer = tooltip_layer

	for child in into.get_children():
		into.remove_child(child)
		child.queue_free()

	_user_hp_bar = null
	_user_status_row = null
	_dummy_hp_bar = null
	_dummy_status_row = null
	_dummy_max_hp_spin = null

	_build_side_display(into, "You", false)
	_build_side_display(into, "Dummy", true)
	_build_playback_controls(into)

	_refresh_display()
	_sync_buttons()

## editable_max_hp is only ever true for the dummy row -- the player's own
## HP is whatever their real Familiar's max_hp already is, never a knob to
## fake, since the player IS the real content being tested.
func _build_side_display(into: VBoxContainer, label_text: String, editable_max_hp: bool) -> void:
	var name_row := HBoxContainer.new()
	into.add_child(name_row)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)

	if editable_max_hp:
		var max_hp_spin := SpinBox.new()
		max_hp_spin.min_value = 1
		max_hp_spin.max_value = 999
		max_hp_spin.custom_minimum_size = Vector2(72, 0)
		max_hp_spin.value = _dummy_familiar.max_hp
		max_hp_spin.value_changed.connect(_on_dummy_max_hp_changed)
		name_row.add_child(max_hp_spin)
		_dummy_max_hp_spin = max_hp_spin

	var hp_bar: HPBar = preload("res://scenes/hp_bar.tscn").instantiate()
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = HP_BAR_BACKGROUND_COLOR
	hp_bar.bar_background_style = background_style
	into.add_child(hp_bar)

	var status_row: StatusRow = preload("res://scenes/status_row.tscn").instantiate()
	status_row.tooltip_layer = _tooltip_layer
	into.add_child(status_row)

	if editable_max_hp:
		_dummy_hp_bar = hp_bar
		_dummy_status_row = status_row
	else:
		_user_hp_bar = hp_bar
		_user_status_row = status_row

## Media-player-style cluster: rewind/next flank Play/Reset in the middle.
func _build_playback_controls(into: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	into.add_child(row)

	_prev_button = Button.new()
	_prev_button.text = "Previous Step"
	_prev_button.pressed.connect(_on_prev_pressed)
	row.add_child(_prev_button)

	_play_button = Button.new()
	_play_button.text = "Play"
	_play_button.pressed.connect(_on_play_pressed)
	row.add_child(_play_button)

	_reset_button = Button.new()
	_reset_button.text = "Reset"
	_reset_button.pressed.connect(_on_reset_pressed)
	row.add_child(_reset_button)

	_next_button = Button.new()
	_next_button.text = "Next Step"
	_next_button.pressed.connect(_on_next_pressed)
	row.add_child(_next_button)

## Translates each Combatant's active statuses into the plain
## {id,color,stacks,damage,icon,description} shape HPBar/StatusRow know how
## to draw -- mirrors battle_controller.gd's refresh_status_preview()
## exactly (that copy is private to battle_controller.gd's own onready
## nodes, so this is a small, deliberate duplication rather than a shared
## helper).
func _refresh_display() -> void:
	if _user_hp_bar == null:
		return

	_update_side_display(user, _user_hp_bar, _user_status_row)
	_update_side_display(dummy, _dummy_hp_bar, _dummy_status_row)

	if _dummy_max_hp_spin != null:
		_dummy_max_hp_spin.editable = not _max_hp_locked

func _update_side_display(combatant: Combatant, hp_bar: HPBar, status_row: StatusRow) -> void:
	hp_bar.set_hp(combatant.current_hp, combatant.familiar.max_hp)

	var segments: Array[Dictionary] = []
	for status in combatant.statuses:
		var damage: int = status.next_tick_damage()
		var stacks: int = status.stacks
		if stacks > 0:
			segments.append({"id": status.status_id(), "color": status.preview_color(), "stacks": stacks, "damage": damage, "icon": status.icon(), "description": status.describe()})

	hp_bar.set_status_preview_segments(segments)
	status_row.set_status_icons(segments)

func _sync_buttons() -> void:
	if _next_button == null:
		return

	var over: bool = is_over()
	# Previous stays enabled even once the fight is over, so a defeated
	# playback can still be rewound to inspect the state just before it --
	# only Play/Next actually need the fight to still be undecided.
	_prev_button.disabled = _playing or _step_count <= 0
	_next_button.disabled = over or _playing
	_play_button.disabled = over
	_play_button.text = "Pause" if _playing else "Play"
