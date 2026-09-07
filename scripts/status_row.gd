class_name StatusRow
extends HFlowContainer

## Maps a status's status_id() to the container currently displaying it, so a
## status that's still active keeps the same node (and tooltip hover state)
## across refreshes instead of being destroyed and recreated every time
## set_status_icons() is called -- see DECISIONS.md/DEVLOG.md for why that
## used to make active tooltips flash/disappear.
var _icon_containers: Dictionary = {}

## Set once by whoever owns this row (battle_controller.gd) so hovering an
## icon can route through the shared hand-rolled tooltip system instead of
## the built-in tooltip_text popup.
var tooltip_layer: TooltipLayer = null

func set_status_icons(entries: Array[Dictionary]) -> void:
	var seen_ids: Array[StringName] = []

	for entry in entries:
		# entry is a dict with keys "id", "color", "stacks", "icon", "description", and "damage" (unused)
		var id: StringName = entry.get("id", &"")
		seen_ids.append(id)

		var container: HBoxContainer = _icon_containers.get(id)
		if container == null:
			container = _build_status_container()
			_icon_containers[id] = container
			add_child(container)

		_update_status_container(container, entry)

	for id in _icon_containers.keys().duplicate():
		if id not in seen_ids:
			_icon_containers[id].free()
			_icon_containers.erase(id)

## Builds the (initially empty) label+icon pair for one status. Only called
## the first time a given status_id shows up -- every later refresh reuses
## this same container via _update_status_container() instead.
func _build_status_container() -> HBoxContainer:
	var container := HBoxContainer.new()

	var stack_label := Label.new()
	stack_label.name = "StackLabel"
	stack_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	stack_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	stack_label.add_theme_constant_override("shadow_offset_x", 1)
	stack_label.add_theme_constant_override("shadow_offset_y", 1)
	stack_label.add_theme_font_size_override("font_size", 14)
	stack_label.add_theme_font_override("font", load("res://assets/fonts/yoster.ttf"))
	container.add_child(stack_label)

	var icon_texture_rect := TextureRect.new()
	icon_texture_rect.name = "Icon"
	icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	icon_texture_rect.custom_minimum_size = Vector2(20, 20)  # Set a minimum size for the icon
	container.add_child(icon_texture_rect)

	container.mouse_entered.connect(func() -> void:
		if tooltip_layer != null:
			tooltip_layer.hover_started(container, container.get_meta("tooltip_text", ""))
	)
	container.mouse_exited.connect(func() -> void:
		if tooltip_layer != null:
			tooltip_layer.hover_ended(container)
	)

	return container

## Refreshes one status's displayed stacks/color/icon/tooltip in place. The
## tooltip text is stashed as metadata on the container (not the icon alone)
## so hovering either the icon or the stack count shows the description --
## the mouse_entered handler above reads it fresh at hover time, since the
## same container gets reused across refreshes as stacks change.
func _update_status_container(container: HBoxContainer, entry: Dictionary) -> void:
	var stack_label: Label = container.get_node("StackLabel")
	var icon_texture_rect: TextureRect = container.get_node("Icon")

	stack_label.text = str(entry.get("stacks", 1))
	icon_texture_rect.texture = entry.get("icon", null)
	icon_texture_rect.modulate = entry.get("color", Color(1, 1, 1, 1))
	container.set_meta("tooltip_text", entry.get("description", ""))
