class_name GameOverPanel
extends Control

## Shown on a win (game.tres champion defeated) or the final loss --
## battle_controller.gd only ever calls show_message() and connects to
## restart_requested; RestartButton is wired entirely inside this script.

signal restart_requested

@onready var message_label: Label = $Content/MessageLabel
@onready var restart_button: Button = $Content/RestartButton


func _ready() -> void:
	restart_button.pressed.connect(func() -> void: restart_requested.emit())


func show_message(message: String) -> void:
	message_label.text = message
	visible = true
