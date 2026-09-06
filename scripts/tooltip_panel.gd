class_name TooltipPanel
extends PanelContainer

## One tooltip's visuals plus its own drag/close behavior once pinned.
## TooltipLayer owns *when* a panel exists and which source it belongs to;
## this script only knows how to display text and, in pinned mode, let
## itself be dragged or closed.

signal close_requested

@onready var content_label: RichTextLabel = $Content/RichTextLabel
@onready var close_button: Button = $Content/CloseButton

var pinned: bool = false

## Set by TooltipLayer right after instantiating this panel, so a hovered
## [url=...] span inside content_label can spawn its own nested tooltip
## through the same hover_started()/hover_ended() path every other source
## uses -- content_label is passed as that nested tooltip's "source".
var tooltip_layer: TooltipLayer = null

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _mouse_over: bool = false
var _hovered_meta: Variant = null

func _ready() -> void:
	close_button.pressed.connect(func() -> void: close_requested.emit())
	mouse_entered.connect(func() -> void: _mouse_over = true)
	mouse_exited.connect(func() -> void: _mouse_over = false)
	content_label.meta_hover_started.connect(_on_meta_hover_started)
	content_label.meta_hover_ended.connect(_on_meta_hover_ended)

## Resolves a hovered [url=...] meta value to a nested tooltip's text.
## Currently only status ids resolve (e.g. "[url=poison]Poison[/url]");
## anything else is silently ignored rather than showing a blank tooltip.
func _on_meta_hover_started(meta: Variant) -> void:
	if tooltip_layer == null:
		return

	var status: Status = Status.from_id(StringName(str(meta)))
	if status == null:
		return
	# See RewardCard._on_description_meta_hover_started() for why this
	# guards against a second, different link on the same label being
	# silently ignored by hover_started()'s "already showing" check.
	if _hovered_meta != null and _hovered_meta != meta:
		tooltip_layer.hover_ended(content_label)
	_hovered_meta = meta
	tooltip_layer.hover_started(content_label, status.describe())

func _on_meta_hover_ended() -> void:
	_hovered_meta = null
	if tooltip_layer != null:
		tooltip_layer.hover_ended(content_label)

## Content is a plain Control, not a Container, so it never propagates
## RichTextLabel's minimum size up to itself the way a Container would --
## without this, PanelContainer sees a 0-size direct child and the whole
## popup collapses. Width comes from RichTextLabel's authored minimum (the
## actual wrap-width cap); height has to be read fresh after the real text
## is set, since fit_content makes it grow with however many lines *this*
## text wraps into -- reading it any earlier would still reflect the
## scene's placeholder text instead.
func set_text(text: String) -> void:
	if text == content_label.text:
		return
	content_label.text = text
	var content: Control = content_label.get_parent()
	content.custom_minimum_size = Vector2(
		content_label.custom_minimum_size.x, content_label.get_minimum_size().y
	)

## Switches between a plain transient tooltip (no close button, not
## draggable) and a pinned one (close button visible, click-and-drag via
## _gui_input below).
func set_pinned(value: bool) -> void:
	pinned = value
	close_button.visible = value

func is_mouse_over() -> bool:
	return _mouse_over

func _gui_input(event: InputEvent) -> void:
	if not pinned:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = get_global_mouse_position() - global_position
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset
