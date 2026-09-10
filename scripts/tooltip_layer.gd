class_name TooltipLayer
extends Control

## Replaces Godot's built-in per-Control tooltip (tooltip_text) with a
## hand-rolled one, since the built-in popup's show/hide/reposition timing
## is owned entirely by the Viewport and can't be paused or persisted.
## Other controls call hover_started()/hover_ended() from their own
## mouse_entered/mouse_exited instead of setting tooltip_text -- and so
## does TooltipPanel itself, forwarding a RichTextLabel's meta_hover
## signals the same way, which is what makes nested tooltips (hovering a
## linked term inside another tooltip's text) work without a separate
## system.
##
## Three tooltip states a source can be in:
## - active (unpinned): shown after a short hover delay, hidden on exit.
##   Tracked in a list rather than a single slot because a nested tooltip
##   has to stay alive *alongside* its parent, not replace it.
## - shift-pinned: an active tooltip kept visible past hover-exit because
##   Shift was held when the mouse left; released on Shift-up.
## - alt-pinned: promoted via Alt into its own persistent, draggable,
##   closable TooltipPanel, tracked independently per source so several can
##   be open at once.

const TOOLTIP_PANEL_SCENE: PackedScene = preload("res://scenes/tooltip_panel.tscn")
const HOVER_DELAY: float = 0.2
const CURSOR_OFFSET: Vector2 = Vector2(20, 20)

## How far the cursor can drift from where a RichTextLabel link's hover
## began before _catch_exited_active_tooltips() treats it as "left the
## link", used only as a fallback for a source whose own meta_hover_ended
## isn't firing (see that function's comment). Tuned down from an initial
## 90.0 (calibrated against the longest single-word status names, e.g.
## Regeneration/Retaliation/Infestation) after live feedback that 90 felt
## too loose -- the cursor doesn't need to physically leave the link's
## rendered word before the tooltip should give up.
const LINK_DRIFT_TOLERANCE: float = 50.0

var _hover_timer: Timer

var _pending_source: Control = null
var _pending_text: String = ""
var _pending_anchor: Vector2 = Vector2.ZERO

## Each entry: {source: Control, panel: TooltipPanel, shift_pinned: bool,
## anchor: Vector2 (cursor position when this hover began)}.
var _active_tooltips: Array[Dictionary] = []

var _currently_hovered_source: Control = null

## TooltipPanel -> source Control (the source may since have been freed --
## always check is_instance_valid on it before use). Keyed by panel, not by
## source: the panel's lifecycle is fully owned by this script, but a
## status icon's source Control can be freed by StatusRow whenever its
## status expires (e.g. right after a combatant is defeated). A Dictionary
## keyed by an Object that later gets freed can no longer be matched by
## that same reference -- .get()/.has()/.erase() all silently fail to find
## the entry -- which permanently orphaned pinned tooltips whose source
## died, with no way to close them.
var _pinned_panels: Dictionary = {}

func _ready() -> void:
	_hover_timer = Timer.new()
	_hover_timer.one_shot = true
	_hover_timer.wait_time = HOVER_DELAY
	_hover_timer.timeout.connect(_show_pending_tooltip)
	add_child(_hover_timer)

func _process(delta: float) -> void:
	_catch_exited_active_tooltips()

	# array of { panel, source }
	var panel_source_array: Array[Dictionary] = []

	for panel in _pinned_panels.keys():
		panel_source_array.append({"panel": panel, "source": _pinned_panels[panel]})

	for tooltip in _active_tooltips:
		panel_source_array.append({"panel": tooltip["panel"], "source": tooltip["source"]})

	if panel_source_array.size() == 0:
		return

	for panel_dict in panel_source_array:
		var panel = panel_dict["panel"]
		var source = panel_dict["source"]

		if is_instance_valid(source):
			if source.has_meta("tooltip_text"):
				panel.set_text(source.get_meta("tooltip_text"))

## Safety net for a RichTextLabel source whose meta_hover_ended can't be
## trusted to fire on its own (confirmed live for a link nested this deep
## -- RewardCard's Button/ButtonGroup/VBoxContainer chain -- vs.
## TooltipPanel's plain PanelContainer/Control, where it's fine). Traced
## this into Godot's own source: RichTextLabel's meta-hover recompute
## (rich_text_label.cpp's gui_input) and Godot's own control-hit-test
## dispatch (viewport.cpp's gui_find_control/_gui_call_input) are both
## unconditional and Button-nesting-agnostic, so in theory this shouldn't
## be reachable at all -- but live testing (both here and by hand) shows
## it reliably is, so this compensates for it rather than trusting it'll
## get fixed upstream.
##
## Two checks, from coarsest to (approximately) finest:
## - Left the control's rect entirely: unambiguous, always correct --
##   leaving the control necessarily means leaving whatever link is
##   inside it too.
## - For a RichTextLabel source specifically, drifted more than
##   LINK_DRIFT_TOLERANCE from where this hover began: a heuristic
##   stand-in for "left the link" when still within the same control,
##   since there's no public API to hit-test a specific link's glyphs
##   directly. Approximate by construction -- lingering within a long
##   link's own glyphs could false-positive, and a very short hop to
##   adjacent plain text could false-negative -- but it's closer to
##   link-scoped than "only the whole label" was.
## Both routed through hover_ended() (not a raw removal) so shift-pinning
## is honored exactly as it would be from a real mouse-exit.
func _catch_exited_active_tooltips() -> void:
	var cursor: Vector2 = get_global_mouse_position()
	for entry in _active_tooltips.duplicate():
		if entry["shift_pinned"]:
			continue
		var source = entry["source"]
		if not is_instance_valid(source):
			continue
		if not source.get_global_rect().has_point(cursor):
			hover_ended(source)
		elif source is RichTextLabel and cursor.distance_to(entry["anchor"]) > LINK_DRIFT_TOLERANCE:
			hover_ended(source)

## Call from a source Control's mouse_entered handler (or, for a nested
## tooltip, from TooltipPanel forwarding its RichTextLabel's
## meta_hover_started).
func hover_started(source: Control, text: String) -> void:
	_currently_hovered_source = source

	if _find_panel_for_source(source) != null:
		return  # already has its own pinned panel -- don't also show one

	if _find_active(source) != -1:
		return  # already showing

	_pending_source = source
	_pending_text = text
	_pending_anchor = get_global_mouse_position()
	_hover_timer.start()

## Call from a source Control's mouse_exited handler (or TooltipPanel
## forwarding meta_hover_ended).
func hover_ended(source: Control) -> void:
	if _currently_hovered_source == source:
		_currently_hovered_source = null

	if _pending_source == source:
		_pending_source = null
		_hover_timer.stop()

	var index: int = _find_active(source)
	if index == -1:
		return

	if Input.is_key_pressed(KEY_SHIFT):
		_active_tooltips[index]["shift_pinned"] = true
	else:
		_remove_active(index)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ALT and event.pressed and not event.echo:
		_on_alt_pressed()
	elif event is InputEventKey and event.keycode == KEY_SHIFT and not event.pressed:
		_on_shift_released()

func _show_pending_tooltip() -> void:
	if _pending_source == null or not is_instance_valid(_pending_source):
		return

	var source: Control = _pending_source
	var text: String = _pending_text
	var anchor: Vector2 = _pending_anchor
	_pending_source = null

	var panel: TooltipPanel = TOOLTIP_PANEL_SCENE.instantiate()
	panel.visible = false  # stays hidden until positioned, so it can't flash at (0, 0)
	add_child(panel)
	panel.tooltip_layer = self
	panel.set_text(text)
	panel.set_pinned(false)
	panel.close_requested.connect(_on_active_close_requested.bind(panel))

	_active_tooltips.append({"source": source, "panel": panel, "shift_pinned": false, "anchor": anchor})

	# Allow wrapped content sizing to update before positioning from the
	# panel's combined minimum size for the edge-of-screen check.
	await get_tree().process_frame
	if is_instance_valid(panel):
		_position_near_cursor(panel, get_global_mouse_position())
		panel.visible = true

## Anchors the panel near `anchor` (the cursor position for a normal hover,
## or wherever the mouse is over a nested link), flipping to the opposite
## side on whichever axis would otherwise push it past the screen edge.
##
## Deliberately reads panel.get_combined_minimum_size() rather than
## panel.size: the latter is a cached rect that only updates once Godot's
## own deferred container layout pass actually runs, which one
## process_frame await isn't reliably enough time for -- reading it here
## could still see the panel's pre-resize (smaller, often placeholder)
## size, under-clamping and letting the *later*, properly-resized panel
## overflow past whichever edge it was placed near. get_combined_
## minimum_size() recomputes on demand (see TooltipPanel.set_text(),
## which already relies on the same on-demand guarantee for content_label's
## own minimum size), so it's accurate immediately, no extra frame needed.
func _position_near_cursor(panel: Control, anchor: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size: Vector2 = panel.get_combined_minimum_size()

	var pos: Vector2 = anchor + CURSOR_OFFSET
	if pos.x + panel_size.x > viewport_size.x:
		pos.x = anchor.x - CURSOR_OFFSET.x - panel_size.x
	if pos.y + panel_size.y > viewport_size.y:
		pos.y = anchor.y - CURSOR_OFFSET.y - panel_size.y

	pos.x = clampf(pos.x, 0, maxf(viewport_size.x - panel_size.x, 0))
	pos.y = clampf(pos.y, 0, maxf(viewport_size.y - panel_size.y, 0))

	panel.global_position = pos

func _on_active_close_requested(panel: TooltipPanel) -> void:
	var index: int = _find_active_by_panel(panel)
	if index != -1:
		_remove_active(index)

func _remove_active(index: int) -> void:
	var entry: Dictionary = _active_tooltips[index]
	_active_tooltips.remove_at(index)
	# Same is_instance_valid-before-typed-assignment ordering as
	# _on_shift_released() -- see its comment for why the order matters.
	if is_instance_valid(entry["panel"]):
		var panel: TooltipPanel = entry["panel"]
		# Children are identified by their source living inside this panel, so
		# they have to be closed while it is still valid -- hence before
		# queue_free(), not after.
		_close_nested(panel)
		panel.queue_free()

## Closes any active tooltip that was spawned from inside `panel`.
##
## A nested tooltip's source is its parent panel's RichTextLabel (see
## TooltipPanel._on_meta_hover_started), so once the parent is freed nothing
## will ever call hover_ended() for the child -- it has no live source left to
## exit from. Without this, closing a parent before its child left the child
## stranded on screen permanently.
##
## Alt-pinned children are deliberately spared: they live in _pinned_panels
## rather than _active_tooltips, so this loop never sees them, and promoting
## one via Alt is an explicit request for it to outlive its parent.
## Shift-pinned children are *not* spared -- shift only defers a hover-exit,
## it isn't a lock.
##
## Entries are looked up by panel identity rather than by cached index,
## because the recursive _remove_active() below mutates _active_tooltips
## underneath this loop (a grandchild can sit at a lower index than its
## parent).
func _close_nested(panel: TooltipPanel) -> void:
	if not is_instance_valid(panel):
		return

	var doomed: Array[TooltipPanel] = []
	for entry in _active_tooltips:
		# Both halves can already be freed -- check before any typed
		# assignment, same reasoning as _on_shift_released().
		if not is_instance_valid(entry["source"]) or not is_instance_valid(entry["panel"]):
			continue
		var source: Control = entry["source"]
		if panel.is_ancestor_of(source):
			doomed.append(entry["panel"])

	for child_panel in doomed:
		var index: int = _find_active_by_panel(child_panel)
		if index != -1:
			_remove_active(index)

func _find_active(source: Control) -> int:
	for i in _active_tooltips.size():
		if _active_tooltips[i]["source"] == source:
			return i
	return -1

func _find_active_by_panel(panel: TooltipPanel) -> int:
	for i in _active_tooltips.size():
		if _active_tooltips[i]["panel"] == panel:
			return i
	return -1

func _on_shift_released() -> void:
	# Walk backwards so remove_at() during the loop can't skip an entry.
	for i in range(_active_tooltips.size() - 1, -1, -1):
		var entry: Dictionary = _active_tooltips[i]
		if not entry["shift_pinned"]:
			continue

		entry["shift_pinned"] = false

		# is_instance_valid() has to run on the raw dictionary value here --
		# assigning a freed Object reference into a typed `Control` variable
		# throws "Trying to assign invalid previously freed instance"
		# immediately, before any validity check on it can even run. This is
		# what crashed the game: a status icon's source Control gets freed
		# by StatusRow on a round transition, and releasing Shift afterward
		# hit this exact assign-then-check ordering.
		var still_hovering: bool = false
		if is_instance_valid(entry["source"]):
			var source: Control = entry["source"]
			still_hovering = source.get_global_rect().has_point(get_global_mouse_position())

		if not still_hovering:
			_remove_active(i)

func _on_alt_pressed() -> void:
	# Hovering an already-pinned panel directly closes it.
	for panel in _pinned_panels.keys():
		if is_instance_valid(panel) and panel.is_mouse_over():
			_remove_pinned(panel)
			return

	# _currently_hovered_source is only ever assigned from a live signal
	# parameter (see hover_started()), so it's virtually always valid here
	# -- but check before doing anything typed with it anyway, on the same
	# principle as _on_shift_released(), rather than trust that invariant
	# forever.
	if not is_instance_valid(_currently_hovered_source):
		_currently_hovered_source = null
		return

	# Hovering the original source of an already-pinned panel closes it too.
	var existing: TooltipPanel = _find_panel_for_source(_currently_hovered_source)
	if existing != null:
		_remove_pinned(existing)
		return

	# Otherwise, promote whichever active tooltip's source is currently
	# hovered -- the outer one, or a nested one if the mouse is over its
	# own linked span -- into a pinned, draggable panel.
	var index: int = _find_active(_currently_hovered_source)
	if index == -1:
		return

	var entry: Dictionary = _active_tooltips[index]
	_active_tooltips.remove_at(index)

	var source: Control = _currently_hovered_source  # already validated above
	var panel: TooltipPanel = entry["panel"]

	panel.set_pinned(true)
	panel.close_requested.disconnect(_on_active_close_requested.bind(panel))
	panel.close_requested.connect(_on_pinned_panel_close_requested.bind(panel))
	_pinned_panels[panel] = source

func _on_pinned_panel_close_requested(panel: TooltipPanel) -> void:
	_remove_pinned(panel)

func _remove_pinned(panel: TooltipPanel) -> void:
	_pinned_panels.erase(panel)
	if is_instance_valid(panel):
		# Closing an alt-pinned parent takes its un-pinned children with it,
		# for the same reason as _remove_active().
		_close_nested(panel)
		panel.queue_free()

## Linear scan by value rather than a dictionary key lookup, since sources
## are the (potentially freed) *values* here, not the keys -- see
## _pinned_panels' own comment for why keying by source was the bug.
func _find_panel_for_source(source: Control) -> TooltipPanel:
	for panel in _pinned_panels.keys():
		if _pinned_panels[panel] == source:
			return panel
	return null
