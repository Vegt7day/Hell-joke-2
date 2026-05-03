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
	for btn in [_btn_menu, _btn_pack, _btn_map, _btn_inspect]:
		btn.mouse_entered.connect(_on_hud_btn_hover_enter)
		btn.mouse_exited.connect(_on_hud_btn_hover_exit)
		btn.button_down.connect(_on_hud_btn_hover_press)
		btn.button_up.connect(_on_hud_btn_hover_release)


func _physics_process(_delta: float) -> void:
	if _pending_inspect_pos != Vector2(-1, -1) and _inspect_mode:
		var pos = _pending_inspect_pos
		_pending_inspect_pos = Vector2(-1, -1)
		_try_inspect_at(pos)


func _input(event: InputEvent) -> void:
	if not _inspect_mode:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				CursorManager.set_frame_key("inspect_press")
			else:
				CursorManager.set_frame_key("inspect_normal")
				_pending_inspect_pos = event.global_position
			get_viewport().set_input_as_handled()
			return
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_exit_inspect_mode()
			get_viewport().set_input_as_handled()
			return



func _on_menu_pressed() -> void:
	_exit_inspect_mode()
	if is_instance_valid(Game):
		Game.open_pause_menu()


func _on_pack_pressed() -> void:
	_exit_inspect_mode()
	if is_instance_valid(Game):
		Game.open_inventory_ui()


func _on_map_pressed() -> void:
	_exit_inspect_mode()
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
	CursorManager.set_cursor_type(CursorManager.CursorType.INSPECT)
	CursorManager.show_cursor()


func _exit_inspect_mode() -> void:
	_inspect_mode = false
	InspectDetector.global_inspect_mode = false
	_close_inspect_popup()
	CursorManager.set_cursor_type(CursorManager.CursorType.ATTACK)


func _try_inspect_at(screen_pos: Vector2) -> void:
	var viewport := get_viewport()
	var space := viewport.get_world_2d().direct_space_state
	if space == null:
		print("[inspect] space is null")
		return
	var camera := viewport.get_camera_2d()
	if camera == null:
		print("[inspect] camera is null")
		return
	# 使用 viewport 坐标变换正确处理窗口缩放和 canvas_items 拉伸
	var canvas_transform := viewport.get_canvas_transform()
	var world_pos: Vector2 = canvas_transform.affine_inverse() * screen_pos
	print("[inspect] screen=", screen_pos, " canvas_tf=", canvas_transform, " world=", world_pos)
	
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collision_mask = 0xFFFFFFFF
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var results := space.intersect_point(params)
	print("[inspect] intersect_point returned ", results.size(), " results")
	for r in results:
		var col := r.collider as Node
		if col == null:
			continue
		print("  - collider: ", col, " class=", col.get_class(), " name=", col.name)
		var mech: Node = null
		if col is Area2D:
			mech = col.get_parent() as Node
		elif col is StaticBody2D or col is CharacterBody2D:
			mech = col
		if mech == null:
			continue
		if not mech.is_in_group("inspectable"):
			continue
		print("[inspect] hit: ", mech.name)
		var desc := _describe_body(mech)
		if not desc.is_empty():
			_show_inspect_popup(desc, screen_pos)
			return


func _describe_body(body: Node) -> String:
	var node := body as Node
	print("[inspect] describe_body starting from ", node, " name=", node.name)
	while node != null:
		print("  parent chain step: ", node.name, " script=", node.get_script())
		# 优先调用机制自身的描述方法
		if node.has_method("_get_inspect_description"):
			return node._get_inspect_description()
		var name_lower := node.name.to_lower()
		var script_name := ""
		if node.has_method("get_script") and node.get_script() != null:
			script_name = node.get_script().resource_path.get_file().get_basename().to_lower()
			print("  -> script_name=", script_name)
		
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
	print("[inspect] _show_inspect_popup: desc='", desc, "' screen=", screen_pos)
	
	var panel := INSPECT_POPUP_SCENE.instantiate() as PanelContainer
	if panel == null:
		print("[inspect] panel is null!")
		return
	var label := panel.get_child(0) as Label
	if label == null:
		print("[inspect] label is null!")
		return
	label.text = desc
	
	panel.global_position = screen_pos + Vector2(16, 0)
	panel.mouse_exited.connect(_on_inspect_popup_mouse_exited)
	
	add_child(panel)
	print("[inspect] popup added, child count=", get_child_count())
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


func _on_hud_btn_hover_enter() -> void:
	if _inspect_mode:
		return
	CursorManager.set_cursor_type(CursorManager.CursorType.HUD)
	CursorManager.set_frame_key("hud_hover")


func _on_hud_btn_hover_exit() -> void:
	if _inspect_mode:
		return
	CursorManager.set_cursor_type(CursorManager.CursorType.ATTACK)


func _on_hud_btn_hover_press() -> void:
	if _inspect_mode:
		return
	CursorManager.set_frame_key("hud_press")


func _on_hud_btn_hover_release() -> void:
	if _inspect_mode:
		return
	CursorManager.set_frame_key("hud_hover")
