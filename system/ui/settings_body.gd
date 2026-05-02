extends Control

signal close_requested

const SETTINGS_UI_GROUP := &"settings_ui"
const FONT_UI_16 := preload("res://assets/资源总库/11_字体/VonwaonBitmap-16px.ttf") as FontFile

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

@onready var slider_master: HSlider = $Center/back/PageMargin/VBox/AudioSection/MasterRow/HSlider
@onready var slider_bgm: HSlider = $Center/back/PageMargin/VBox/AudioSection/BgmRow/HSlider
@onready var slider_sfx: HSlider = $Center/back/PageMargin/VBox/AudioSection/SfxRow/HSlider
@onready var slider_ui: HSlider = $Center/back/PageMargin/VBox/AudioSection/UiRow/HSlider

@onready var check_fullscreen: CheckBox = $Center/back/PageMargin/VBox/DisplaySection/ResolutionRow/CheckFullscreen
@onready var option_resolution: OptionButton = $Center/back/PageMargin/VBox/DisplaySection/ResolutionRow/OptionResolution

@onready var btn_back: Button = $Center/back/PageMargin/VBox/BtnBack


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	slider_master.value_changed.connect(func(v): _on_bus_slider_changed(&"Master", v))
	slider_bgm.value_changed.connect(func(v): _on_bus_slider_changed(&"BGM", v))
	slider_sfx.value_changed.connect(func(v): _on_bus_slider_changed(&"SFX", v))
	slider_ui.value_changed.connect(func(v): _on_bus_slider_changed(&"UI", v))

	check_fullscreen.toggled.connect(_on_fullscreen_toggled)
	option_resolution.item_selected.connect(_on_resolution_selected)
	btn_back.pressed.connect(_request_close)

	if FONT_UI_16 != null:
		var pop := option_resolution.get_popup()
		pop.add_theme_font_override(&"font", FONT_UI_16)
		pop.add_theme_font_size_override(&"font_size", 16)
		pop.theme = preload("res://system/ui/button_theme.tres")

	_sync_settings_ui_group()
	refresh_from_game()


func _on_visibility_changed() -> void:
	_sync_settings_ui_group()


func _sync_settings_ui_group() -> void:
	if not is_inside_tree():
		return
	if visible:
		add_to_group(SETTINGS_UI_GROUP)
	else:
		if is_in_group(SETTINGS_UI_GROUP):
			remove_from_group(SETTINGS_UI_GROUP)


func refresh_from_game() -> void:
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


func _request_close() -> void:
	if is_instance_valid(Game):
		Game.persist_settings_to_disk()
	close_requested.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_request_close()
