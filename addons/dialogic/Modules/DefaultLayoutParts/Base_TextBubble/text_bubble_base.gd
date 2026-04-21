@tool
extends DialogicLayoutBase

## This layout won't do anything on its own

var bubbles: Array = []
var registered_characters: Dictionary = {}

@export_group("Main")
@export_range(1, 25, 1) var bubble_count: int = 2

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	DialogicUtil.autoload().Text.about_to_show_text.connect(_on_dialogic_text_event)
	
	# 检查是否有Example节点
	if has_node("Example") and has_node("Example/CRT"):
		$Example/CRT.position = $Example.get_viewport_rect().size/2

	if not has_node("TextBubbleLayer"):
		printerr("[Dialogic] TextBubbleLayer 节点不存在！")
		return

	if len(bubbles) < bubble_count:
		add_bubble()

func register_character(character:Variant, node:Node):
	if typeof(character) == TYPE_STRING:
		var character_string: String = character
		if "://" in character:
			character = load(character)
		else:
			character = DialogicResourceUtil.get_character_resource(character)
		if not character:
			printerr("[Dialogic] Textbubble: Tried registering character from invalid string '", character_string, "'.")

	registered_characters[character] = node
	if len(registered_characters) > len(bubbles) and len(bubbles) < bubble_count:
		add_bubble()

func _get_persistent_info() -> Dictionary:
	return {"textbubble_registers": registered_characters}

func _load_persistent_info(info: Dictionary) -> void:
	var register_info: Dictionary = info.get("textbubble_registers", {})
	for character in register_info:
		if is_instance_valid(register_info[character]):
			register_character(character, register_info[character])

func add_bubble() -> void:
	if not has_node("TextBubbleLayer"):
		printerr("[Dialogic] TextBubbleLayer 节点不存在，无法添加气泡")
		return

	var text_bubble_layer = get_node("TextBubbleLayer")
	var new_bubble: Control = text_bubble_layer.add_bubble()
	
	# 检查是否成功添加气泡
	if not new_bubble or not is_instance_valid(new_bubble):
		printerr("[Dialogic] 无法创建气泡节点")
		return
	
	# 检查气泡是否已经在场景树中
	if new_bubble.is_inside_tree():
		print("[Dialogic] 警告：气泡已在场景树中，不需要重复添加")
		# 仍然添加到气泡数组，但不再添加为子节点
		bubbles.append(new_bubble)
		print("[Dialogic] 已注册气泡，当前气泡数量:", len(bubbles))
		return
	
	# 检查气泡是否已经有父节点
	if new_bubble.get_parent():
		print("[Dialogic] 警告：新气泡已有父节点，正在移除父节点")
		var parent = new_bubble.get_parent()
		parent.remove_child(new_bubble)
	
	# 确保布局层在场景树中
	if not is_inside_tree():
		printerr("[Dialogic] 错误：布局层不在场景树中")
		return
	
	# 添加到当前布局层
	add_child(new_bubble)
	
	# 添加到气泡数组
	bubbles.append(new_bubble)
	
	print("[Dialogic] 成功添加气泡，当前气泡数量:", len(bubbles))

func _on_dialogic_text_event(info:Dictionary):
	if Engine.is_editor_hint():
		return
	
	print("=== 开始处理文本事件 ===")
	print("事件信息:", info)
	
	# 清理无效的气泡
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
	
	var bubble_to_use: Node = null
	
	# 第一步：查找与当前角色匹配的气泡
	for bubble in bubbles:
		if bubble and is_instance_valid(bubble):
			# 安全访问 current_character
			var char = bubble.get("current_character")
			if char and is_instance_valid(char) and char == info.get("character"):
				bubble_to_use = bubble
				print("[Dialogic] 找到匹配角色的气泡")
				break
		else:
			print("[Dialogic] 发现无效气泡，跳过")
	
	# 第二步：如果没有找到，查找空闲气泡
	if not bubble_to_use:
		for bubble in bubbles:
			if bubble and is_instance_valid(bubble):
				var char = bubble.get("current_character")
				if not char or not is_instance_valid(char):
					bubble_to_use = bubble
					print("[Dialogic] 找到空闲气泡")
					break
			else:
				print("[Dialogic] 发现无效气泡，跳过")
	
	# 第三步：如果还没有找到，使用第一个有效气泡
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
	if info.has("character") and info.character in registered_characters:
		node_to_point_at = registered_characters[info.character]
		if has_node("Example"):
			$Example.hide()
		print("[Dialogic] 使用已注册角色节点")
	else:
		# 使用默认标记点
		if has_node("Example") and has_node("Example/CRT/Marker"):
			node_to_point_at = $Example/CRT/Marker
			if has_node("Example"):
				$Example.show()
			print("[Dialogic] 使用默认标记点")
		else:
			printerr("[Dialogic] 无法找到默认标记点")
	
	# 设置气泡属性
	if node_to_point_at:
		bubble_to_use.set("node_to_point_at", node_to_point_at)
	
	# 设置当前角色
	if info.has("character"):
		bubble_to_use.set("current_character", info.get("character"))
		print("[Dialogic] 设置角色成功")
	else:
		print("[Dialogic] 没有角色信息")
	
	# 重置气泡
	if not bubble_to_use.visible:
		bubble_to_use.call("reset")
	
	# 应用样式覆盖
	if has_node("TextBubbleLayer"):
		get_node("TextBubbleLayer").call("bubble_apply_overrides", bubble_to_use)
	
	# 打开气泡
	bubble_to_use.call("open")
	
	# 关闭其他气泡
	for bubble in bubbles:
		if bubble and is_instance_valid(bubble) and bubble != bubble_to_use:
			bubble.call("close")
			# 清除角色引用
			bubble.set("current_character", null)
	
	print("=== 文本事件处理完成 ===")
