class_name CombatLogView
extends VBoxContainer

## Subscribes to a CombatLog and renders each entry as a colored Label.
## BattleController never touches this directly -- it only calls
## CombatLog.add_entry(), which this view happens to be listening for.

@onready var combat_log: CombatLog = $"../../CombatLog"
@onready var scroll_container: ScrollContainer = get_parent() as ScrollContainer

## Set once by battle_controller.gd when each side's familiar is known, so
## entries can highlight a combatant's own name in their accent color --
## every other word in the line stays plain white regardless of which side
## the message is about.
var player_name: String = ""
var enemy_name: String = ""

func _ready() -> void:
	combat_log.entry_added.connect(_on_entry_added)
	scroll_container.get_v_scroll_bar().changed.connect(_scroll_to_bottom)

func _on_entry_added(text: String, _source: CombatLog.Source) -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.text = _highlight_names(text)
	label.add_theme_color_override("default_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)

## Wraps every occurrence of the player's/enemy's own name in that side's
## accent color -- both names can appear in the same line (e.g. "X uses
## move on Y"), so this isn't driven by which side the entry came from.
func _highlight_names(text: String) -> String:
	if player_name != "":
		text = text.replace(player_name, "[color=#%s]%s[/color]" % [Palette.PLAYER_ACCENT.to_html(false), player_name])
	if enemy_name != "":
		text = text.replace(enemy_name, "[color=#%s]%s[/color]" % [Palette.ENEMY_ACCENT.to_html(false), enemy_name])
	return text

func _scroll_to_bottom() -> void:
	scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

## Wipes every logged entry -- used when a run restarts, so the new run's
## log doesn't start out scrolled past the previous run's entries.
func clear() -> void:
	for child in get_children():
		child.queue_free()