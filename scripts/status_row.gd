class_name StatusRow
extends HBoxContainer


func set_status_icons(entries: Array[Dictionary]) -> void:
	for child in get_children():
		child.free()

	for entry in entries:
		# entry is a dict with keys "color", "stacks", "icon", and "damage" (unused)
		var icon_texture: Texture2D = entry.get("icon", null)
		var color: Color = entry.get("color", Color(1, 1, 1, 1))
		var stacks: int = entry.get("stacks", 1)

		var icon_texture_rect: TextureRect = TextureRect.new()
		icon_texture_rect.texture = icon_texture
		icon_texture_rect.modulate = color
		icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		icon_texture_rect.custom_minimum_size = Vector2(16, 16)  # Set a minimum size for the icon

		var stack_label: Label = Label.new()
		stack_label.text = str(stacks)
		stack_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		stack_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		stack_label.add_theme_constant_override("shadow_offset_x", 1)
		stack_label.add_theme_constant_override("shadow_offset_y", 1)
		stack_label.add_theme_constant_override("font_size", 12)
		stack_label.add_theme_font_override("font", load("res://assets/fonts/BoldPixels.ttf"))

		add_child(stack_label)

		add_child(icon_texture_rect)
