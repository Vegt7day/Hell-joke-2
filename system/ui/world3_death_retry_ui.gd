extends CanvasLayer

const SAVE_SLOTS_SHEET_SCENE := preload("res://system/ui/save_slots_sheet.tscn")
const BUTTON_THEME := preload("res://system/ui/button_theme.tres")

@onready var dim_bg: ColorRect = $Root/DimBG
@onready var dead_texture: TextureRect = $Root/MenuBack/Center/VBox/DeadTexture
@onready var dead_label: Label = $Root/MenuBack/Center/VBox/DeadLabel
@onready var btn_heart: Button = $Root/MenuBack/Center/VBox/Buttons/BtnHeart
@onready var btn_savepoint: Button = $Root/MenuBack/Center/VBox/Buttons/BtnSavePoint
@onready var ui_sfx: AudioStreamPlayer = get_node_or_null("UiSfx") as AudioStreamPlayer

var _game: Node = null


func _play_ui_click() -> void:
	if ui_sfx != null and ui_sfx.stream != null:
		ui_sfx.play()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if btn_heart != null and not btn_heart.pressed.is_connected(_on_press_heart):
		btn_heart.pressed.connect(_on_press_heart)
	if btn_savepoint != null and not btn_savepoint.pressed.is_connected(_on_press_savepoint):
		btn_savepoint.pressed.connect(_on_press_savepoint)
	_refresh_heart_button_state()
	if dead_texture != null and dead_texture.texture != null:
		if dead_label != null:
			dead_label.visible = false
	else:
		if dead_label != null:
			dead_label.visible = true


func bind_game(game_node: Node) -> void:
	_game = game_node
	_refresh_heart_button_state()


func _refresh_heart_button_state() -> void:
	if btn_heart == null:
		return
	if _game != null and _game.has_method("has_save"):
		btn_heart.visible = bool(_game.call("has_save", "heart"))
	else:
		btn_heart.visible = true


func _on_press_heart() -> void:
	_play_ui_click()
	if _game != null and _game.has_method("on_world3_death_choice_load_heart"):
		_game.call("on_world3_death_choice_load_heart")
	queue_free()


func _on_press_savepoint() -> void:
	_play_ui_click()
	if is_instance_valid(Game):
		Game.open_save_slots_sheet(Game.SaveSlotsSheetMode.LOAD)
	queue_free()
