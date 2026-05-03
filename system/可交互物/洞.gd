extends StaticBody2D

# 陷阱组别
@export var trap_group: String = "default"  # 陷阱所属组别
@export var disable_collision_on_trigger: bool = true  # 触发时是否禁用碰撞
@export var one_time_trigger: bool = true  # 是否一次性触发
@export var reset_delay: float = 0.0  # 重置延迟（秒），0表示不重置
@export var trigger_sfx: AudioStream = preload("res://assets/资源总库/10_音频/jump.mp3")

# 节点引用
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# 状态变量
var is_triggered: bool = false
var is_collision_disabled: bool = false
var is_resetting: bool = false

func _ready():
	add_to_group("inspectable")
	# 确保Sprite2D使用正确的纹理
	if sprite:
		# 设置Sprite2D属性
		sprite.hframes = 5
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, 160, 32)
	
	# 重置动画状态
	reset_state()
	
	print("陷阱初始化完成: ", name, " (组别: ", trap_group, ")")

func reset_state():
	"""重置陷阱状态"""
	if animation_player and animation_player.has_animation("RESET"):
		animation_player.play("RESET")
	
	is_triggered = false
	is_collision_disabled = false
	is_resetting = false
	
	# 启用碰撞
	if collision_shape and is_collision_disabled:
		collision_shape.set_deferred("disabled", false)
		is_collision_disabled = false

func trigger_trap():
	"""触发陷阱"""
	if (one_time_trigger and is_triggered) or is_resetting:
		return
	
	print("触发陷阱: ", name, " (组别: ", trap_group, ")")
	
	is_triggered = true
	if is_instance_valid(Game):
		Game.mark_mechanism_observed("洞")
	# 播放触发动画
	if animation_player and animation_player.has_animation("触发"):
		_play_trigger_sound()
		animation_player.play("触发")
		print("播放触发动画")
	else:
		print("警告：未找到'触发'动画")
	
	# 禁用碰撞
	if disable_collision_on_trigger and collision_shape:
		collision_shape.set_deferred("disabled", true)
		is_collision_disabled = true
		print("陷阱碰撞已禁用")
	
	# 如果设置了重置延迟，延迟后重置陷阱
	if reset_delay > 0:
		is_resetting = true
		await get_tree().create_timer(reset_delay).timeout
		reset_state()

func enable_collision():
	"""启用碰撞"""
	if collision_shape and is_collision_disabled:
		collision_shape.disabled = false
		is_collision_disabled = false
		print("陷阱碰撞已启用")

func disable_collision():
	"""禁用碰撞"""
	if collision_shape and not is_collision_disabled:
		collision_shape.disabled = true
		is_collision_disabled = true
		print("陷阱碰撞已禁用")

func is_active() -> bool:
	"""检查陷阱是否激活（有碰撞）"""
	return not is_collision_disabled

func get_trap_group() -> String:
	"""获取陷阱组别"""
	return trap_group

func set_trap_group(new_group: String):
	"""设置陷阱组别"""
	trap_group = new_group
	print("陷阱组别已更新为: ", trap_group)

func _on_animation_finished(anim_name: String):
	"""动画播放完成回调"""
	if anim_name == "触发":
		print("陷阱触发动画完成: ", name)


func _play_trigger_sound() -> void:
	if trigger_sfx == null:
		return
	MechanismSfxBus.request_once(&"trap_trigger", trigger_sfx)


func _get_inspect_description() -> String:
	if not is_instance_valid(Game) or not Game.observed_mechanisms.get("洞", false):
		return "还未触发过该类型机关"
	return "可疑的土地" + ("（尚未触发）" if not is_triggered else "（已触发）")
