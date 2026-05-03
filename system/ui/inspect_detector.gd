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
	print("[inspect_detector] _ready parent=", get_parent(), " input_event connected=", input_event.is_connected(_on_input_event))


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	print("[inspect_detector] event: ", event)
	if not global_inspect_mode:
		return
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[inspect_detector] left release detected")
		var desc: String = description
		if desc.is_empty():
			var mech := get_parent()
			if mech == null:
				print("[inspect_detector] parent is null")
				return
			if not mech.has_method("_get_inspect_description"):
				print("[inspect_detector] no _get_inspect_description on ", mech.name)
				return
			desc = mech._get_inspect_description()
		print("[inspect_detector] desc='", desc, "'")
		if desc.is_empty():
			print("[inspect_detector] empty desc")
			return
		print("[inspect_detector] calling _show_popup")
		_show_popup(desc, event.global_position)


func _show_popup(desc: String, screen_pos: Vector2) -> void:
	_close_popup()
	print("[inspect_detector] panel instantiate start")
	var panel := INSPECT_POPUP_SCENE.instantiate() as PanelContainer
	print("[inspect_detector] panel=", panel)
	if panel == null:
		print("[inspect_detector] panel is null!")
		return
	var label := panel.get_child(0) as Label
	print("[inspect_detector] label=", label)
	if label == null:
		print("[inspect_detector] label is null!")
		return
	label.text = desc
	panel.global_position = screen_pos - Vector2(16, 16)
	panel.mouse_exited.connect(_on_popup_mouse_exited)
	print("[inspect_detector] add_child to hud_root, hud_root=", hud_root)
	if hud_root == null:
		print("[inspect_detector] hud_root is null, cannot show popup")
		return
	hud_root.add_child(panel)
	var margin: float = 8.0
	panel.position = Vector2(
		clampf(screen_pos.x - 16, margin, hud_root.size.x - panel.size.x - margin),
		clampf(screen_pos.y - 16, margin, hud_root.size.y - panel.size.y - margin)
	)
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
