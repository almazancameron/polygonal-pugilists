class_name BlockPalette
extends VBoxContainer

## Both palettes -- the technique column on the left and the condition
## column on the right use this same script.
##
## Condition blocks group under headers taken from each definition's
## `category`, so the "split the palette by condition kind" requirement is
## satisfied by authored data rather than by layout code. Adding a new
## category is a new .tres, not an edit here.

const PALETTE_BLOCK_SCENE: PackedScene = preload("res://scenes/priority_builder/palette_block.tscn")

func populate_conditions(definitions: Array[ConditionBlockDefinition]) -> void:
	_clear()

	# Categories in first-appearance order, so the palette's grouping follows
	# the authored order of the definitions rather than an alphabetical
	# reshuffle.
	var seen_categories: Array[String] = []
	for definition in definitions:
		if not seen_categories.has(definition.category):
			seen_categories.append(definition.category)

	for category in seen_categories:
		_add_header(category)
		for definition in definitions:
			if definition.category != category:
				continue
			var block: PaletteBlock = PALETTE_BLOCK_SCENE.instantiate()
			add_child(block)
			block.setup_condition(definition)

func populate_techniques(techniques: Array[Technique], layer: TooltipLayer) -> void:
	_clear()
	for technique in techniques:
		var block: PaletteBlock = PALETTE_BLOCK_SCENE.instantiate()
		add_child(block)
		block.setup_technique(technique, layer)

## Read-only reference list -- see PaletteBlock.setup_passive() for why
## these never produce a drag.
func populate_passives(passives: Array[PassiveEffect], layer: TooltipLayer) -> void:
	_clear()
	for passive in passives:
		var block: PaletteBlock = PALETTE_BLOCK_SCENE.instantiate()
		add_child(block)
		block.setup_passive(passive, layer)

func _add_header(text: String) -> void:
	var header := Label.new()
	header.text = text.to_upper()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)

## queue_free() is deferred, so also remove immediately -- otherwise a
## repopulate in the same frame would append alongside the outgoing children
## instead of replacing them.
func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
