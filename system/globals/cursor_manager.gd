extends Node

## 统一光标管理器 Autoload
## 创建 CanvasLayer + TextureRect 替换系统光标。
## 根据游戏状态切换光标类型和帧（问号/准星/HUD），每类各含常态/悬浮/点击帧。

enum CursorType { HUD, ATTACK, INSPECT }

# 指针.png 8 帧 region（每帧 16x16，共 128x16）
# 实际 PNG 布局：鼠标(0-2) → 问号(3-5) → 准心(6-7)
const _FRAMES := {
	# 鼠标（帧 0-2）
	"hud_normal":     Rect2(0, 0, 16, 16),
	"hud_hover":      Rect2(16, 0, 16, 16),
	"hud_press":      Rect2(32, 0, 16, 16),
	# 问号（帧 3-5）
	"inspect_normal": Rect2(48, 0, 16, 16),
	"inspect_hover":  Rect2(64, 0, 16, 16),
	"inspect_press":  Rect2(80, 0, 16, 16),
	# 准心（帧 6-7）
	"attack_normal":  Rect2(96, 0, 16, 16),
	"attack_press":   Rect2(112, 0, 16, 16),
}

# 每类光标的默认帧 key
const _TYPE_DEFAULT_FRAME := {
	CursorType.INSPECT: "inspect_normal",
	CursorType.ATTACK:  "attack_normal",
	CursorType.HUD:     "hud_normal",
}

# 热点偏移（0,0 = 左上角）
const _HOTSPOT := {
	"inspect_normal": Vector2(6, 14),
	"inspect_hover":  Vector2(6, 14),
	"inspect_press":  Vector2(6, 14),
	"attack_normal":  Vector2(8, 8),
	"attack_press":   Vector2(8, 8),
	"hud_normal":     Vector2(1, 1),
	"hud_hover":      Vector2(1, 1),
	"hud_press":      Vector2(1, 1),
}

var _cursor_tex: AtlasTexture
var _cursor_rect: TextureRect
var _current_type: CursorType = CursorType.ATTACK
var _current_frame_key: String = "attack_normal"
var _is_custom_cursor_showing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var base_tex := preload("res://assets/资源总库/03_图像_UI/指针.png")
	_cursor_tex = AtlasTexture.new()
	_cursor_tex.atlas = base_tex
	_cursor_tex.region = _FRAMES["attack_normal"]
	# Autoload 的 parent（root）仍在 setup，add_child 需延迟
	call_deferred("_build_cursor")


func _build_cursor() -> void:
	var cl := CanvasLayer.new()
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	cl.layer = 135
	cl.name = "CursorManagerLayer"
	get_tree().root.add_child(cl)

	_cursor_rect = TextureRect.new()
	_cursor_rect.name = "CursorRect"
	_cursor_rect.texture = _cursor_tex
	_cursor_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_cursor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_rect.visible = true
	cl.add_child(_cursor_rect)
	# 默认准星常显
	show_cursor()


func _input(event: InputEvent) -> void:
	if _cursor_rect == null:
		return
	if event is InputEventMouseMotion:
		_cursor_rect.global_position = event.global_position - _HOTSPOT[_current_frame_key]
		# HUD 模式：自动检测悬停在任何可交互控件上
		if _current_type == CursorType.HUD:
			var hovered := get_viewport().gui_find_control(event.global_position)
			if hovered != null and hovered is Control and (hovered as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
				set_frame_key("hud_hover")
			elif _current_frame_key == "hud_hover":
				set_frame_key("hud_normal")
	if event is InputEventMouseButton:
		if _current_type == CursorType.ATTACK:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					set_frame_key("attack_press")
				else:
					set_frame_key("attack_normal")
		elif _current_type == CursorType.HUD:
			if event.pressed:
				set_frame_key("hud_press")
			else:
				var hovered := get_viewport().gui_find_control(event.global_position)
				if hovered != null and hovered is Control and (hovered as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
					set_frame_key("hud_hover")
				else:
					set_frame_key("hud_normal")


## 设置光标类型（问号/准星/HUD），自动还原为对应默认帧
func set_cursor_type(t: CursorType) -> void:
	_current_type = t
	set_frame_key(_TYPE_DEFAULT_FRAME[t])


## 按 key 切换具体帧
func set_frame_key(key: String) -> void:
	if not _FRAMES.has(key):
		return
	_current_frame_key = key
	_cursor_tex.region = _FRAMES[key]


## 显示自定义光标，隐藏系统光标
func show_cursor() -> void:
	if _is_custom_cursor_showing:
		return
	_is_custom_cursor_showing = true
	if _cursor_rect != null:
		_cursor_rect.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


## 隐藏自定义光标，恢复系统光标
func hide_cursor() -> void:
	if not _is_custom_cursor_showing:
		return
	_is_custom_cursor_showing = false
	if _cursor_rect != null:
		_cursor_rect.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func is_showing() -> bool:
	return _is_custom_cursor_showing


func get_current_type() -> CursorType:
	return _current_type


func get_current_frame_key() -> String:
	return _current_frame_key
