@tool
extends DialogicLayoutBase

var bubbles: Array = []
var registered_characters: Dictionary = {}

@export_group("Main")
@export_range(1, 25, 1) var bubble_count: int = 2

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	print("=== Dialogic气泡布局初始化 ===")
	
	DialogicUtil.autoload().Text.about_to_show_text.connect(_on_dialogic_text_event)
	
	# 检查是否有Example节点
	if has_node("Example") and has_node("Example/CRT"):
		$Example/CRT.position = $Example.get_viewport_rect().size/2

	if not has_node("TextBubbleLayer"):
		printerr("[Dialogic] TextBubbleLayer 节点不存在！")
		return

	if len(bubbles) < bubble_count:
		add_bubble()
	
	# 等待一帧确保节点完全初始化
	await get_tree().process_frame
	
	# 从全局注册表加载角色
	load_characters_from_registry()

func load_characters_from_registry() -> void:
	print("=== 从全局注册表加载角色 ===")
	
	# 给注册表更多时间初始化
	await get_tree().create_timer(0.1).timeout
	
	# 通过自动加载节点路径获取注册器
	var registry = get_node_or_null("/root/DialogicRegistry")
	if registry and registry.has_method("get_character_node"):
		print("DialogicRegistry找到，开始加载角色...")
		
		# 尝试加载学生角色
		var student_node = registry.get_character_node("中学生")
		if student_node and is_instance_valid(student_node):
			var student_resource = registry.get_character_resource("中学生")
			if student_resource and ResourceLoader.exists(student_resource):
				var resource = load(student_resource)
				if resource:
					registered_characters[resource] = student_node
					print("✓ 从全局注册表加载学生角色: ", student_resource)
				else:
					print("✗ 无法加载学生角色资源: ", student_resource)
			else:
				# 尝试通过Dialogic资源工具获取
				student_resource = DialogicResourceUtil.get_character_resource("中学生")
				if student_resource:
					registered_characters[student_resource] = student_node
					print("✓ 通过DialogicResourceUtil加载学生角色")
		else:
			print("✗ 学生角色未注册或节点无效")
		
		# 尝试加载教师角色
		var teacher_node = registry.get_character_node("老教师")
		if teacher_node and is_instance_valid(teacher_node):
			var teacher_resource = registry.get_character_resource("老教师")
			if teacher_resource and ResourceLoader.exists(teacher_resource):
				var resource = load(teacher_resource)
				if resource:
					registered_characters[resource] = teacher_node
					print("✓ 从全局注册表加载教师角色: ", teacher_resource)
				else:
					print("✗ 无法加载教师角色资源: ", teacher_resource)
			else:
				# 尝试通过Dialogic资源工具获取
				teacher_resource = DialogicResourceUtil.get_character_resource("老教师")
				if teacher_resource:
					registered_characters[teacher_resource] = teacher_node
					print("✓ 通过DialogicResourceUtil加载教师角色")
		else:
			print("✗ 教师角色未注册或节点无效")
		
		print("=== 角色加载结果 ===")
		print("已注册角色数量: ", registered_characters.size())
		for char_res in registered_characters:
			var node = registered_characters[char_res]
			print("  - ", char_res, " -> ", node.get_path())
		
		if len(registered_characters) == 0:
			print("警告：没有成功加载任何角色，将使用备用方法")
			register_characters_directly()
	else:
		print("警告：全局注册表不可用，尝试备用注册方法")
		register_characters_directly()

func register_characters_directly() -> void:
	print("=== 尝试直接注册角色 ===")
	
	# 尝试通过组名或节点路径直接查找角色
	var student = get_tree().get_first_node_in_group("player")
	var teacher = get_tree().get_first_node_in_group("teacher")
	
	if student:
		var student_resource = DialogicResourceUtil.get_character_resource("中学生")
		if student_resource:
			registered_characters[student_resource] = student
			print("✓ 直接注册学生角色: ", student.get_path())
	
	if teacher:
		var teacher_resource = DialogicResourceUtil.get_character_resource("老教师")
		if teacher_resource:
			registered_characters[teacher_resource] = teacher
			print("✓ 直接注册教师角色: ", teacher.get_path())
	
	# 如果没有找到，尝试通过Dialogic默认角色
	if len(registered_characters) == 0:
		print("警告：无法直接找到任何角色节点")

func register_character(character: Variant, node: Node) -> bool:
	if typeof(character) == TYPE_STRING:
		var character_string: String = character
		if "://" in character:
			character = load(character)
		else:
			character = DialogicResourceUtil.get_character_resource(character_string)
		
		if not character:
			printerr("[Dialogic] Textbubble: 尝试从未知字符串注册角色: '", character_string, "'")
			return false
	
	registered_characters[character] = node
	print("[Dialogic] 注册角色: ", character, " 节点: ", node.name)
	
	if len(registered_characters) > len(bubbles) and len(bubbles) < bubble_count:
		add_bubble()
	
	return true

# 清理所有无效的节点引用
func cleanup_invalid_references() -> void:
	var characters_to_remove = []
	
	for character in registered_characters:
		var node = registered_characters[character]
		if not is_instance_valid(node):
			characters_to_remove.append(character)
	
	for character in characters_to_remove:
		registered_characters.erase(character)
		print("[Dialogic] 清理无效的角色引用: ", character)

func _get_persistent_info() -> Dictionary:
	return {}

func _load_persistent_info(info: Dictionary) -> void:
	pass

func add_bubble() -> void:
	if not has_node("TextBubbleLayer"):
		printerr("[Dialogic] TextBubbleLayer 节点不存在，无法添加气泡")
		return

	var text_bubble_layer = get_node("TextBubbleLayer")
	if not text_bubble_layer or not is_instance_valid(text_bubble_layer):
		printerr("[Dialogic] TextBubbleLayer 节点无效")
		return
	
	if not text_bubble_layer.has_method("add_bubble"):
		printerr("[Dialogic] TextBubbleLayer 没有 add_bubble 方法")
		return
	
	var new_bubble: Control = text_bubble_layer.add_bubble()
	
	if not new_bubble or not is_instance_valid(new_bubble):
		printerr("[Dialogic] 无法创建气泡节点")
		return
	
	if new_bubble.is_inside_tree():
		print("[Dialogic] 气泡已在场景树中")
	else:
		# 确保气泡被添加到场景树
		if not is_inside_tree():
			await get_tree().process_frame
		
		if is_inside_tree():
			add_child(new_bubble)
		else:
			printerr("[Dialogic] 布局层不在场景树中")
			return
	
	bubbles.append(new_bubble)
	
	print("[Dialogic] 成功添加气泡，当前气泡数量:", len(bubbles))

func _on_dialogic_text_event(info: Dictionary):
	if Engine.is_editor_hint():
		return
	
	print("=== 开始处理文本事件 ===")
	print("事件信息:", info)
	
	# 清理无效气泡
	var valid_bubbles = []
	for bubble in bubbles:
		if bubble and is_instance_valid(bubble):
			valid_bubbles.append(bubble)
		else:
			print("[Dialogic] 发现无效气泡，已从数组中移除")
	
	bubbles = valid_bubbles
	
	# 如果没有气泡，尝试添加一个
	if len(bubbles) == 0:
		print("[Dialogic] 没有可用气泡，尝试添加新气泡")
		add_bubble()
		if len(bubbles) == 0:
			printerr("[Dialogic] 无法创建任何气泡，无法显示文本")
			return
	
	# 清理无效的角色引用
	cleanup_invalid_references()
	
	var bubble_to_use: Node = null
	
	# 第一步：查找与当前角色匹配的气泡
	var current_character = info.get("character")
	if current_character:
		for bubble in bubbles:
			if bubble and is_instance_valid(bubble):
				var bubble_char = bubble.get("current_character")
				if bubble_char and is_instance_valid(bubble_char) and bubble_char == current_character:
					bubble_to_use = bubble
					print("[Dialogic] 找到匹配角色的气泡: ", current_character)
					break
	
	# 第二步：查找空闲气泡
	if not bubble_to_use:
		for bubble in bubbles:
			if bubble and is_instance_valid(bubble):
				var bubble_char = bubble.get("current_character")
				if not bubble_char or not is_instance_valid(bubble_char):
					bubble_to_use = bubble
					print("[Dialogic] 找到空闲气泡")
					break
	
	# 第三步：使用第一个有效气泡
	if not bubble_to_use and len(bubbles) > 0:
		for bubble in bubbles:
			if bubble and is_instance_valid(bubble):
				bubble_to_use = bubble
				print("[Dialogic] 使用第一个有效气泡")
				break
	
	if not bubble_to_use:
		printerr("[Dialogic] 错误：没有可用的气泡节点！")
		return
	
	print("[Dialogic] 选择气泡：", bubble_to_use.name)
	
	var node_to_point_at: Node = null
	
	# 检查角色是否已注册
	if info.has("character") and info.character is Resource:
		# 查找注册的角色节点
		for char_res in registered_characters:
			if char_res == info.character:
				node_to_point_at = registered_characters[char_res]
				if node_to_point_at and is_instance_valid(node_to_point_at):
					print("[Dialogic] 使用已注册角色节点: ", node_to_point_at.name)
					break
	
	# 如果还没有找到节点，尝试通过自动加载注册表查找
	if not node_to_point_at and current_character:
		var registry = get_node_or_null("/root/DialogicRegistry")
		if registry and registry.has_method("get_character_node"):
			var char_id = _get_character_id_from_resource(current_character)
			if char_id:
				node_to_point_at = registry.get_character_node(char_id)
				if node_to_point_at and is_instance_valid(node_to_point_at):
					print("[Dialogic] 通过注册表找到角色节点: ", char_id)
	
	# 如果还是没有找到，使用默认标记点
	if not node_to_point_at:
		if has_node("Example") and has_node("Example/CRT/Marker"):
			node_to_point_at = $Example/CRT/Marker
			if has_node("Example"):
				$Example.show()
			print("[Dialogic] 使用默认标记点")
		else:
			print("[Dialogic] 警告：无法找到任何标记点，气泡将显示在默认位置")
	
	# 设置气泡属性
	if node_to_point_at and is_instance_valid(node_to_point_at):
		if bubble_to_use.has_method("set_node_to_point_at"):
			bubble_to_use.set_node_to_point_at(node_to_point_at)
		elif "node_to_point_at" in bubble_to_use:
			bubble_to_use.node_to_point_at = node_to_point_at
		else:
			print("[Dialogic] 气泡没有node_to_point_at属性")
	else:
		print("[Dialogic] 警告：标记点无效，跳过设置")
	
	# 设置当前角色
	if info.has("character"):
		if bubble_to_use.has_method("set_current_character"):
			bubble_to_use.set_current_character(info.get("character"))
		elif "current_character" in bubble_to_use:
			bubble_to_use.current_character = info.get("character")
		print("[Dialogic] 设置角色成功")
	else:
		print("[Dialogic] 没有角色信息")
	
	# 重置气泡
	if bubble_to_use.has_method("reset"):
		if not bubble_to_use.visible:
			bubble_to_use.reset()
	
	# 应用样式覆盖
	if has_node("TextBubbleLayer"):
		get_node("TextBubbleLayer").call("bubble_apply_overrides", bubble_to_use)
	
	# 打开气泡
	if bubble_to_use.has_method("open"):
		bubble_to_use.open()
	
	# 关闭其他气泡
	for bubble in bubbles:
		if bubble and is_instance_valid(bubble) and bubble != bubble_to_use:
			if bubble.has_method("close"):
				bubble.close()
			# 清除角色引用
			if bubble.has_method("set_current_character"):
				bubble.set_current_character(null)
			elif bubble.has_property("current_character"):
				bubble.current_character = null
	
	print("=== 文本事件处理完成 ===")

func _get_character_id_from_resource(character_resource: Resource) -> String:
	# 尝试从角色资源获取ID
	if character_resource.has_method("get_character_name"):
		return character_resource.get_character_name()
	elif character_resource.has_property("display_name"):
		return character_resource.display_name
	elif character_resource.has_property("name"):
		return character_resource.name
	
	# 尝试从路径猜测
	var path = character_resource.resource_path
	if path:
		var filename = path.get_file()
		return filename.replace(".dch", "")
	
	return ""
