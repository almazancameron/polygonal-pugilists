class_name StatUpgradeRow
extends PanelContainer

## One row of the stat-upgrade panel (Phase A): icon, stat name, current
## value, an arrow, resulting value, and +/- allocation controls --
## everything visible without hovering, per assets/ui_mockup/stat_mockup.png.
## Unlike Phase B's RewardCard, this is immediate-allocate-with-undo, not
## select-then-confirm-per-card -- the screen-level Confirm button is
## what actually commits every row's allocation at once (see
## RewardFlowController.confirm_stat_phase()). The mockup highlights
## whichever single stat is chosen; since this row's own mechanic lets a
## point land on more than one stat, "highlighted" here means "has at
## least one point allocated right now" instead.

@onready var icon_rect: TextureRect = $Row/Icon
@onready var name_label: Label = $Row/NameLabel
@onready var current_label: Label = $Row/CurrentLabel
@onready var resulting_label: Label = $Row/ResultingLabel
@onready var minus_button: Button = $Row/MinusButton
@onready var allocated_label: Label = $Row/AllocatedLabel
@onready var plus_button: Button = $Row/PlusButton

var upgrade: ModifyStatUpgrade
var current_value: int = 0
var _allocated_count: int = 0

## Emitted with (stat, delta) when +/- is pressed -- the owning screen
## calls RewardFlowController.try_allocate() and, on success, calls
## refresh_availability()/re-renders every row (a + here can gray out
## every other row's + button too).
signal allocate_requested(stat: Familiar.Stat, delta: int)

func setup(stat_upgrade: ModifyStatUpgrade, starting_value: int) -> void:
	upgrade = stat_upgrade
	current_value = starting_value
	_allocated_count = 0

	icon_rect.texture = Familiar.stat_icon(upgrade.stat)
	name_label.text = Familiar.stat_name(upgrade.stat)
	minus_button.pressed.connect(func() -> void: allocate_requested.emit(upgrade.stat, -1))
	plus_button.pressed.connect(func() -> void: allocate_requested.emit(upgrade.stat, 1))

	_update_display()

## Called after a successful allocate on THIS row.
func set_allocated_count(count: int) -> void:
	_allocated_count = count
	_update_display()

## Called on every row whenever the shared available_points pool changes,
## even rows whose own allocation didn't change -- one stat's + can gray
## out every other row's + button.
func refresh_availability(points_remaining: int) -> void:
	plus_button.disabled = points_remaining <= 0
	minus_button.disabled = _allocated_count <= 0

func _update_display() -> void:
	current_label.text = str(current_value)
	resulting_label.text = str(current_value + upgrade.bonus * _allocated_count)
	allocated_label.text = "✚%d" % _allocated_count
	allocated_label.add_theme_color_override(
		"font_color", Palette.GOLD_ACCENT if _allocated_count > 0 else Palette.TEXT_MUTED
	)
	_update_style()

func _update_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.BACKGROUND
	style.border_color = Palette.GOLD_ACCENT if _allocated_count > 0 else Palette.PANEL_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(2)
	add_theme_stylebox_override("panel", style)
