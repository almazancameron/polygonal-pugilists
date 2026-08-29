extends VBoxContainer

## Subscribes to a CombatLog and renders each entry as a colored Label.
## BattleController never touches this directly -- it only calls
## CombatLog.add_entry(), which this view happens to be listening for.

@onready var combat_log: CombatLog = $"../../CombatLog"

func _ready() -> void:
	combat_log.entry_added.connect(_on_entry_added)

func _on_entry_added(text: String, source: CombatLog.Source) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = Color.WHITE if source == CombatLog.Source.PLAYER else Color(0.9, 0.3, 0.3)
	add_child(label)
