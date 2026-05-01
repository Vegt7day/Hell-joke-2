extends CanvasLayer

const SETTINGS_UI_GROUP := &"settings_ui"

## 常用窗口像素尺寸（16:9 与 4:3）；下拉文案与数组顺序一致
const WINDOW_PRESETS: Array[Vector2i] = [
	Vector2i(640, 360),
	Vector2i(854, 480),
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
	Vector2i(640, 480),
	Vector2i(800, 600),
	Vector2i(1024, 768),
	Vector2i(1280, 960),
	Vector2i(1600, 1200),
]

const WINDOW_PRESET_LABELS: PackedStringArray = [
	"640 × 360 (16:9)",
	"854 × 480 (16:9)",
	"960 × 540 (16:9)",
	"1280 × 720 (16:9)",
	"1600 × 900 (16:9)",
	"1920 × 1080 (16:9)",
	"2560 × 1440 (16:9)",
	"3840 × 2160 (16:9)",
	"640 × 480 (4:3)",
	"800 × 600 (4:3)",
	"1024 × 768 (4:3)",
	"1280 × 960 (4:3)",
	"1600 × 1200 (4:3)",
]

var _reopen_pause_menu: bool = false

@onready var slider_master: HSlider = $Root/Center/VBox/AudioSection/MasterRow/HSlider
@onready var slider_bgm: HSlider = $Root/Center/VBox/AudioSection/BgmRow/HSlider
@onready var slider_sfx: HSlider = $Root/Center/VBox/AudioSection/SfxRow/HSlider
@onready var slider_ui: HSlider = $Root/Center/VBox/AudioSection/UiRow/HSlider

@onready var check_fullscreen: CheckBox = $Root/Center/VBox/DisplaySection/CheckFullscreen
@onready var option_resolution: OptionButton = $Root/Center/VBox/DisplaySection/ResolutionRow/OptionResolution

@onready var btn_back: Button = $Root/Center/VBox/BtnBack


func setup(reopen_pause_menu: bool) -> void:
	_reopen_pause_menu = reopen_pause_menu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 101
	add_to_group(SETTINGS_UI_GROUP)

	slider_master.value_changed.connect(func(v): _on_bus_slider_changed(&"Master", v))
	slider_bgm.value_changed.connect(func(v): _on_bus_slider_changed(&"BGM", v))
	slider_sfx.value_changed.connect(func(v): _on_bus_slider_changed(&"SFX", v))
	slider_ui.value_changed.connect(func(v): _on_bus_slider_changed(&"UI", v))

	check_fullscreen.toggled.connect(_on_fullscreen_toggled)
	option_resolution.item_selected.connect(_on_resolution_selected)
	btn_back.pressed.connect(_close)

	_refresh_controls_from_game()


func _refresh_controls_from_game() -> void:
	if not is_instance_valid(Game):
		return
	slider_master.set_block_signals(true)
	slider_bgm.set_block_signals(true)
	slider_sfx.set_block_signals(true)
	slider_ui.set_block_signals(true)
	slider_master.value = Game.get_audio_bus_slider_normalized(&"Master")
	slider_bgm.value = Game.get_audio_bus_slider_normalized(&"BGM")
	slider_sfx.value = Game.get_audio_bus_slider_normalized(&"SFX")
	slider_ui.value = Game.get_audio_bus_slider_normalized(&"UI")
	slider_master.set_block_signals(false)
	slider_bgm.set_block_signals(false)
	slider_sfx.set_block_signals(false)
	slider_ui.set_block_signals(false)

	check_fullscreen.set_block_signals(true)
	check_fullscreen.button_pressed = Game.display_is_fullscreen()
	check_fullscreen.set_block_signals(false)

	option_resolution.set_block_signals(true)
	option_resolution.clear()
	for i in range(WINDOW_PRESETS.size()):
		var lbl: String = WINDOW_PRESET_LABELS[i] if i < WINDOW_PRESET_LABELS.size() else "%d × %d" % [WINDOW_PRESETS[i].x, WINDOW_PRESETS[i].y]
		option_resolution.add_item(lbl)
	var w := Game.get_settings_window_width()
	var h := Game.get_settings_window_height()
	option_resolution.select(_nearest_preset_index(w, h))
	option_resolution.disabled = Game.display_is_fullscreen()
	option_resolution.set_block_signals(false)


func _on_bus_slider_changed(bus_name: StringName, normalized: float) -> void:
	if is_instance_valid(Game):
		Game.set_audio_bus_from_normalized(bus_name, normalized)
		Game.persist_settings_to_disk()


func _on_fullscreen_toggled(pressed: bool) -> void:
	if not is_instance_valid(Game):
		return
	Game.apply_display_settings(pressed, Game.get_settings_window_width(), Game.get_settings_window_height())
	Game.persist_settings_to_disk()
	option_resolution.disabled = pressed


func _on_resolution_selected(index: int) -> void:
	if not is_instance_valid(Game):
		return
	if index < 0 or index >= WINDOW_PRESETS.size():
		return
	var p: Vector2i = WINDOW_PRESETS[index]
	Game.apply_display_settings(Game.display_is_fullscreen(), p.x, p.y)
	Game.persist_settings_to_disk()


func _nearest_preset_index(w: int, h: int) -> int:
	var best_i := 0
	var best_d := 2147483647
	for i in range(WINDOW_PRESETS.size()):
		var p: Vector2i = WINDOW_PRESETS[i]
		var d: int = absi(w - p.x) + absi(h - p.y)
		if d < best_d:
			best_d = d
			best_i = i
	return best_i


func _close() -> void:
	if is_instance_valid(Game):
		Game.persist_settings_to_disk()
	var reopen := _reopen_pause_menu
	# 必须先脱离组再 queue_free：否则下一帧 deferred 打开暂停菜单时节点仍在树内，
	# Game.settings_ui_is_open() 为真会直接 return，游戏会一直卡在 paused。
	remove_from_group(SETTINGS_UI_GROUP)
	queue_free()
	if reopen and is_instance_valid(Game):
		Game.call_deferred(&"open_pause_menu_after_settings")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
