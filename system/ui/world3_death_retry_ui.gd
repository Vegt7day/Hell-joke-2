extends CanvasLayer

@onready var dim_bg: ColorRect = $Root/DimBG
@onready var dead_texture: TextureRect = $Root/Center/VBox/DeadTexture
@onready var dead_label: Label = $Root/Center/VBox/DeadLabel
@onready var btn_heart: Button = $Root/Center/VBox/Buttons/BtnHeart
@onready var btn_savepoint: Button = $Root/Center/VBox/Buttons/BtnSavePoint
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
	# 如果后续配置了“死”图片，就隐藏文字；未配置时用文字占位。
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
		btn_heart.disabled = not bool(_game.call("has_save", "heart"))
	else:
		btn_heart.disabled = false


func _on_press_heart() -> void:
	_play_ui_click()
	if _game != null and _game.has_method("on_world3_death_choice_load_heart"):
		_game.call("on_world3_death_choice_load_heart")
	queue_free()


func _on_press_savepoint() -> void:
	_play_ui_click()
	if _game != null and _game.has_method("on_world3_death_choice_load_savepoint"):
		_game.call("on_world3_death_choice_load_savepoint")
	queue_free()
