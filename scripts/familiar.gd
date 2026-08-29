class_name Familiar
extends Resource

## A familiar's build: static stats authored in the Inspector and saved as a
## .tres file. Used identically for the player's familiar and any opponent.

@export var familiar_name: String = "Familiar"
@export var sprite: Texture2D
@export var max_hp: int = 50
@export var power: int = 10
@export var defense: int = 5
@export var speed: int = 10
@export var focus: int = 10
