class_name CombatLog
extends Node

## Data-only combat log. Knows nothing about how entries are displayed --
## any number of views can subscribe to entry_added.

enum Source { PLAYER, ENEMY }

signal entry_added(text: String, source: Source)

func add_entry(text: String, source: Source) -> void:
	entry_added.emit(text, source)
