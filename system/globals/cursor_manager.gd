extends Node

## 统一光标管理器 Autoload
## 创建 CanvasLayer + TextureRect 替换系统光标。
## 根据游戏状态切换光标类型和帧（问号/准星/HUD），每类各含常态/悬浮/点击帧。
## 全局处理：所有可交互 Control（Button/Slider 等）自动悬浮高亮，任意位置点击均有反馈。

enum CursorType { HUD, ATTACK, INSPECT }

# 指针.png 8 帧 region（每帧 16x16，共 128x16）
const _FRAMES := {
	"hud_normal":     Rect2(0, 0, 16, 16),
	"hud_hover":      Rect2(16, 0, 16, 16),
	"hud_press":      Rect2(32, 0, 16, 16),
	"inspect_normal": Rect2(48, 0, 16, 16),
	"inspect_hover":  Rect2(64, 0, 16, 16),
	"inspect_press":  Rect2(80, 0, 16, 16),
	"attack_normal":  Rect2(96, 0, 16, 16),
	"attack_press":   Rect2(112, 0, 16, 16),
}

const _TYPE_DEFAULT_FRAME := {
	CursorType.INSPECT: "inspect_normal",
	CursorType.ATTACK:  "attack_normal",
	CursorType.HUD:     "hud_normal",
}

const _TYPE_PRESS_FRAME := {
	CursorType.INSPECT: "inspect_press",
	CursorType.ATTACK:  "attack_press",
	CursorType.HUD:     "hud_press",
}

const _TYPE_HOVER_FRAME := {
	CursorType.INSPECT: "inspect_hover",
	CursorType.HUD:     "hud_hover",
}

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

# 悬浮检测：_hovered_count 跟踪已进入但未离开的可交互控件数量
var _hovered_count: int = 0
var _type_before_hover: CursorType = CursorType.ATTACK
# 面板激活标志：打开背包/地图/暂停菜单时设为 true，阻止 _restore_default_cursor 切回准星
var _panel_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var base_tex := preload("res://assets/资源总库/03_图像_UI/指针.png")
	_cursor_tex = AtlasTexture.new()
	_cursor_tex.atlas = base_tex
	_cursor_tex.region = _FRAMES["attack_normal"]
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
	show_cursor()
	# 延迟初始化悬浮检测（等场景树就绪）
	call_deferred("_init_hover_detection")


func _init_hover_detection() -> void:
	get_tree().node_added.connect(_on_node_added)
	_scan_for_interactive(get_tree().root)


## 递归扫描场景树，找出所有 BaseButton / Range（含 Slider）并连接悬浮信号
func _scan_for_interactive(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton or child is Range:
			_connect_hover(child as Control)
		_scan_for_interactive(child)


func _on_node_added(node: Node) -> void:
	if node is BaseButton or node is Range:
		_connect_hover(node as Control)


## 对单个可交互控件连接 mouse_entered / mouse_exited / tree_exiting
func _connect_hover(node: Control) -> void:
	if node.mouse_entered.is_connected(_on_hover_enter):
		return
	node.mouse_entered.connect(_on_hover_enter)
	node.mouse_exited.connect(_on_hover_exit)
	node.tree_exiting.connect(_on_hover_exit)


func _on_hover_enter() -> void:
	_hovered_count += 1
	if _hovered_count == 1:
		_apply_hover_cursor()


func _on_hover_exit() -> void:
	_hovered_count = max(0, _hovered_count - 1)
	if _hovered_count == 0:
		_restore_default_cursor()


## 首次悬浮到可交互控件时：ATTACK/INSPECT → HUD，然后设置 hover 帧
func _apply_hover_cursor() -> void:
	if _current_type == CursorType.HUD:
		set_frame_key("hud_hover")
		return
	_type_before_hover = _current_type
	_current_type = CursorType.HUD
	set_frame_key("hud_hover")


## 所有可交互控件都离开后：HUD → 悬浮前的原始类型（面板激活时不恢复）
func _restore_default_cursor() -> void:
	if _hovered_count > 0 or _panel_active:
		return
	if _current_type == CursorType.HUD:
		set_cursor_type(_type_before_hover)
	elif _TYPE_HOVER_FRAME.has(_current_type):
		set_frame_key(_TYPE_DEFAULT_FRAME[_current_type])


## 面板打开/关闭时调用，阻止悬浮系统切回准星
func set_panel_active(active: bool) -> void:
	_panel_active = active
	if active:
		set_cursor_type(CursorType.HUD)


func _input(event: InputEvent) -> void:
	if _cursor_rect == null:
		return
	if event is InputEventMouseMotion:
		_cursor_rect.global_position = event.global_position - _HOTSPOT[_current_frame_key]
	if event is InputEventMouseButton:
		var is_click: bool = event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]
		if is_click:
			if event.pressed:
				if _TYPE_PRESS_FRAME.has(_current_type):
					set_frame_key(_TYPE_PRESS_FRAME[_current_type])
			else:
				# 释放时：若仍悬浮在可交互控件上则恢复 hover 帧，否则恢复默认帧
				if _hovered_count > 0 and _TYPE_HOVER_FRAME.has(_current_type):
					set_frame_key(_TYPE_HOVER_FRAME[_current_type])
				else:
					set_frame_key(_TYPE_DEFAULT_FRAME[_current_type])


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
