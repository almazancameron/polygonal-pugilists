class_name StatUpgradeRow
extends HBoxContainer

## One row of the stat-upgrade panel (Phase A): stat name, current value,
## an arrow, resulting value, and +/- allocation controls -- everything
## visible without hovering, per assets/ui_mockup/stat_mockup.png. Unlike
## Phase B's RewardCard, this is immediate-allocate-with-undo, not
## select-then-confirm-per-card -- the screen-level Confirm button is
## what actually commits every row's allocation at once (see
## RewardFlowController.confirm_stat_phase()).

@onready var name_label: Label = $NameLabel
@onready var current_label: Label = $CurrentLabel
@onready var resulting_label: Label = $ResultingLabel
@onready var minus_button: Button = $MinusButton
@onready var allocated_label: Label = $AllocatedLabel
@onready var plus_button: Button = $PlusButton

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
	allocated_label.text = "+%d" % _allocated_count
