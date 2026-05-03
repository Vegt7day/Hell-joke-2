extends Control

@onready var _btn_menu: TextureButton = $MenuBtnGroup/BtnGroup_Menu/BtnMenu
@onready var _btn_pack: TextureButton = $MenuBtnGroup/BtnGroup_Pack/BtnPack
@onready var _btn_map: TextureButton = $MenuBtnGroup/BtnGroup_Map/BtnMap
@onready var _btn_inspect: TextureButton = $MenuBtnGroup/BtnGroup_Inspect/BtnInspect

const INSPECT_POPUP_SCENE: PackedScene = preload("res://system/ui/inspect_popup.tscn")

var _inspect_mode: bool = false
var _inspect_popup: PanelContainer = null
var _pending_inspect_pos: Vector2 = Vector2(-1, -1)


func _ready() -> void:
	InspectDetector.hud_root = self
	_btn_menu.pressed.connect(_on_menu_pressed)
	_btn_pack.pressed.connect(_on_pack_pressed)
	_btn_map.pressed.connect(_on_map_pressed)
	_btn_inspect.pressed.connect(_on_inspect_pressed)


func _physics_process(_delta: float) -> void:
	if _pending_inspect_pos != Vector2(-1, -1) and _inspect_mode:
		var pos = _pending_inspect_pos
		_pending_inspect_pos = Vector2(-1, -1)
		_try_inspect_at(pos)


func _input(event: InputEvent) -> void:
	# X 键切换详细/检查模式
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_X:
			_on_inspect_pressed()
			get_viewport().set_input_as_handled()
			return

	if not _inspect_mode:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# 悬浮在按钮上时：放行事件让按钮处理点击（按钮自身会退出检查模式）
			if CursorManager._hovered_count > 0:
				return
			if not event.pressed:
				_pending_inspect_pos = event.global_position
			get_viewport().set_input_as_handled()
			return
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_exit_inspect_mode()
			get_viewport().set_input_as_handled()
			return



func _on_menu_pressed() -> void:
	_exit_inspect_mode()
	CursorManager.set_panel_active(true)
	if is_instance_valid(Game):
		Game.open_pause_menu()


func _on_pack_pressed() -> void:
	_exit_inspect_mode()
	CursorManager.set_panel_active(true)
	if is_instance_valid(Game):
		Game.open_inventory_ui()


func _on_map_pressed() -> void:
	_exit_inspect_mode()
	CursorManager.set_panel_active(true)
	if is_instance_valid(Game):
		Game.open_abstract_map_ui()


func _on_inspect_pressed() -> void:
	if _inspect_mode:
		_exit_inspect_mode()
	else:
		_enter_inspect_mode()


func _enter_inspect_mode() -> void:
	_inspect_mode = true
	InspectDetector.global_inspect_mode = true
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	get_tree().paused = true
	# 暂停时将己方 HUD 节点设为不受暂停影响
	for c in get_parent().get_children():
		if c is CanvasLayer:
			c.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		elif c is Control:
			c.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	CursorManager.set_cursor_type(CursorManager.CursorType.INSPECT)
	CursorManager.show_cursor()


func _exit_inspect_mode() -> void:
	_inspect_mode = false
	InspectDetector.global_inspect_mode = false
	_close_inspect_popup()
	get_tree().paused = false
	# 恢复 HUD 节点的 process_mode
	process_mode = Node.PROCESS_MODE_INHERIT
	for c in get_parent().get_children():
		if c is CanvasLayer or c is Control:
			c.process_mode = Node.PROCESS_MODE_INHERIT
	# 退出时若仍在按钮上，恢复为 HUD 光标而非准星
	CursorManager.set_cursor_type(CursorManager.CursorType.ATTACK)


func _try_inspect_at(screen_pos: Vector2) -> void:
	var viewport := get_viewport()
	var space := viewport.get_world_2d().direct_space_state
	if space == null:
		return
	var camera := viewport.get_camera_2d()
	if camera == null:
		return
	var canvas_transform := viewport.get_canvas_transform()
	var world_pos: Vector2 = canvas_transform.affine_inverse() * screen_pos
	
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collision_mask = 0xFFFFFFFF
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var results := space.intersect_point(params)
	# 精确位置未命中时，搜索周围 5×5 网格（覆盖碰撞体边缘）
	if results.is_empty():
		for dx in range(-2, 3):
			if not results.is_empty():
				break
			for dy in range(-2, 3):
				if dx == 0 and dy == 0:
					continue
				params.position = world_pos + Vector2(dx, dy)
				results = space.intersect_point(params)
				if not results.is_empty():
					break
		params.position = world_pos
	# 按碰撞体中心到查询点的距离排序，优先匹配最近的
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_node := a.collider as Node2D
		var b_node := b.collider as Node2D
		if a_node == null: return false
		if b_node == null: return true
		return a_node.global_position.distance_squared_to(world_pos) < b_node.global_position.distance_squared_to(world_pos)
	)
	for r in results:
		var col := r.collider as Node
		if col == null:
			continue
		# 先尝试父节点（InspectDetector 子节点的情况），再尝试碰撞体自身
		var desc := ""
		if col is Area2D and col.get_parent() != null:
			desc = _describe_body(col.get_parent())
		if desc.is_empty():
			desc = _describe_body(col)
		if not desc.is_empty():
			_show_inspect_popup(desc, screen_pos)
			return


func _describe_body(body: Node) -> String:
	var node := body as Node
	while node != null:
		if node.has_method("_get_inspect_description"):
			return node._get_inspect_description()
		var name_lower := node.name.to_lower()
		var script_name := ""
		if node.has_method("get_script") and node.get_script() != null:
			script_name = node.get_script().resource_path.get_file().get_basename().to_lower()
		
		if _check_name(name_lower, script_name, "洞", "hole"):
			return "可疑的土地"
		elif _check_name(name_lower, script_name, "开关", "switch"):
			return "能触发对应颜色机关的开关"
		elif _check_name(name_lower, script_name, "窗", "window"):
			return "可被开关控制的窗户"
		elif _check_name(name_lower, script_name, "桶", "bucket"):
			return "被打中后会漏水的旧桶"
		elif _check_name(name_lower, script_name, "水", "water"):
			return "从桶里溅出的水滴"
		elif _check_name(name_lower, script_name, "触发器", "trigger"):
			return "踩上去会触发陷阱的机关"
		elif _check_name(name_lower, script_name, "存档", "save"):
			return "可以保存进度的存档点"
		elif _check_name(name_lower, script_name, "门", "door"):
			return "可以通行的门"
		elif name_lower.contains("机关") or name_lower.contains("mechanism"):
			return "触发后会影响周围环境的机关"
		
		if node.get_parent() != null:
			node = node.get_parent()
		else:
			break
	return ""


func _check_name(name_lower: String, script_name: String, cn: String, en: String) -> bool:
	return name_lower.contains(cn) or name_lower.contains(en) or script_name.contains(cn)


func _show_inspect_popup(desc: String, screen_pos: Vector2) -> void:
	_close_inspect_popup()
	var panel := INSPECT_POPUP_SCENE.instantiate() as PanelContainer
	if panel == null:
		return
	var label := panel.get_child(0) as Label
	if label == null:
		return
	label.text = desc
	# 先添加到场景树以获取实际尺寸
	add_child(panel)
	# 左上角对齐问号位置偏移(-16,-16)，钳制到父节点区域内
	var margin: float = 4.0
	panel.position = Vector2(
		clampf(screen_pos.x - 16.0, margin, size.x - panel.size.x - margin),
		clampf(screen_pos.y - 16.0, margin, size.y - panel.size.y - margin)
	)
	panel.mouse_exited.connect(_on_inspect_popup_mouse_exited)
	_inspect_popup = panel


func _on_inspect_popup_mouse_exited() -> void:
	if _inspect_popup == null:
		return
	await get_tree().process_frame
	if _inspect_popup != null and is_instance_valid(_inspect_popup):
		var rect := _inspect_popup.get_global_rect()
		if not rect.has_point(get_viewport().get_mouse_position()):
			_close_inspect_popup()


func _close_inspect_popup() -> void:
	if _inspect_popup != null and is_instance_valid(_inspect_popup):
		_inspect_popup.queue_free()
	_inspect_popup = null
