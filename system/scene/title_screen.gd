extends Control

@onready var new_game: Button = $V/new_game

@onready var v: VBoxContainer = $V

func _ready()->  void:
	new_game.grab_focus()
	for button:Button in v.get_children():
		button.mouse_entered.connect(button.grab_focus)
		



func _on_new_game_pressed() -> void:
	Game.new_game()

func _on_load_game_pressed() -> void:
	Game.load_game()

func _on_exit_game_pressed() -> void:
	get_tree().quit()
