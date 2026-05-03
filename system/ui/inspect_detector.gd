extends Area2D
class_name InspectDetector

const INSPECT_POPUP_SCENE: PackedScene = preload("res://system/ui/inspect_popup.tscn")

var _inspect_popup: PanelContainer = null
@export var description: String = ""
static var global_inspect_mode: bool = false
static var hud_root: Control = null
static var _current_hovered_detector: InspectDetector = null


func _ready() -> void:
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not global_inspect_mode:
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var desc: String = description
		if desc.is_empty():
			var mech := get_parent()
			if mech == null:
				return
			if not mech.has_method("_get_inspect_description"):
				return
			desc = mech._get_inspect_description()
		if desc.is_empty():
			return
		# 世界坐标 → 视口坐标（hud_root 在 CanvasLayer 110 上，共享视口坐标空间）
		var viewport_pos: Vector2 = get_viewport().get_canvas_transform() * event.global_position
		_show_popup(desc, viewport_pos)


func _show_popup(desc: String, screen_pos: Vector2) -> void:
	_close_popup()
	var panel := INSPECT_POPUP_SCENE.instantiate() as PanelContainer
	if panel == null:
		return
	var label := panel.get_child(0) as Label
	if label == null:
		return
	label.text = desc
	if hud_root == null:
		return
	# 先添加到场景树以获取实际尺寸
	hud_root.add_child(panel)
	# 左上角对齐问号位置偏移(-16,-16)，钳制到父节点区域内
	var margin: float = 4.0
	panel.position = Vector2(
		clampf(screen_pos.x - 16.0, margin, hud_root.size.x - panel.size.x - margin),
		clampf(screen_pos.y - 16.0, margin, hud_root.size.y - panel.size.y - margin)
	)
	panel.mouse_exited.connect(_on_popup_mouse_exited)
	_inspect_popup = panel


func _on_popup_mouse_exited() -> void:
	if _inspect_popup == null:
		return
	await get_tree().process_frame
	if _inspect_popup != null and is_instance_valid(_inspect_popup):
		var rect := _inspect_popup.get_global_rect()
		if not rect.has_point(get_viewport().get_mouse_position()):
			_close_popup()


func _close_popup() -> void:
	if _inspect_popup != null and is_instance_valid(_inspect_popup):
		_inspect_popup.queue_free()
	_inspect_popup = null


func _on_mouse_entered() -> void:
	if not global_inspect_mode:
		return
	_current_hovered_detector = self
	CursorManager.set_frame_key("inspect_hover")


func _on_mouse_exited() -> void:
	if not global_inspect_mode:
		return
	if _current_hovered_detector == self:
		_current_hovered_detector = null
		CursorManager.set_frame_key("inspect_normal")
