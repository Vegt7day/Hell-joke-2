class_name PauseMenu
extends CanvasLayer

@onready var page_main: VBoxContainer = $Root/Center/PageMain
@onready var page_settings: Control = $Root/Center/PageSettings
@onready var btn_resume: Button = $Root/Center/PageMain/BtnResume
@onready var btn_settings: Button = $Root/Center/PageMain/BtnSettings
@onready var btn_load: Button = $Root/Center/PageMain/BtnLoad
@onready var btn_title: Button = $Root/Center/PageMain/BtnTitle
@onready var btn_quit: Button = $Root/Center/PageMain/BtnQuit

var _in_settings: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	btn_resume.pressed.connect(_on_resume)
	btn_settings.pressed.connect(_on_settings)
	btn_load.pressed.connect(_on_load)
	btn_title.pressed.connect(_on_title)
	btn_quit.pressed.connect(_on_quit)
	if page_settings.has_signal(&"close_requested"):
		page_settings.close_requested.connect(_on_settings_close_requested)
	btn_resume.grab_focus()


func _close_pause() -> void:
	queue_free()
	get_tree().paused = false


func close_pause_external() -> void:
	_close_pause()


func _input(event: InputEvent) -> void:
	if is_instance_valid(Game) and Game.save_slots_sheet_is_open():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if _in_settings:
			_leave_settings_page()
			return
		_close_pause()


func _leave_settings_page() -> void:
	_in_settings = false
	page_settings.visible = false
	page_main.visible = true
	btn_settings.grab_focus()


func _on_settings_close_requested() -> void:
	if _in_settings:
		_leave_settings_page()


func _on_resume() -> void:
	_close_pause()


func _on_settings() -> void:
	_in_settings = true
	page_main.visible = false
	page_settings.visible = true
	if page_settings.has_method(&"refresh_from_game"):
		page_settings.call(&"refresh_from_game")
	var back_btn_path := NodePath("Center/VBox/BtnBack")
	if page_settings.has_node(back_btn_path):
		(page_settings.get_node(back_btn_path) as Button).grab_focus()


func _on_load() -> void:
	if is_instance_valid(Game):
		Game.open_save_slots_sheet(Game.SaveSlotsSheetMode.LOAD, self)


func _on_title() -> void:
	var popup := preload("res://system/ui/confirm_popup.tscn").instantiate() as ConfirmPopup
	if popup == null:
		return
	var on_ok := func():
		Game.return_to_title_screen()
		queue_free()
	get_tree().root.add_child(popup)
	popup.show_confirm("返回标题", "确定返回标题画面？\n未保存的进度将丢失。", on_ok)


func _on_quit() -> void:
	var popup := preload("res://system/ui/confirm_popup.tscn").instantiate() as ConfirmPopup
	if popup == null:
		return
	var on_ok := func():
		get_tree().quit()
	get_tree().root.add_child(popup)
	popup.show_confirm("离开游戏", "确定离开游戏吗？", on_ok)
