extends Node2D

@onready var animation_player = $AnimationPlayer
@onready var sprite = $Sprite2D

func _ready():
	# 设置显示模式，防止撕裂
	setup_display_mode()
	
	# 等待一帧确保所有节点都加载完成
	await get_tree().process_frame
	
	# 播放动画
	play_loading_animation()

func setup_display_mode():
	# 获取主窗口
	var window = get_tree().root
	
	# 设置垂直同步以防止撕裂
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	
	# 设置全屏模式
	# 方法1：独占全屏（无边框，但可能有撕裂）
	# window.mode = Window.MODE_FULLSCREEN
	
	# 方法2：窗口最大化全屏（通常无撕裂，但可能有状态栏）
	# window.mode = Window.MODE_WINDOWED
	
	# 方法3：无边框窗口全屏
	window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	
	# 设置帧率限制
	Engine.max_fps = 60
	
	# 设置窗口大小与屏幕匹配
	# window.size = DisplayServer.screen_get_size()

func play_loading_animation():
	if animation_player:
		if animation_player.has_animation("new_animation"):
			animation_player.play("new_animation")
			print("开始播放加载动画")
	else:
		print("错误：AnimationPlayer节点不存在")
