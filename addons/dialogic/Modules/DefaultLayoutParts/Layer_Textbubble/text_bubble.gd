extends Control

@onready var text: DialogicNode_DialogText = (%DialogText as DialogicNode_DialogText)
# The choice container is added by the TextBubble layer
@onready var choice_container: Container = null

@onready var nine_patch_rect: NinePatchRect = $Group/NinePatchRect

var node_to_point_at: Node = null:
	set(val):
		node_to_point_at = val
		base_position = get_speaker_canvas_position() + base_direction * safe_zone
		position = base_position

# 修复：current_character 的 getter 和 setter
var _current_character: DialogicCharacter = null
var current_character: DialogicCharacter:
	get:
		# 返回安全的 current_character
		return _current_character
	set(value):
		# 设置 current_character
		_current_character = value
		# 调试信息 - 修复：使用安全的方法获取角色名称
		if Engine.is_editor_hint():
			return
		if value and is_instance_valid(value):
			# 修复：使用更安全的方法获取角色显示名称
			if value.has_method("get_display_name"):
				print("设置 current_character:", value.get_display_name())
			elif value.has_method("_get_name"):
				print("设置 current_character:", value._get_name())
			elif "name" in value:
				print("设置 current_character:", value.name)
			else:
				print("设置 current_character: [DialogicCharacter 资源]")
		else:
			print("设置 current_character: null")

var max_width := 300

var bubble_rect: Rect2 = Rect2(0.0, 0.0, 2.0, 2.0)
var base_position := Vector2.ZERO

var base_direction := Vector2(1.0, -1.0).normalized()
var safe_zone := 20.0
var padding := Vector2(10,10)  # 这个padding变量在_resize_bubble中没有被使用

# 气泡背景的内边距
var bg_padding := Vector2(5, 5)  # 这个在_resize_bubble中被使用

# 调试计数器
var resize_counter: int = 0
# 调试标识
var bubble_id: String = ""

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	# 生成唯一ID用于调试
	bubble_id = str(get_instance_id())
	print("=== 气泡脚本调试信息 (ID: ", bubble_id, ") ===")
	print("气泡节点路径:", get_path())
	print("text 节点:", text)
	print("text 节点类型:", typeof(text))
	print("text 节点路径:", get_path_to(text) if text else "null")
	print("nine_patch_rect 节点:", nine_patch_rect)
	print("nine_patch_rect 是否有效:", is_instance_valid(nine_patch_rect) if nine_patch_rect else "null")
	
	# 检查是否有DialogText节点
	var dialog_text_node = get_node_or_null("%DialogText")
	print("通过%DialogText查找:", dialog_text_node)
	
	# 检查所有子节点
	print("所有子节点:")
	for child in get_children():
		print("  - ", child.name, " (", child.get_class(), ")")
	
	reset()
	DialogicUtil.autoload().Choices.question_shown.connect(_on_question_shown)

func reset() -> void:
	set_process(false)
	scale = Vector2.ZERO
	modulate.a = 0.0

	bubble_rect = Rect2(0,0,2,2)

	base_position = get_speaker_canvas_position() + base_direction * safe_zone
	position = base_position

func _process(delta:float) -> void:
	base_position = get_speaker_canvas_position()

	var center := get_viewport_rect().size / 2.0

	var dist_x := absf(base_position.x - center.x)
	var dist_y := absf(base_position.y - center.y)
	var x_e := center.x - bubble_rect.size.x
	var y_e := center.y - bubble_rect.size.y
	var influence_x := remap(clamp(dist_x, x_e, center.x), x_e, center.x * 0.8, 0.0, 1.0)
	var influence_y := remap(clamp(dist_y, y_e, center.y), y_e, center.y * 0.8, 0.0, 1.0)
	if base_position.x > center.x: influence_x = -influence_x
	if base_position.y > center.y: influence_y = -influence_y
	var edge_influence := Vector2(influence_x, influence_y)

	var direction := (base_direction + edge_influence).normalized()

	var p: Vector2 = base_position + direction * (
		safe_zone + lerp(bubble_rect.size.y, bubble_rect.size.x, abs(direction.x)) * 0.4
		)
	p = p.clamp(bubble_rect.size / 2.0, get_viewport_rect().size - bubble_rect.size / 2.0)

	position = position.lerp(p, 5 * delta)

func open() -> void:
	set_process(true)
	show()
	text.enabled = true
	
	var open_tween := create_tween().set_parallel(true)
	open_tween.tween_property(self, "scale", Vector2.ONE, 0.1).from(Vector2.ZERO)
	open_tween.tween_property(self, "modulate:a", 1.0, 0.1).from(0.0)
	if nine_patch_rect and is_instance_valid(nine_patch_rect):
		open_tween.tween_property(nine_patch_rect, "modulate:a", 1.0, 0.1).from(0.0)

func close() -> void:
	text.enabled = false
	var close_tween := create_tween().set_parallel(true)
	close_tween.tween_property(self, "scale", Vector2.ONE * 0.8, 0.2)
	close_tween.tween_property(self, "modulate:a", 0.0, 0.2)
	if nine_patch_rect and is_instance_valid(nine_patch_rect):
		close_tween.tween_property(nine_patch_rect, "modulate:a", 0.0, 0.2)
	await close_tween.finished
	hide()
	set_process(false)

func _on_dialog_text_started_revealing_text() -> void:
	_resize_bubble(await get_base_content_size(), true)

func _resize_bubble(content_size:Vector2, popup:=false) -> void:
	resize_counter += 1
	print("=== 调整气泡大小 (ID: ", bubble_id, ", 第", resize_counter, "次) ===")
	print("内容大小:", content_size)
	
	# 修复第一次气泡过大的问题
	if resize_counter == 1 and content_size.y > 100:
		print("检测到第一次调整尺寸异常，进行修正")
		# 根据内容宽度估算合理的高度
		# 经验公式：每行高度约 20-25 像素
		var estimated_lines = ceil(content_size.x / (max_width * 0.8))
		var estimated_height = estimated_lines * 22.0  # 行高
		# 限制最大高度
		estimated_height = min(estimated_height, 100.0)
		estimated_height = max(estimated_height, 30.0)  # 最小高度
		content_size.y = estimated_height
		print("修正后内容大小:", content_size)
	
	# 计算气泡大小
	# 注意：只使用很小的内边距，让气泡紧贴文字
	var bubble_size: Vector2 = content_size + (bg_padding * 2)
	
	var half_size: Vector2 = (bubble_size / 2.0)
	
	# 更新气泡矩形
	bubble_rect = Rect2(position, bubble_size)
	
	# 设置NinePatchRect作为背景 - 添加完整的空值检查
	if nine_patch_rect and is_instance_valid(nine_patch_rect):
		# 检查 nine_patch_rect 是否仍然有效
		if nine_patch_rect.texture and is_instance_valid(nine_patch_rect.texture):
			# 直接设置大小和位置
			nine_patch_rect.size = bubble_size
			nine_patch_rect.position = -half_size
			nine_patch_rect.pivot_offset = half_size
			
			print("NinePatchRect设置完成:")
			print("  - 大小:", nine_patch_rect.size)
			print("  - 位置:", nine_patch_rect.position)
			print("  - 轴心点:", nine_patch_rect.pivot_offset)
			print("  - 纹理:", nine_patch_rect.texture.get_size() if nine_patch_rect.texture else "无纹理")
			
			if popup:
				var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				t.tween_property(nine_patch_rect, "scale", Vector2.ONE, 0.2).from(Vector2.ZERO)
			else:
				nine_patch_rect.scale = Vector2.ONE
		else:
			print("警告: NinePatchRect纹理未加载或无效")
			# 即使纹理未加载，也设置基本属性
			nine_patch_rect.size = bubble_size
			nine_patch_rect.position = -half_size
			nine_patch_rect.pivot_offset = half_size
	else:
		print("错误: nine_patch_rect 为 null 或无效，无法设置背景")
		# 返回，避免进一步处理
		return
	
	# 设置文本大小和位置
	if text and is_instance_valid(text):
		text.size = content_size
		# 修复：文本应该考虑内边距，而不是居中
		# 原来的代码：text.position = -half_size
		# 正确的代码：文本应该从气泡左上角偏移内边距
		# 气泡的左上角是 -half_size
		# 所以文本的左上角应该是 -half_size + bg_padding
		text.position = -half_size + bg_padding
		print("文本位置:", text.position, " (考虑了内边距: ", bg_padding, ")")
	else:
		print("错误: text 节点无效，无法设置文本位置")

func _on_question_shown(info:Dictionary) -> void:
	if !is_visible_in_tree():
		return

	# 避免选择容器闪烁
	if choice_container and is_instance_valid(choice_container):
		choice_container.modulate.a = 0

	var content_size := await get_base_content_size()
	if choice_container and is_instance_valid(choice_container):
		content_size.y += choice_container.size.y
		content_size.x = max(content_size.x, choice_container.size.x)
	
	_resize_bubble(content_size)

	# 显示选择容器
	if choice_container and is_instance_valid(choice_container):
		choice_container.modulate.a = 1

func get_base_content_size() -> Vector2:
	# 确保文本节点存在
	if not is_instance_valid(text):
		print("错误：text 节点无效")
		return Vector2(100, 30)
	
	var font: Font = text.get_theme_font(&"normal_font")
	var text_width = font.get_multiline_string_size(
		text.get_parsed_text(),
		HORIZONTAL_ALIGNMENT_LEFT,
		max_width,
		text.get_theme_font_size(&"normal_font_size")
		).x

	# 让文本使用内容的宽度，并自动缩小高度以适应内容
	text.size = Vector2(text_width, 0)
	await get_tree().process_frame

	return text.size

func add_choice_container(node:Container, alignment:=FlowContainer.ALIGNMENT_BEGIN, choices_button_path:="", maximum_choices:=5) -> void:
	if choice_container and is_instance_valid(choice_container):
		choice_container.get_parent().remove_child(choice_container)
		choice_container.queue_free()

	node.name = "ChoiceContainer"
	choice_container = node
	node.set_anchors_preset(LayoutPreset.PRESET_BOTTOM_WIDE)
	node.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	# 确保文本节点存在后再添加子节点
	if is_instance_valid(text):
		text.add_child(node)
	else:
		print("错误：无法添加选择容器，text 节点无效")
		return

	if node is HFlowContainer:
		(node as HFlowContainer).alignment = alignment

	var choices_button: PackedScene = null
	if not choices_button_path.is_empty():
		if ResourceLoader.exists(choices_button_path):
			choices_button = (load(choices_button_path) as PackedScene)
		else:
			printerr("[Dialogic] Unable to load custom choice button from ", choices_button_path)

	for i:int in range(maximum_choices):
		var new_button : DialogicNode_ChoiceButton
		if choices_button == null:
			new_button = DialogicNode_ChoiceButton.new()
		else:
			new_button = (choices_button.instantiate() as DialogicNode_ChoiceButton)
		choice_container.add_child(new_button)
		if node is HFlowContainer:
			continue
		match alignment:
			HBoxContainer.ALIGNMENT_BEGIN:
				(choice_container.get_child(-1) as Control).size_flags_horizontal = SIZE_SHRINK_BEGIN
			HBoxContainer.ALIGNMENT_CENTER:
				(choice_container.get_child(-1) as Control).size_flags_horizontal = SIZE_SHRINK_CENTER
			HBoxContainer.ALIGNMENT_END:
				(choice_container.get_child(-1) as Control).size_flags_horizontal = SIZE_SHRINK_END

	for child:Button in choice_container.get_children():
		var prev := child.get_parent().get_child(wrap(child.get_index()-1, 0, choice_container.get_child_count()-1)).get_path()
		var next := child.get_parent().get_child(wrap(child.get_index()+1, 0, choice_container.get_child_count()-1)).get_path()
		child.focus_next = next
		child.focus_previous = prev
		child.focus_neighbor_left = prev
		child.focus_neighbor_top = prev
		child.focus_neighbor_right = next
		child.focus_neighbor_bottom = next

func get_speaker_canvas_position() -> Vector2:
	if is_instance_valid(node_to_point_at):
		if node_to_point_at is Node3D:
			base_position = get_viewport().get_camera_3d().unproject_position(
				(node_to_point_at as Node3D).global_position)
		if node_to_point_at is CanvasItem:
			base_position = (node_to_point_at as CanvasItem).get_global_transform_with_canvas().origin
	return base_position

func change_mouse_filter(filter: Control.MouseFilter) -> void:
	# 修复参数名冲突，添加空值检查
	if is_instance_valid(text):
		text.mouse_filter = filter
