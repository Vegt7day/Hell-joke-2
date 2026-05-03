extends Control

@onready var new_game: Button = $MenuBg/V/new_game

@onready var v: VBoxContainer = $MenuBg/V

func _ready() -> void:
	# 根节点若不 IGNORE，全屏 Control 可能在某些层级下影响命中；让点击交给子控件
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	CursorManager.set_cursor_type(CursorManager.CursorType.HUD)
	CursorManager.show_cursor()
	call_deferred("_grab_initial_focus")
	for button: Button in v.get_children():
		button.mouse_entered.connect(button.grab_focus)
		button.mouse_entered.connect(func(): CursorManager.set_frame_key("hud_hover"))
		button.mouse_exited.connect(func(): CursorManager.set_frame_key("hud_normal"))
		button.button_down.connect(func(): CursorManager.set_frame_key("hud_press"))
		button.button_up.connect(func(): CursorManager.set_frame_key("hud_hover"))


func _grab_initial_focus() -> void:
	if is_instance_valid(Game):
		Game.strip_dialogic_mouse_blockers()
	if is_instance_valid(new_game):
		new_game.grab_focus()
		



func _on_new_game_pressed() -> void:
	Game.new_game()

func _on_load_game_pressed() -> void:
	if is_instance_valid(Game):
		Game.open_save_slots_sheet(Game.SaveSlotsSheetMode.LOAD)


func _on_settings_pressed() -> void:
	if is_instance_valid(Game):
		Game.open_settings_ui()


func _on_exit_game_pressed() -> void:
	get_tree().quit()
