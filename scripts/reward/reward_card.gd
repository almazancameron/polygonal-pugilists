class_name RewardCard
extends Button

## One of the 3 reward-screen offers. toggle_mode + a shared ButtonGroup
## (wired in battle_controller.gd) give "select exactly one of three" for
## free -- the interaction Phase B needs (select, don't apply, confirm
## separately), which nothing else in this codebase needed before.
##
## Wider than palette_block.tscn's single-Label card on purpose: title +
## icon placeholder + description are all shown on-card (per
## assets/ui_mockup/reward_mockup.png). No card-level tooltip -- the full
## description is already visible on the card itself. description_label
## is a RichTextLabel (not a plain Label) specifically so the
## [url=...]-wrapped status names describe() produces (see
## Status.status_link()) render as real links and resolve into nested
## status tooltips on hover, the same way TooltipPanel's own content
## already does -- see _on_description_meta_hover_started() below,
## mirroring tooltip_panel.gd's _on_meta_hover_started() exactly.

@onready var content: Control = $Content
@onready var title_label: Label = $Content/TitleLabel
@onready var icon_area: ColorRect = $Content/IconArea
@onready var description_label: RichTextLabel = $Content/DescriptionLabel

var option: UpgradeOption
var _tooltip_layer: TooltipLayer
var _hovered_meta: Variant = null

## The shared Theme's default hover/pressed borders are both a gold close
## enough to Palette.GOLD_ACCENT to blend into this card's own gold-bordered
## column frame (SpeciesColumn/RunColumn/PivotColumn) -- hovering a card was
## barely distinguishable from the frame around it. Overridden per-instance
## to Palette.PLAYER_ACCENT instead, on both "hover" and "pressed" (a
## toggle_mode Button shows "pressed" continuously while selected, not just
## while the mouse is held down, so this is also what keeps a chosen card
## highlighted after the click ends).
func _ready() -> void:
	# Same bg_color as the shared Theme's own StyleBoxFlat for each state
	# (pixel_pugilists.tres) -- only border_color changes here.
	var bg_colors := {
		"hover": Color(0.11, 0.13, 0.16, 1),
		"focus": Color(0.11, 0.13, 0.16, 1),
		"pressed": Color(0.16, 0.18, 0.22, 1),
	}
	for style_name in bg_colors:
		var style := StyleBoxFlat.new()
		style.bg_color = bg_colors[style_name]
		style.border_color = Palette.PLAYER_ACCENT
		style.set_border_width_all(2)
		style.set_content_margin_all(6)
		style.set_corner_radius_all(2)
		add_theme_stylebox_override(style_name, style)

func setup(upgrade_option: UpgradeOption, tooltip_layer: TooltipLayer) -> void:
	option = upgrade_option
	_tooltip_layer = tooltip_layer

	title_label.text = option.label
	# No per-reward icon exists yet (UpgradeOption carries no icon data) --
	# hide the placeholder rather than show an empty gray box. The node
	# stays in the scene so a future icon pass has a slot ready to fill in.
	icon_area.visible = false
	description_label.text = option.describe()

	if not description_label.meta_hover_started.is_connected(_on_description_meta_hover_started):
		description_label.meta_hover_started.connect(_on_description_meta_hover_started)
	if not description_label.meta_hover_ended.is_connected(_on_description_meta_hover_ended):
		description_label.meta_hover_ended.connect(_on_description_meta_hover_ended)

	_resize_to_content()

## Resolves a hovered [url=...] span (e.g. "[url=poison]Poison[/url]")
## to its status's own describe() text, exactly like
## tooltip_panel.gd's _on_meta_hover_started() -- description_label is
## passed as the nested tooltip's "source", same role TooltipPanel's own
## content_label plays for its nested tooltips.
func _on_description_meta_hover_started(meta: Variant) -> void:
	if _tooltip_layer == null:
		return
	var status: Status = Status.from_id(StringName(str(meta)))
	if status == null:
		return
	# hover_started() no-ops while description_label already has a
	# tooltip showing (TooltipLayer.hover_started's "already showing"
	# guard, keyed by description_label itself, not by which link). A
	# card can reference the same status more than once (e.g. Stoke's 3
	# separate Burn links) -- without ending the old one first, hovering
	# a second, different link on the same card would leave the first
	# link's stale text and stale screen position stuck on top.
	if _hovered_meta != null and _hovered_meta != meta:
		_tooltip_layer.hover_ended(description_label)
	_hovered_meta = meta
	_tooltip_layer.hover_started(description_label, status.describe())

func _on_description_meta_hover_ended() -> void:
	_hovered_meta = null
	if _tooltip_layer != null:
		_tooltip_layer.hover_ended(description_label)

## RewardCard's own Button never asks its children how much space they
## need -- that's a Container thing, and Button (like any plain Control)
## doesn't propagate a child's minimum size upward. Without this, a long
## describe() just overflows past the card's fixed rect into whatever
## sits below it (the Reroll button, the next row down). One frame's
## wait is needed for the description's fit_content height to have
## actually settled against Content's real, already-laid-out width --
## querying it on the same frame setup() runs would see a stale/zero
## width instead.
func _resize_to_content() -> void:
	await get_tree().process_frame
	custom_minimum_size.y = max(custom_minimum_size.y, content.get_combined_minimum_size().y)
	_resync_hover_under_cursor()

## This resize just moved description_label's wrapped-text layout, which
## can shift a [url=...] status link out from under a mouse that never
## actually moved. Godot only recomputes a RichTextLabel's per-link hover
## state (meta_hover_started/ended) in response to a real mouse-motion
## event, so a layout change with no motion leaves it stale -- e.g. a
## status link the mouse started on can keep reporting hovered after the
## text reflows out from under it, or the reverse. Pushing a synthetic
## motion event at the cursor's current position forces Godot to redo
## that hit-test against the new layout, through the same native,
## per-link-precise mechanism a real mouse move would use -- rather than
## polling gui_get_hovered_control() every frame, which can only ever
## tell "is the mouse over this control at all", not "is it over the
## link", and would make every hover in this card as coarse as the whole
## description block.
func _resync_hover_under_cursor() -> void:
	if not is_instance_valid(description_label):
		return
	var viewport: Viewport = description_label.get_viewport()
	var refresh: InputEventMouseMotion = InputEventMouseMotion.new()
	refresh.position = viewport.get_mouse_position()
	refresh.global_position = refresh.position
	viewport.push_input(refresh)
