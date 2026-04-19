extends Area2D

# 触发器组别
@export var trigger_group: String = "default"  # 触发器所属组别
@export var trigger_delay: float = 0.0  # 触发延迟（秒）
@export var reset_delay: float = 0.0  # 重置延迟（秒），0表示不重置
@export var trigger_once: bool = false  # 是否只触发一次
@export var debug_mode: bool = true  # 调试模式

# 陷阱节点引用
@export var target_traps: Array[NodePath] = []  # 目标陷阱节点路径
@export var trap_group_to_trigger: String = ""  # 要触发的陷阱组别（如果设置了，会触发同组所有陷阱）

# 节点引用
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var debug_label: Label = $DebugLabel if has_node("DebugLabel") else null

# 状态变量
var is_triggered: bool = false
var is_resetting: bool = false
var bodies_in_area: Array = []
var cached_traps: Array = []  # 缓存的陷阱节点

func _ready():
	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	# 初始化目标陷阱
	_initialize_target_traps()
	
	# 设置调试标签
	if debug_label:
		debug_label.text = "触发器\n组别: " + trigger_group
		if trap_group_to_trigger != "":
			debug_label.text += "\n触发陷阱组: " + trap_group_to_trigger
		debug_label.text += "\n陷阱数: " + str(cached_traps.size())
		debug_label.visible = debug_mode
	else:
		print("未找到DebugLabel节点，调试标签将不可用")
	
	print("陷阱触发器初始化完成: ", name, " (组别: ", trigger_group, ")")
	print("目标陷阱数: ", cached_traps.size())
	if trap_group_to_trigger != "":
		print("将触发陷阱组: ", trap_group_to_trigger)

func _process(delta):
	# 调试模式下更新标签
	if debug_mode and debug_label and bodies_in_area.size() > 0:
		debug_label.text = "触发器\n组别: " + trigger_group
		if trap_group_to_trigger != "":
			debug_label.text += "\n触发陷阱组: " + trap_group_to_trigger
		debug_label.text += "\n陷阱数: " + str(cached_traps.size())
		debug_label.text += "\n物体数: " + str(bodies_in_area.size())
	elif debug_mode and debug_label:
		debug_label.text = "触发器\n组别: " + trigger_group
		if trap_group_to_trigger != "":
			debug_label.text += "\n触发陷阱组: " + trap_group_to_trigger
		debug_label.text += "\n陷阱数: " + str(cached_traps.size())

func _initialize_target_traps():
	"""初始化目标陷阱"""
	cached_traps.clear()
	
	# 处理通过节点路径指定的陷阱
	for trap_path in target_traps:
		var trap = get_node_or_null(trap_path)
		if trap and trap.has_method("trigger_trap"):
			if not cached_traps.has(trap):
				cached_traps.append(trap)
				print("添加目标陷阱: ", trap.name)
		elif trap:
			print("警告：节点不是陷阱或缺少trigger_trap方法: ", trap.name)
	
	# 处理通过组别指定的陷阱
	if trap_group_to_trigger != "":
		var group_traps = _get_traps_by_group(trap_group_to_trigger)
		for trap in group_traps:
			if trap and trap.has_method("trigger_trap"):
				if not cached_traps.has(trap):
					cached_traps.append(trap)
					print("通过组别添加陷阱: ", trap.name, " (组别: ", trap_group_to_trigger, ")")
	
	print("总共找到 ", cached_traps.size(), " 个陷阱")

func _get_traps_by_group(group_name: String) -> Array:
	"""根据组别获取陷阱节点"""
	var traps_in_group = []
	
	# 遍历场景中的所有节点，查找符合组别的陷阱
	var all_nodes = get_tree().get_nodes_in_group("traps")
	for node in all_nodes:
		if node.has_method("get_trap_group") and node.get_trap_group() == group_name:
			traps_in_group.append(node)
	
	# 如果没有分组，则通过名称查找
	if traps_in_group.size() == 0:
		_find_traps_by_group_recursive(get_tree().current_scene, group_name, traps_in_group)
	
	return traps_in_group

func _find_traps_by_group_recursive(node: Node, group_name: String, result: Array):
	"""递归查找符合组别的陷阱"""
	if node.has_method("get_trap_group") and node.get_trap_group() == group_name:
		if not result.has(node):
			result.append(node)
	
	for child in node.get_children():
		_find_traps_by_group_recursive(child, group_name, result)

func _on_body_entered(body: Node2D):
	"""物理体进入区域"""
	_handle_entered(body, "物体")

func _on_area_entered(area: Area2D):
	"""区域进入"""
	_handle_entered(area, "区域")

func _on_body_exited(body: Node2D):
	"""物理体离开区域"""
	_handle_exited(body, "物体")

func _on_area_exited(area: Area2D):
	"""区域离开"""
	_handle_exited(area, "区域")

func _handle_entered(node: Node, type: String):
	"""处理进入事件"""
	print(type, "进入触发器区域: ", node.name, " (触发器: ", name, ", 组别: ", trigger_group, ")")
	
	# 添加到进入物体列表
	if not bodies_in_area.has(node):
		bodies_in_area.append(node)
	
	# 触发陷阱
	if not is_triggered or not trigger_once:
		_trigger_traps()

func _handle_exited(node: Node, type: String):
	"""处理离开事件"""
	print(type, "离开触发器区域: ", node.name, " (触发器: ", name, ", 组别: ", trigger_group, ")")
	
	# 从进入物体列表中移除
	if bodies_in_area.has(node):
		bodies_in_area.erase(node)
	
	# 如果没有物体在区域中，可以重置触发器
	if bodies_in_area.size() == 0 and reset_delay > 0 and not is_resetting:
		_start_reset_timer()

func _trigger_traps():
	"""触发所有目标陷阱"""
	if is_triggered and trigger_once:
		print("触发器已触发过且设置为一次性触发，跳过: ", name)
		return
	
	print("触发器开始触发陷阱: ", name, " (组别: ", trigger_group, ")")
	is_triggered = true
	
	# 如果有触发延迟，等待
	if trigger_delay > 0:
		print("等待 ", trigger_delay, " 秒后触发陷阱")
		await get_tree().create_timer(trigger_delay).timeout
	
	# 触发所有缓存的陷阱
	var triggered_count = 0
	for trap in cached_traps:
		if is_instance_valid(trap) and trap.has_method("trigger_trap"):
			trap.trigger_trap()
			triggered_count += 1
			print("已触发陷阱: ", trap.name)
		else:
			print("警告：无效陷阱或缺少trigger_trap方法: ", trap.name if is_instance_valid(trap) else "无效")
	
	print("总共触发了 ", triggered_count, " 个陷阱")
	
	# 如果设置为触发一次，禁用触发器
	if trigger_once:
		print("触发器设置为一次性触发，已禁用: ", name)
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		if collision_shape:
			collision_shape.set_deferred("disabled", true)

func _start_reset_timer():
	"""启动重置计时器"""
	if reset_delay <= 0 or is_resetting:
		return
	
	print("启动重置计时器，", reset_delay, " 秒后重置触发器: ", name)
	is_resetting = true
	
	await get_tree().create_timer(reset_delay).timeout
	
	_reset_trigger()

func _reset_trigger():
	"""重置触发器"""
	print("重置触发器: ", name, " (组别: ", trigger_group, ")")
	
	is_triggered = false
	is_resetting = false
	
	# 重新初始化陷阱（以防场景变化）
	_initialize_target_traps()
	
	# 重新启用触发器
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	
	print("触发器已重置，可以再次触发: ", name)

func enable_trigger():
	"""启用触发器"""
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	
	print("触发器已启用: ", name)

func disable_trigger():
	"""禁用触发器"""
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	print("触发器已禁用: ", name)

func get_trigger_group() -> String:
	"""获取触发器组别"""
	return trigger_group

func set_trigger_group(new_group: String):
	"""设置触发器组别"""
	trigger_group = new_group
	if debug_label:
		debug_label.text = "触发器\n组别: " + trigger_group
		if trap_group_to_trigger != "":
			debug_label.text += "\n触发陷阱组: " + trap_group_to_trigger
		debug_label.text += "\n陷阱数: " + str(cached_traps.size())
	
	print("触发器组别已更新为: ", trigger_group)

func set_trap_group_to_trigger(new_group: String):
	"""设置要触发的陷阱组别"""
	trap_group_to_trigger = new_group
	_initialize_target_traps()  # 重新初始化目标陷阱
	
	if debug_label:
		debug_label.text = "触发器\n组别: " + trigger_group
		if trap_group_to_trigger != "":
			debug_label.text += "\n触发陷阱组: " + trap_group_to_trigger
		debug_label.text += "\n陷阱数: " + str(cached_traps.size())
	
	print("要触发的陷阱组别已更新为: ", trap_group_to_trigger)

func add_target_trap(trap_path: NodePath):
	"""添加目标陷阱"""
	if not target_traps.has(trap_path):
		target_traps.append(trap_path)
		_initialize_target_traps()  # 重新初始化目标陷阱
		print("已添加目标陷阱路径: ", trap_path)

func remove_target_trap(trap_path: NodePath):
	"""移除目标陷阱"""
	if target_traps.has(trap_path):
		target_traps.erase(trap_path)
		_initialize_target_traps()  # 重新初始化目标陷阱
		print("已移除目标陷阱路径: ", trap_path)

func clear_target_traps():
	"""清空目标陷阱"""
	target_traps.clear()
	_initialize_target_traps()  # 重新初始化目标陷阱
	print("已清空所有目标陷阱")

func is_activated() -> bool:
	"""检查触发器是否已激活"""
	return is_triggered

func get_target_trap_count() -> int:
	"""获取目标陷阱数量"""
	return cached_traps.size()
