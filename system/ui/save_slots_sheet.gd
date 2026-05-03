extends CanvasLayer

const SHEET_GROUP := &"save_slots_sheet"

var _mode: Game.SaveSlotsSheetMode = Game.SaveSlotsSheetMode.LOAD
var _pause_menu: Node = null
var _save_point_after_save: SavePointInteractable = null

@onready var title_label: Label = $Root/Center/Panel/PageMargin/VBox/TitleLabel
@onready var btn_slot1: Button = $Root/Center/Panel/PageMargin/VBox/BtnSlot1
@onready var btn_slot2: Button = $Root/Center/Panel/PageMargin/VBox/BtnSlot2
@onready var btn_slot3: Button = $Root/Center/Panel/PageMargin/VBox/BtnSlot3
@onready var btn_cancel: Button = $Root/Center/Panel/PageMargin/VBox/BtnCancel


func setup(mode: Game.SaveSlotsSheetMode, pause_menu: Node = null, save_point_after_save: SavePointInteractable = null) -> void:
	_mode = mode
	_pause_menu = pause_menu
	_save_point_after_save = save_point_after_save


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 125
	add_to_group(SHEET_GROUP)

	btn_slot1.pressed.connect(func(): _on_slot_pressed(0))
	btn_slot2.pressed.connect(func(): _on_slot_pressed(1))
	btn_slot3.pressed.connect(func(): _on_slot_pressed(2))
	btn_cancel.pressed.connect(_close_sheet)

	title_label.text = "选择存档槽位"
	_refresh_slot_buttons()
	btn_slot1.grab_focus()


func _refresh_slot_buttons() -> void:
	if not is_instance_valid(Game):
		return
	for i in range(3):
		var id: String = Game.manual_save_slot_id(i)
		var btn := _slot_button(i)
		var summ: Dictionary = Game.read_manual_save_slot_summary(id)
		var empty: bool = bool(summ.get("empty", true))
		if empty:
			btn.text = "空"
		else:
			var map_label := str(summ.get("map_label", ""))
			var time_text := str(summ.get("time_text", ""))
			if time_text.is_empty():
				btn.text = map_label
			else:
				btn.text = "%s\n%s" % [map_label, time_text]
		btn.disabled = _mode == Game.SaveSlotsSheetMode.LOAD and empty


func _slot_button(index: int) -> Button:
	match index:
		1:
			return btn_slot2
		2:
			return btn_slot3
		_:
			return btn_slot1


func _close_sheet() -> void:
	if _save_point_after_save != null and _mode == Game.SaveSlotsSheetMode.SAVE:
		var tree := get_tree()
		if tree != null:
			tree.paused = false
	queue_free()


func _on_slot_pressed(index: int) -> void:
	if not is_instance_valid(Game):
		return
	var slot_id :String= Game.manual_save_slot_id(index)
	if _mode == Game.SaveSlotsSheetMode.SAVE:
		var summ: Dictionary = Game.read_manual_save_slot_summary(slot_id)
		if not bool(summ.get("empty", true)):
			var popup := preload("res://system/ui/confirm_popup.tscn").instantiate() as ConfirmPopup
			if popup == null:
				return
			get_tree().root.add_child(popup)
			popup.show_confirm(
				"覆盖存档",
				"存档槽 %d 已有存档，确定覆盖？" % [index + 1],
				func(): _perform_save(slot_id)
			)
		else:
			_perform_save(slot_id)
	else:
		var summ_ld: Dictionary = Game.read_manual_save_slot_summary(slot_id)
		if bool(summ_ld.get("empty", true)):
			return
		_perform_load(slot_id)


func _perform_save(slot_id: String) -> void:
	var tree := get_tree()
	if not is_instance_valid(Game):
		if tree != null and _save_point_after_save != null:
			tree.paused = false
		queue_free()
		return
	Game.save_game(slot_id)
	var sp := _save_point_after_save
	if tree != null and sp != null:
		tree.paused = false
	queue_free()
	if sp != null and is_instance_valid(sp):
		Game.start_save_point_post_save_feedback(sp)


func _perform_load(slot_id: String) -> void:
	if not is_instance_valid(Game):
		return
	var ok: bool = await Game.load_game(true, slot_id)
	if not ok:
		return
	queue_free()
	if _pause_menu != null and is_instance_valid(_pause_menu) and _pause_menu.has_method(&"close_pause_external"):
		_pause_menu.call(&"close_pause_external")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_sheet()
