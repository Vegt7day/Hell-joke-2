extends Node2D

# 导出变量
@export var stats: Stats
@export var auto_initialize: bool = true  # 是否自动初始化
@export var max_retry_count: int = 10  # 最大重试次数
@export var retry_delay: float = 0.1  # 重试延迟（秒）
@onready var sprite_2d: Sprite2D = $Sprite2D


# 节点引用
@onready var health_bar: TextureProgressBar = $healthbar

# 状态变量
var is_initialized: bool = false
var retry_count: int = 0
var is_visible: bool = true
var _health_tween: Tween = null

@export var drop_tween_duration: float = 0.45
@export var heal_tween_duration: float = 0.2

func _ready() -> void:
	# 如果启用自动初始化，则开始初始化
	if auto_initialize:
		call_deferred("initialize_with_retry")

func initialize_with_retry():
	"""带重试机制的初始化函数"""
	if is_initialized:
		return
	
	# 检查stats是否有效
	if stats and stats is Stats:
		_initialize_stats_success()
		return
	
	# 如果stats为null，尝试查找
	if not stats:
		_find_stats_node()
	
	# 如果仍然为null，并且还有重试次数
	if (not stats or not stats is Stats) and retry_count < max_retry_count:
		retry_count += 1
		print("尝试初始化stats，第", retry_count, "次尝试，stats:", stats)
		
		# 延迟后重试
		await get_tree().create_timer(retry_delay).timeout
		initialize_with_retry()
		return
	
	# 如果达到最大重试次数仍然失败
	if retry_count >= max_retry_count:
		push_error("初始化stats失败，已达到最大重试次数", max_retry_count)
		print("错误: stats 仍然为 null，请检查节点引用")

func _initialize_stats_success():
	"""成功初始化stats"""
	if not stats or not stats is Stats:
		return
	
	# 连接健康变化信号
	if not stats.health_changed.is_connected(update_health):
		stats.health_changed.connect(update_health)
	
	# 更新血条显示
	update_health()
	
	is_initialized = true
	print("Boss血条初始化成功，当前生命值:", stats.health, "/", stats.max_health)

func _find_stats_node():
	"""查找stats节点"""
	# 在父节点中查找
	if not stats and get_parent():
		# 查找父节点中的Stats节点
		for child in get_parent().get_children():
			if child is Stats:
				stats = child
				print("找到Stats节点:", child.name)
				break
	# 主马等：Stats 在 CharacterBody2D 根上，血条在 CanvasLayer 子树下
	if not stats and get_parent() != null and get_parent().get_parent() != null:
		var horse_root := get_parent().get_parent()
		var st := horse_root.get_node_or_null("Stats") as Stats
		if st != null:
			stats = st
			print("找到Stats节点(马根):", st.name)
	
	# 在场景中查找
	if not stats:
		var all_stats = get_tree().get_nodes_in_group("stats")
		if all_stats.size() > 0:
			stats = all_stats[0] as Stats
			print("通过组找到Stats节点")

func update_health() -> void:
	"""更新血条显示"""
	if not stats or not health_bar:
		return
	
	# 计算生命值百分比
	var percentage: float = stats.health / float(stats.max_health)
	
	# 确保百分比在0-1范围内
	percentage = clamp(percentage, 0.0, 1.0)
	var from_value: float = health_bar.value
	if _health_tween != null and is_instance_valid(_health_tween):
		_health_tween.kill()
	var duration: float = drop_tween_duration if percentage < from_value else heal_tween_duration
	duration = maxf(duration, 0.01)
	_health_tween = create_tween()
	_health_tween.tween_property(health_bar, "value", percentage, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	

func initialize_stats() -> void:
	"""外部调用初始化stats（兼容原有函数）"""
	if is_initialized:
		print("血条已经初始化")
		return
	
	call_deferred("initialize_with_retry")

func set_stats(new_stats: Stats):
	"""设置stats节点"""
	# 断开旧信号的连接
	if stats and stats.health_changed.is_connected(update_health):
		stats.health_changed.disconnect(update_health)
	
	# 设置新的stats
	stats = new_stats
	
	# 重新初始化
	if stats:
		_initialize_stats_success()
	else:
		print("设置了一个空的stats节点")

func get_current_health() -> float:
	"""获取当前生命值"""
	if not stats:
		return 0.0
	return stats.health

func get_max_health() -> float:
	"""获取最大生命值"""
	if not stats:
		return 0.0
	return stats.max_health

func get_health_percentage() -> float:
	"""获取生命值百分比"""
	if not stats or not stats.max_health:
		return 0.0
	return stats.health / float(stats.max_health)

func show_health_bar():
	"""显示血条"""
	sprite_2d.visible = true

	health_bar.visible = true
	is_visible = true


func hide_health_bar():

	health_bar.visible = false
	is_visible = false
	print("隐藏Boss血条")
	sprite_2d.visible = false

func toggle_health_bar():
	"""切换血条显示状态"""
	if health_bar:
		health_bar.visible = not health_bar.visible
		is_visible = health_bar.visible
		print("切换Boss血条显示状态:", "显示" if is_visible else "隐藏")

func is_health_bar_visible() -> bool:
	"""检查血条是否可见"""
	return is_visible

func reset_health_bar():
	"""重置血条"""
	if stats and health_bar:
		update_health()
		print("血条已重置")

func get_stats_node() -> Stats:
	"""获取stats节点引用"""
	return stats

func is_initialized_successfully() -> bool:
	"""检查是否成功初始化"""
	return is_initialized

func _exit_tree():
	"""节点退出场景时清理"""
	# 断开信号连接
	if stats and stats.health_changed.is_connected(update_health):
		stats.health_changed.disconnect(update_health)
	
	print("Boss血条节点清理完成")
