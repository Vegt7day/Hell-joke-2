class_name PauseMenu
extends CanvasLayer

@onready var btn_resume: Button = $Root/Center/VBox/BtnResume
@onready var btn_inventory: Button = $Root/Center/VBox/BtnInventory
@onready var btn_save: Button = $Root/Center/VBox/BtnSave
@onready var btn_title: Button = $Root/Center/VBox/BtnTitle
@onready var btn_quit: Button = $Root/Center/VBox/BtnQuit

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	btn_resume.pressed.connect(_on_resume)
	btn_inventory.pressed.connect(_on_inventory)
	btn_save.pressed.connect(_on_save)
	btn_title.pressed.connect(_on_title)
	btn_quit.pressed.connect(_on_quit)
	btn_resume.grab_focus()


func _close() -> void:
	queue_free()
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()


func _on_resume() -> void:
	_close()


func _on_inventory() -> void:
	# 文档要求：背包打开时保持暂停；背包 UI（inventory_ui）接入前仅用占位提示，不关闭暂停菜单
	var dlg := AcceptDialog.new()
	dlg.process_mode = Node.PROCESS_MODE_ALWAYS
	dlg.dialog_text = "背包界面尚未接入（Phase 2）。\n稍后将从此处打开物品栏。"
	dlg.ok_button_text = "知道了"
	dlg.confirmed.connect(dlg.queue_free)
	dlg.close_requested.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


func _on_save() -> void:
	if is_instance_valid(Game) and Game.has_method("save_game"):
		Game.save_game("savepoint")


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
