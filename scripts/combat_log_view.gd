extends VBoxContainer

## Subscribes to a CombatLog and renders each entry as a colored Label.
## BattleController never touches this directly -- it only calls
## CombatLog.add_entry(), which this view happens to be listening for.

@onready var combat_log: CombatLog = $"../../CombatLog"
@onready var scroll_container: ScrollContainer = get_parent() as ScrollContainer

func _ready() -> void:
	combat_log.entry_added.connect(_on_entry_added)
	scroll_container.get_v_scroll_bar().changed.connect(_scroll_to_bottom)

func _on_entry_added(text: String, source: CombatLog.Source) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = Color.WHITE if source == CombatLog.Source.PLAYER else Color(0.9, 0.3, 0.3)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)

func _scroll_to_bottom() -> void:
	scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)