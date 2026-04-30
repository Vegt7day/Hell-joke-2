extends Node
## 血量阶段、入场 Timeline、20% 商鞅分支、五马同场调度。
## 设计见 `Docs/更新文档/11-World3-Boss马战设计.md`。

signal phase_changed(new_phase: BossHorseTypes.BossPhase)
signal shared_health_changed(current_health: int, max_health: int, hp_percent: float)
signal shared_health_depleted
signal intro_timeline_finished
## 心剑交互后进入「马开始战斗」时间线或读档强制进战时：Boss 场切战斗 BGM（由 `world3_boss_arena` 监听）。
signal boss_combat_bgm_requested

## 相对本节点（`World3BossArena/Systems/PhaseController`）
@export var main_horse_path: NodePath = NodePath("../../Bosses/MainHorse")
@export var boss_si_path: NodePath = NodePath("../../Bosses/BossSi")
@export var minors_path: NodePath = NodePath("../../Bosses/Minors")
@export var grey_spawn_path: NodePath = NodePath("../../Bosses/SpawnMarkers/GreySpawn")
@export var main_horse_spawn_path: NodePath = NodePath("../../Bosses/SpawnMarkers/MainHorseSpawn")
@export var dynamic_minor_scene: PackedScene = preload("res://system/levels/world3/bosses/boss_horse_minor.tscn")
@export var use_dynamic_minor_spawn: bool = true

@export var main_skill_shared_cooldown: float = 10.0

## 入场：先从右侧场外平移入场，再执行驷分裂离场
@export var intro_main_entry_offset: Vector2 = Vector2(520, 0)
@export var intro_si_entry_offset: Vector2 = Vector2(640, 0)
@export var intro_entry_duration: float = 1.1
@export var intro_main_jump_beat_seconds: float = 0.25
@export var si_exit_screen_offset: Vector2 = Vector2(-1400, 0)
## 驷马沿 offset 离场 tween 时长；调短以加快离场后战斗衔接。
@export var si_exit_duration: float = 1.2
## 主马/驷马离场速度（像素/秒），按此速度移动到刚出摄像头范围即停
@export var si_main_exit_speed: float = 400.0
@export var si_main_exit_margin: float = 64.0
@export var grey_entry_offset: Vector2 = Vector2(-420, 0)

## 换马流程：当前马先离场，下一匹从临近侧回场（当前用平移模拟小跳前进）
@export var horse_switch_exit_offset: Vector2 = Vector2(360, 0)
@export var horse_switch_entry_offset: Vector2 = Vector2(280, 0)
@export var horse_switch_duration: float = 0.35
@export var skip_intro_timeline: bool = false
@export var shangyang_path: NodePath = NodePath("../../Bosses/ShangYang")
## 对话气泡「商鞅」锚点；预警期可追踪召唤体。场景 `World3BossArena` 下默认 `Systems/ShangYangDialogProxy`。
@export var shangyang_dialog_proxy_path: NodePath = NodePath("../ShangYangDialogProxy")
@export var ropes_root_path: NodePath = NodePath("../../Bosses/PropsSpawn/RopesRoot")
@export var rope_scene: PackedScene = preload("res://system/levels/world3/props/rope_to_shangyang.tscn")
@export var shangyang_limb_scene: PackedScene = preload("res://system/levels/world3/props/shangyang_limb_piece.tscn")
@export var fatal_warning_scene: PackedScene = preload("res://system/levels/world3/ui/boss_fatal_warning.tscn")
@export var limb_outscreen_margin: float = 220.0
## 沿拖拽方向移动的距离（世界单位），需足够大以移出摄像机视野。
@export var limb_pull_travel_distance: float = 920.0
## 20% 演出：不在场的马回到场内（Tween 时长）
@export var final_warn_horse_entry_duration: float = 0.9
## 从各自出生点沿「远离商鞅」方向外推的起始距离（再 tween 回出生点附近）
@export var final_warn_entry_push_distance: float = 520.0
## 绳子从 0 连到肢体的时长
@export var final_warn_rope_extend_seconds: float = 2.0
## 绳连上后的静止停顿
@export var final_warn_pause_after_rope_seconds: float = 1.0
## 绳索完全伸长扣住肢体后，给玩家的屏幕提示（`Systems/UIHints/RopeLimbHint`）
@export var rope_limb_hint_label_path: NodePath = NodePath("../UIHints/RopeLimbHint")
@export var rope_contact_hint_shangyang: String = "绳索已锁住商鞅的四肢。\n接下来将进入剧情对话。"
@export var rope_contact_hint_player: String = "绳索已缚紧……"
@export var rope_contact_hint_duration: float = 2.8
## 阶段切换时的提示（如「灰马进入了直播间」）
@export var phase_enter_hint_label_path: NodePath = NodePath("../UIHints/PhaseEnterHint")
@export var phase_enter_hint_duration: float = 1.8
## 马开始向外走后，延迟多久肢体才开始被拖动（秒）
@export var final_warn_limb_follow_delay_seconds: float = 1.0
## 马被拖出屏幕的总时长（肢体 tween 时长 = 该值 - 延迟，与马同时结束）
@export var final_warn_horse_pull_duration: float = 4.2
## 商鞅分尸演出结束后，五马从场外 tween 回出生点位的时长
@export var finale_rally_after_pull_duration: float = 1.0
## Boss 血量归零时五马四散逃离
@export var scatter_flee_duration: float = 1.15
@export var scatter_flee_distance: float = 760.0
## 无商鞅、五马拉玩家时：绳末端相对主角根节点的本地偏移（顺序同 `_get_five_horses_ordered`：主马、灰、白、黑、红）。
@export var player_fatal_rope_end_offset_0: Vector2 = Vector2(12, 2-32)
@export var player_fatal_rope_end_offset_1: Vector2 = Vector2(15, 26-32)
@export var player_fatal_rope_end_offset_2: Vector2 = Vector2(24, 15-32)
@export var player_fatal_rope_end_offset_3: Vector2 = Vector2(9, 15-32)
@export var player_fatal_rope_end_offset_4: Vector2 = Vector2(18, 2-32)
## 20% 致命拉扯：五马先冲到目标（玩家/商鞅）周围该半径（像素）再连绳
@export var fatal_pull_surround_radius_px: float = 96.0
@export var fatal_pull_surround_rush_duration: float = 0.85
## 商鞅线：伸绳期间摄像机（玩家子节点 Camera2D）缓慢移向商鞅的时长；与绳伸长并行
@export var camera_pull_duration_seconds: float = 1.0
@export var camera_return_duration_seconds: float = 0.5
## 商鞅最后对话结束后，给镜头回归的最短等待时长
@export var final_dialog_camera_return_wait_seconds: float = 0.4
## 五马拉商鞅：围拢/镜头锚点相对商鞅根坐标的偏移（右 +X，上 -Y）
@export var fatal_sy_pull_horses_anchor_offset: Vector2 = Vector2(32, -32)

var current_phase: BossHorseTypes.BossPhase = BossHorseTypes.BossPhase.INTRO

var _main_stats: Stats
var _phase_logged_once: Dictionary = {}
var _intro_done: bool = false
var _is_switching_minor: bool = false
var _active_minor_name: StringName = &"MinorGrey"
var _queued_target_phase: BossHorseTypes.BossPhase = BossHorseTypes.BossPhase.INTRO
var _final_warning_sequence_started: bool = false
var _summoned_sy_during_warning: Node2D = null
var _fatal_warning_watch_active: bool = false
## 致命序列：预警开始前或预警 UI 期间场上曾存在可识别的商鞅（静态路径/召唤组），用于放宽「走商鞅分尸时间线」判定。
var _fatal_sy_seen_before_or_during_warning: bool = false
## 预警期间召唤商鞅时预生成的肢体（到连绳时复用）
var _warning_spawned_limbs: Array[Node2D] = []
var _relimb_timeline_started: bool = false
var _pending_minor_switch_phase: BossHorseTypes.BossPhase = BossHorseTypes.BossPhase.INTRO
var _external_damage_busy: bool = false
var _queued_external_damage_percent: float = 0.2
var _queued_external_damage_source: String = "interaction_target"
var _minor_name_to_horse_id: Dictionary = {
	"MinorGrey": BossHorseTypes.HorseId.GREY,
	"MinorWhite": BossHorseTypes.HorseId.WHITE,
	"MinorBlack": BossHorseTypes.HorseId.BLACK,
	"MinorRed": BossHorseTypes.HorseId.RED,
}

const _TIMELINE_SY_PULL := "商鞅五马分尸"
const _TIMELINE_RELIMB := "重拾五肢"
const _TIMELINE_SY_PULL_PATH := "res://assets/资源总库/12_Dialogic工程/Dialogic/level2/商鞅五马分尸.dtl"
const _TIMELINE_RELIMB_PATH := "res://assets/资源总库/12_Dialogic工程/Dialogic/level2/重拾五肢.dtl"
const _TIMELINE_INTRO_TUTORIAL := "商鞅教导交互心与剑"
const _TIMELINE_INTRO_TUTORIAL_PATH := "res://assets/资源总库/12_Dialogic工程/Dialogic/level2/商鞅教导交互心与剑.dtl"
const _TIMELINE_INTRO_BATTLE_START := "马开始战斗"
const _TIMELINE_INTRO_BATTLE_START_PATH := "res://assets/资源总库/12_Dialogic工程/Dialogic/level2/马开始战斗.dtl"
const _TIMELINE_FATAL_WARNING_HINT := "商鞅提醒按f"
const _TIMELINE_FATAL_WARNING_HINT_PATH := "res://assets/资源总库/12_Dialogic工程/Dialogic/level2/商鞅提醒按f.dtl"

var _intro_waiting_first_heart_sword: bool = false
var _intro_battle_start_timeline_started: bool = false
var _intro_first_heart_sword_triggered: bool = false
var _restore_si_exit_sequence_running: bool = false
var _final_dialog_input_locked_player: Node2D = null
var _final_dialog_input_locked_saved_enable_input: Variant = null
var _fatal_pull_sequence_active: bool = false
var _sy_pull_locked_player: Node2D = null
var _sy_pull_locked_saved_enable_input: Variant = null

const _DEBUG_LOG_PATH := "d:/items/godot/hell_joke_2/文字地狱重制版/debug-5144a3.log"


func is_summon_during_fatal_warning_window() -> bool:
	return _fatal_warning_watch_active


## 致命 20%：预警→拖拽/拉扯→对话→回归 的整段演出期间为 true。
## 用于让主马/小马停止继续放技能，并暂停离场 respawn 回到摄像头。
func is_fatal_pull_sequence_active() -> bool:
	return _fatal_pull_sequence_active


func on_warning_summoned_shangyang_ready(shangyang: Node2D) -> void:
	if not _fatal_warning_watch_active:
		return
	if not is_instance_valid(shangyang):
		return
	_warning_spawned_limbs = _filter_valid_limbs(_warning_spawned_limbs)
	if _warning_spawned_limbs.size() >= 5:
		return
	var ropes_root := get_node_or_null(ropes_root_path) as Node2D
	if ropes_root == null:
		return
	var markers := _collect_shangyang_markers(shangyang)
	if markers.size() < 5:
		return
	_warning_spawned_limbs = _spawn_shangyang_limbs(ropes_root, markers)


func _ready() -> void:
	#region agent log
	_debug_log("run10", "H1", "boss_horse_phase_controller.gd:_ready", "entry", {
		"use_dynamic_minor_spawn": use_dynamic_minor_spawn
	})
	#endregion
	add_to_group("boss_phase_controller")
	var minors_root := get_node_or_null(minors_path) as Node2D
	if use_dynamic_minor_spawn and minors_root != null:
		#region agent log
		_debug_log("run10", "H1", "boss_horse_phase_controller.gd:_ready", "before_clear_all_minors_runtime", {
			"children_count": minors_root.get_child_count()
		})
		#endregion
		_clear_all_minors_runtime(minors_root)
	var main_horse := get_node_or_null(main_horse_path) as Node
	if main_horse:
		_main_stats = main_horse.get_node_or_null("Stats") as Stats
	if _main_stats and not _main_stats.health_changed.is_connected(_on_main_health_changed):
		_main_stats.health_changed.connect(_on_main_health_changed)
	_log_phase("初始化阶段")
	_on_main_health_changed()
	# 必须在 _ready 内 await：call_deferred 到含 await 的函数时，协程续跑不可靠，导致注册从未完成
	await _register_world3_dialogic_when_ready()
	# 入场对话依赖注册完成后再启动，避免与 intro 协程并发导致首段场景对话丢失
	_queue_async_on_timer(Callable(self, "_intro_timeline_launcher"))


func _resolve_dialogic_registry() -> Node:
	var root := get_tree().root
	var reg := root.get_node_or_null("DialogicRegistry")
	if reg:
		return reg
	for c in root.get_children():
		if String(c.name) == "DialogicRegistry":
			return c
	return null


## 入场后多帧重试：玩家入组 / Marker 就绪可能晚于 PhaseController._ready。
func _register_world3_dialogic_when_ready() -> void:
	var tries := 0
	while tries < 90:
		var quiet := tries < 89
		var n := _register_boss_arena_dialogic_characters(get_node_or_null(shangyang_path) as Node2D, quiet)
		if n > 0:
			print("[BossPhase] World3 Dialogic 注册成功（第 %d 帧，共注册 %d 项）" % [tries + 1, n])
			return
		if not await _await_process_frame_safe():
			return
		tries += 1
	push_warning("[BossPhase] World3 Dialogic 注册失败：90 帧内未找到 DialogicRegistry 或玩家/标记点（见上一帧详细警告）")


## 气泡布局依赖 DialogicRegistry 绑定「中学生 / 商鞅」到场景节点。
## 返回成功调用 register_character 的次数（用于重试判断）。quiet 为 true 时不打印逐项失败，仅统计。
func _register_boss_arena_dialogic_characters(sy_opt: Node2D = null, quiet: bool = false) -> int:
	var reg := _resolve_dialogic_registry()
	if reg == null:
		if not quiet:
			push_warning("[BossPhase] DialogicRegistry 未找到（/root 下无此自动加载节点）")
		return 0
	if not reg.has_method("register_character"):
		if not quiet:
			push_warning("[BossPhase] DialogicRegistry 无 register_character 方法")
		return 0
	var count := 0
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		if not quiet:
			push_warning("[BossPhase] 未找到分组 player 的玩家节点")
	else:
		var dm := player.get_node_or_null("DialogMarker")
		if dm == null:
			dm = player.get_node_or_null("Marker2D")
		if dm == null:
			if not quiet:
				push_warning("[BossPhase] 玩家缺少 DialogMarker / Marker2D，无法注册「中学生」")
		else:
			if reg.register_character("中学生", dm, "res://assets/资源总库/12_Dialogic工程/Dialogic/中学生.dch"):
				count += 1
	var proxy := get_node_or_null(shangyang_dialog_proxy_path)
	if proxy != null and is_instance_valid(proxy) and proxy.has_method("get_dialog_anchor"):
		if is_instance_valid(sy_opt):
			proxy.global_position = sy_opt.global_position
		elif proxy.has_method("sync_now"):
			proxy.sync_now()
		var sm_proxy := proxy.call("get_dialog_anchor") as Node2D
		if sm_proxy == null:
			sm_proxy = proxy as Node2D
		if reg.register_character("商鞅", sm_proxy, "res://assets/资源总库/12_Dialogic工程/Dialogic/商鞅.dch"):
			count += 1
	else:
		var sy := sy_opt
		if sy == null or not is_instance_valid(sy):
			sy = get_node_or_null(shangyang_path) as Node2D
		if sy and is_instance_valid(sy):
			var sm := sy.get_node_or_null("DialogMarker")
			if sm == null:
				sm = sy
			if reg.register_character("商鞅", sm, "res://assets/资源总库/12_Dialogic工程/Dialogic/商鞅.dch"):
				count += 1
		elif not quiet:
			push_warning("[BossPhase] 无商鞅节点可注册（无 Dialog 代理且路径/sy_opt 无效）")
	return count


func _try_register_shangyang_for_dialog(sy: Node2D, quiet: bool) -> bool:
	var reg := _resolve_dialogic_registry()
	if reg == null or not reg.has_method("register_character"):
		if not quiet:
			push_warning("[BossPhase] 无法注册商鞅：DialogicRegistry 不可用")
		return false
	var proxy := get_node_or_null(shangyang_dialog_proxy_path)
	if proxy != null and is_instance_valid(proxy) and proxy.has_method("get_dialog_anchor"):
		if is_instance_valid(sy):
			proxy.global_position = sy.global_position
		elif proxy.has_method("sync_now"):
			proxy.sync_now()
		var sm_p := proxy.call("get_dialog_anchor") as Node2D
		if sm_p == null:
			sm_p = proxy as Node2D
		return reg.register_character("商鞅", sm_p, "res://assets/资源总库/12_Dialogic工程/Dialogic/商鞅.dch")
	if not is_instance_valid(sy):
		if not quiet:
			push_warning("[BossPhase] 无法注册商鞅：节点无效（且无 Dialog 代理）")
		return false
	var sm := sy.get_node_or_null("DialogMarker")
	if sm == null:
		sm = sy
	return reg.register_character("商鞅", sm, "res://assets/资源总库/12_Dialogic工程/Dialogic/商鞅.dch")


func _ensure_dialogic_registry_for_sy_pull_dialog(sy: Node2D) -> void:
	if not is_instance_valid(sy) and not _has_shangyang_dialog_proxy():
		push_warning("[BossPhase] 商鞅分尸对话：商鞅节点无效且无 Dialog 代理，跳过注册")
		return
	var tries := 0
	while tries < 120:
		var quiet := tries < 119
		if is_instance_valid(sy):
			_register_boss_arena_dialogic_characters(sy, quiet)
		else:
			_register_boss_arena_dialogic_characters(null, quiet)
		if _try_register_shangyang_for_dialog(sy if is_instance_valid(sy) else null, quiet):
			print("[BossPhase] Boss 对话前「商鞅」已注册到 DialogicRegistry（第 %d 帧）" % [tries + 1])
			return
		if not await _await_process_frame_safe():
			return
		tries += 1
	push_warning("[BossPhase] Boss 对话前「商鞅」注册失败（120 帧，见上一帧详细警告）")


func _has_shangyang_dialog_proxy() -> bool:
	var p := get_node_or_null(shangyang_dialog_proxy_path)
	return p != null and is_instance_valid(p) and p.has_method("get_dialog_anchor")


func _shangyang_exists_anywhere_relaxed() -> bool:
	var static_n := get_node_or_null(shangyang_path)
	if static_n is ShangYang and is_instance_valid(static_n):
		return true
	for n in get_tree().get_nodes_in_group("shangyang_player_summon"):
		if n is ShangYang and is_instance_valid(n):
			return true
	return false


func _resolve_best_shangyang_for_pull() -> ShangYang:
	if is_instance_valid(_summoned_sy_during_warning) and _summoned_sy_during_warning is ShangYang:
		return _summoned_sy_during_warning as ShangYang
	var from_path := get_node_or_null(shangyang_path)
	if from_path is ShangYang and is_instance_valid(from_path):
		return from_path as ShangYang
	for n in get_tree().get_nodes_in_group("shangyang_player_summon"):
		if n is ShangYang and is_instance_valid(n):
			return n as ShangYang
	return null


func _on_main_health_changed() -> void:
	if _main_stats == null:
		return
	var hp_percent := _get_hp_percent()
	shared_health_changed.emit(_main_stats.health, _main_stats.max_health, hp_percent)
	print("[BossPhase] HP 更新: ", _main_stats.health, "/", _main_stats.max_health, " (", snapped(hp_percent * 100.0, 0.1), "%)")
	if _intro_done:
		_update_phase_by_hp_percent(hp_percent)
	if _main_stats.health <= 0:
		_cleanup_all_summoned_clones_on_boss_death()
		shared_health_depleted.emit()
		print("[BossPhase] 共享 Boss 血量归零。")
		if _intro_done and not _relimb_timeline_started:
			_relimb_timeline_started = true
			_queue_async_on_timer(Callable(self, "_relimb_timeline_launcher"))


func request_phase(next: BossHorseTypes.BossPhase) -> void:
	#region agent log
	_debug_log("run11", "H5", "boss_horse_phase_controller.gd:request_phase", "entry", {
		"current_phase": int(current_phase),
		"next_phase": int(next)
	})
	#endregion
	if current_phase == next:
		#region agent log
		_debug_log("run11", "H5", "boss_horse_phase_controller.gd:request_phase", "skip_same_phase", {
			"phase": int(current_phase)
		})
		#endregion
		return
	var old_phase := current_phase
	current_phase = next
	phase_changed.emit(next)
	print("[BossPhase] 阶段切换: ", BossHorseTypes.phase_to_text(old_phase), " -> ", BossHorseTypes.phase_to_text(next))
	_show_phase_enter_hint_if_needed(next)
	_emit_minor_entry_feed_if_needed(next)
	if next == BossHorseTypes.BossPhase.FINAL_WARNING_20 and not _final_warning_sequence_started:
		_cancel_summoned_shangyang_lifetime_limit_in_scene()
		_final_warning_sequence_started = true
		_queue_async_on_timer(Callable(self, "_fatal_attack_launcher"))


func _emit_minor_entry_feed_if_needed(phase: BossHorseTypes.BossPhase) -> void:
	var main := get_node_or_null(main_horse_path) as Node
	if main == null or not is_instance_valid(main):
		return
	if main.has_method("post_minor_entry_broadcast"):
		main.call("post_minor_entry_broadcast", int(phase))


func _cancel_summoned_shangyang_lifetime_limit_in_scene() -> void:
	var summons := get_tree().get_nodes_in_group("shangyang_player_summon")
	for n in summons:
		if n != null and is_instance_valid(n) and n.has_method("cancel_summoned_lifetime_limit"):
			n.call("cancel_summoned_lifetime_limit")


func _cleanup_all_summoned_clones_on_boss_death() -> void:
	for n in get_tree().get_nodes_in_group("boss_horse_main_summoned_clone"):
		if n != null and is_instance_valid(n):
			n.queue_free()
	for n in get_tree().get_nodes_in_group("boss_horse_minor_summoned_clone"):
		if n != null and is_instance_valid(n):
			n.queue_free()
	
	# Boss 死亡 2 秒后销毁全部敌对目标（主马 + 小马 + 驷）
	var cleanup_timer := get_tree().create_timer(2.0)
	cleanup_timer.timeout.connect(
		func():
			for n in get_tree().get_nodes_in_group("boss_horse_main"):
				if n != null and is_instance_valid(n):
					n.queue_free()
			for n in get_tree().get_nodes_in_group("boss_horse_minor"):
				if n != null and is_instance_valid(n):
					n.queue_free()
	,
		CONNECT_ONE_SHOT
	)


func apply_shared_damage(damage_amount: float, source_name: String = "unknown") -> void:
	if _main_stats == null:
		push_warning("共享血条未初始化，无法结算伤害。source=%s" % source_name)
		return
	var before := _main_stats.health
	_main_stats.health -= int(round(damage_amount))
	print("[BossPhase] 共享受伤 source=", source_name, " damage=", damage_amount, " hp=", before, " -> ", _main_stats.health)


func trigger_external_percent_damage(percent: float = 0.2, source_name: String = "interaction_target") -> void:
	if _main_stats == null:
		push_warning("[BossPhase] 外部扣血触发失败：共享血条未初始化。source=%s" % source_name)
		return
	_intro_first_heart_sword_triggered = true
	if _intro_waiting_first_heart_sword and not _intro_battle_start_timeline_started:
		_intro_battle_start_timeline_started = true
		_queue_async_on_timer(Callable(self, "_intro_battle_start_timeline_launcher"))
	if _external_damage_busy:
		print("[BossPhase] 外部扣血请求被忽略（忙碌中）。source=", source_name)
		return
	_queued_external_damage_percent = clampf(percent, 0.01, 1.0)
	_queued_external_damage_source = source_name
	_queue_async_on_timer(Callable(self, "_external_percent_damage_launcher"))


func _external_percent_damage_launcher() -> void:
	await _run_external_percent_damage_sequence(_queued_external_damage_percent, _queued_external_damage_source)


func _run_external_percent_damage_sequence(percent: float, source_name: String) -> void:
	if _main_stats == null or _main_stats.max_health <= 0:
		return
	_external_damage_busy = true
	var main_horse := get_node_or_null(main_horse_path) as Node2D
	var visual := main_horse as CanvasItem
	var base_scale := main_horse.scale if main_horse != null else Vector2.ONE
	var base_modulate := visual.modulate if visual != null else Color(1, 1, 1, 1)
	if main_horse != null:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(main_horse, NodePath("scale"), base_scale * 1.08, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if visual != null:
			var flash := Color(
				clampf(base_modulate.r * 2.15, 0.0, 2.8),
				clampf(base_modulate.g * 2.15, 0.0, 2.8),
				clampf(base_modulate.b * 2.15, 0.0, 2.8),
				base_modulate.a
			)
			tw.tween_property(visual, NodePath("modulate"), flash, 0.08).set_trans(Tween.TRANS_LINEAR)
		await tw.finished
		var tw_back := create_tween()
		tw_back.set_parallel(true)
		tw_back.tween_property(main_horse, NodePath("scale"), base_scale, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if visual != null:
			tw_back.tween_property(visual, NodePath("modulate"), base_modulate, 0.18).set_trans(Tween.TRANS_LINEAR)
		await tw_back.finished
	var damage_amount: int = max(1, int(round(float(_main_stats.max_health) * clampf(percent, 0.01, 1.0))))
	apply_shared_damage(damage_amount, source_name)
	_external_damage_busy = false


func get_shared_stats() -> Stats:
	return _main_stats


func _get_hp_percent() -> float:
	if _main_stats == null or _main_stats.max_health <= 0:
		return 0.0
	return float(_main_stats.health) / float(_main_stats.max_health)


func _update_phase_by_hp_percent(hp_percent: float) -> void:
	var target_phase := _resolve_target_phase_by_hp(hp_percent)
	if target_phase == BossHorseTypes.BossPhase.FINAL_WARNING_20:
		request_phase(target_phase)
		_log_phase_once("20%阈值触发")
		return

	if current_phase != target_phase:
		request_phase(target_phase)
	# 新规则：阶段推进时“新增一种小马，旧的小马继续留场”
	_apply_cumulative_minors_for_phase(target_phase)


func _log_phase(message: String) -> void:
	print("[BossPhase] ", message, " 当前=", BossHorseTypes.phase_to_text(current_phase))


func _log_phase_once(key: String) -> void:
	if _phase_logged_once.has(key):
		return
	_phase_logged_once[key] = true
	_log_phase(key)


func _run_boss_intro_timeline() -> void:
	# 稳态：若已判定进入战斗态（如读档补偿已生效），不要再执行 intro 门控，避免把驷/主再次锁死为不可动。
	if _intro_done or _intro_first_heart_sword_triggered or current_phase != BossHorseTypes.BossPhase.INTRO:
		intro_timeline_finished.emit()
		return
	var main := get_node_or_null(main_horse_path) as Node2D
	var si := get_node_or_null(boss_si_path) as Node2D
	var minors := get_node_or_null(minors_path) as Node2D
	var grey_spawn := get_node_or_null(grey_spawn_path) as Node2D

	if main == null or si == null or minors == null:
		push_warning("[BossPhase] 入场 Timeline 缺少节点：Main/Si/Minors")
		_intro_done = true
		intro_timeline_finished.emit()
		return

	request_phase(BossHorseTypes.BossPhase.INTRO)
	print("[BossPhase] 入场 Timeline 开始。")
	_set_horse_movement(main, false)
	_set_horse_movement(si, false)
	main.visible = false
	main.process_mode = Node.PROCESS_MODE_DISABLED
	si.visible = false
	si.process_mode = Node.PROCESS_MODE_DISABLED
	_intro_waiting_first_heart_sword = false
	_intro_battle_start_timeline_started = false
	_intro_first_heart_sword_triggered = false

	var target_main_pos := main.global_position
	var target_si_pos := si.global_position
	main.global_position = target_main_pos + intro_main_entry_offset
	si.global_position = target_si_pos + intro_si_entry_offset

	await _move_pair(main, target_main_pos, si, target_si_pos, intro_entry_duration)
	# 读档场景下，_ready 已经排队了 intro 协程；若此时存档恢复把状态推进到战斗态，
	# 必须在执行清场前立刻中断，避免误清空已恢复的 minors。
	if _intro_done or _intro_first_heart_sword_triggered or current_phase != BossHorseTypes.BossPhase.INTRO:
		intro_timeline_finished.emit()
		return

	if use_dynamic_minor_spawn:
		_clear_all_minors_runtime(minors)
	else:
		for c in minors.get_children():
			if c is Node:
				c.visible = false
				(c as Node).process_mode = Node.PROCESS_MODE_DISABLED

	# 对话开始前再做一次角色注册，避免玩家锚点晚就绪导致“主角未注册”
	_register_boss_arena_dialogic_characters(get_node_or_null(shangyang_path) as Node2D, true)
	await _await_dialog_timeline(_TIMELINE_INTRO_TUTORIAL, _TIMELINE_INTRO_TUTORIAL_PATH)
	_intro_waiting_first_heart_sword = true
	if _intro_first_heart_sword_triggered and not _intro_battle_start_timeline_started:
		_intro_battle_start_timeline_started = true
		_queue_async_on_timer(Callable(self, "_intro_battle_start_timeline_launcher"))
	while _intro_waiting_first_heart_sword:
		if not await _await_process_frame_safe():
			break

	if skip_intro_timeline:
		await _apply_grey_solo_spawn(minors, grey_spawn, false)
		si.visible = false
		si.process_mode = Node.PROCESS_MODE_DISABLED
		_set_horse_movement(main, true)
		_intro_done = true
		request_phase(BossHorseTypes.BossPhase.FOUR_EXIT_GREY_ENTER)
		request_phase(BossHorseTypes.BossPhase.GREY_SOLO)
		print("[BossPhase] 入场 Timeline 已跳过（skip_intro_timeline）。")
		boss_combat_bgm_requested.emit()
		intro_timeline_finished.emit()
		return

	main.visible = true
	main.process_mode = Node.PROCESS_MODE_INHERIT
	si.visible = true
	si.process_mode = Node.PROCESS_MODE_INHERIT

	var main_ap := main.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if main_ap and main_ap.has_animation(&"jump"):
		main_ap.play(&"jump")

	await _await_seconds_safe(intro_main_jump_beat_seconds)

	var si_ap := si.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if si_ap and si_ap.has_animation(&"divide"):
		si_ap.play(&"divide")
		var div_len := si_ap.get_animation(&"divide").length
		if div_len <= 0.0:
			div_len = 1.0
		await _await_seconds_safe(div_len)

	if si_ap and si_ap.has_animation(&"horses run"):
		si_ap.play(&"horses run")

	var exit_dir := si_exit_screen_offset
	var main_exit_target := _target_outside_camera(main, exit_dir, si_main_exit_margin)
	var si_exit_target := _target_outside_camera(si, exit_dir, si_main_exit_margin)
	await _move_pair_by_speed(main, main_exit_target, si, si_exit_target, si_main_exit_speed)
	# 主马无需等待驷马退场与灰马进场，开场即恢复移动
	_set_horse_movement(main, true)

	si.visible = false
	si.process_mode = Node.PROCESS_MODE_DISABLED
	if si_ap:
		si_ap.stop()

	await _apply_grey_solo_spawn(minors, grey_spawn, true)

	_intro_done = true
	request_phase(BossHorseTypes.BossPhase.FOUR_EXIT_GREY_ENTER)
	request_phase(BossHorseTypes.BossPhase.GREY_SOLO)
	_on_main_health_changed()
	print("[BossPhase] 入场 Timeline 完成（驷离场，灰马进场）。")
	intro_timeline_finished.emit()


func _intro_battle_start_timeline_launcher() -> void:
	boss_combat_bgm_requested.emit()
	# 需求：对话与召唤/出战同时进行，不再等待对话结束后才放行
	_intro_waiting_first_heart_sword = false
	# 播放前临门重注册一次，避免主角对话气泡丢失
	_register_boss_arena_dialogic_characters(get_node_or_null(shangyang_path) as Node2D, true)
	await _await_dialog_timeline(_TIMELINE_INTRO_BATTLE_START, _TIMELINE_INTRO_BATTLE_START_PATH)


func mark_intro_battle_triggered_for_save() -> void:
	_intro_first_heart_sword_triggered = true
	if _intro_waiting_first_heart_sword and not _intro_battle_start_timeline_started:
		_intro_battle_start_timeline_started = true
		_queue_async_on_timer(Callable(self, "_intro_battle_start_timeline_launcher"))


func is_intro_battle_triggered_for_save() -> bool:
	return _intro_first_heart_sword_triggered


func is_si_split_triggered_for_save() -> bool:
	# 驷马分裂/退场流程是否已经进入过战斗态。
	return _intro_done


func apply_intro_battle_triggered_from_save(triggered: bool) -> void:
	_intro_first_heart_sword_triggered = triggered
	if triggered and _intro_waiting_first_heart_sword and not _intro_battle_start_timeline_started:
		_intro_battle_start_timeline_started = true
		_queue_async_on_timer(Callable(self, "_intro_battle_start_timeline_launcher"))


func force_main_si_enter_battle_from_save() -> void:
	# 读档补偿：不再模拟“补一次心剑”，直接让主马+驷马进入战斗态。
	_intro_first_heart_sword_triggered = true
	_intro_waiting_first_heart_sword = false
	_intro_battle_start_timeline_started = true
	_intro_done = true
	var main := get_node_or_null(main_horse_path) as Node2D
	var si := get_node_or_null(boss_si_path) as Node2D
	if main != null:
		main.visible = true
		main.process_mode = Node.PROCESS_MODE_INHERIT
		_set_horse_movement(main, true)
	if si != null:
		si.visible = true
		si.process_mode = Node.PROCESS_MODE_INHERIT
		if "move_left_speed" in si:
			# 读档强制进战斗时，确保驷马速度不落到体感极慢档位。
			var cur_speed: float = float(si.get("move_left_speed"))
			if cur_speed < 180.0:
				si.set("move_left_speed", 220.0)
		# 读档恢复需求：驷马要执行“撤场动作”，因此此处先停，交给恢复序列驱动离场。
		_set_horse_movement(si, false)
	if current_phase == BossHorseTypes.BossPhase.INTRO:
		request_phase(BossHorseTypes.BossPhase.FOUR_EXIT_GREY_ENTER)
		request_phase(BossHorseTypes.BossPhase.GREY_SOLO)
	# 读档后立即按共享血量重同步一次阶段，避免 deferred 顺序导致小马集合短暂回落。
	_resync_phase_and_minors_from_shared_hp()
	boss_combat_bgm_requested.emit()
	_queue_restore_si_exit_and_grey_entry_sequence()


func _queue_restore_si_exit_and_grey_entry_sequence() -> void:
	if _restore_si_exit_sequence_running:
		return
	_restore_si_exit_sequence_running = true
	_queue_async_on_timer(Callable(self, "_restore_si_exit_and_grey_entry_launcher"))


func _restore_si_exit_and_grey_entry_launcher() -> void:
	await _run_restore_si_exit_and_grey_entry_sequence()


func _run_restore_si_exit_and_grey_entry_sequence() -> void:
	var main := get_node_or_null(main_horse_path) as Node2D
	var si := get_node_or_null(boss_si_path) as Node2D
	var minors := get_node_or_null(minors_path) as Node2D
	var grey_spawn := get_node_or_null(grey_spawn_path) as Node2D
	if main == null or si == null or minors == null:
		_restore_si_exit_sequence_running = false
		return
	if not si.visible:
		# 驷马已离场时不重复演出，直接补齐当前阶段小马。
		_resync_phase_and_minors_from_shared_hp()
		_restore_si_exit_sequence_running = false
		return
	var si_ap := si.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if si_ap and si_ap.has_animation(&"horses run"):
		si_ap.play(&"horses run")
	var exit_dir := si_exit_screen_offset
	var main_exit_target := _target_outside_camera(main, exit_dir, si_main_exit_margin)
	var si_exit_target := _target_outside_camera(si, exit_dir, si_main_exit_margin)
	await _move_pair_by_speed(main, main_exit_target, si, si_exit_target, si_main_exit_speed)
	si.visible = false
	si.process_mode = Node.PROCESS_MODE_DISABLED
	if si_ap:
		si_ap.stop()
	if grey_spawn != null:
		await _apply_grey_solo_spawn(minors, grey_spawn, true)
	# 撤场+灰马入场完成后，按共享血量再同步一次，避免读档并发顺序导致漏补红马。
	_resync_phase_and_minors_from_shared_hp()
	_restore_si_exit_sequence_running = false


func _resync_phase_and_minors_from_shared_hp() -> void:
	if _main_stats == null or _main_stats.max_health <= 0:
		return
	var hp_percent := _get_hp_percent()
	#region agent log
	_debug_log("run10", "H3", "boss_horse_phase_controller.gd:_resync_phase_and_minors_from_shared_hp", "before_update_phase", {
		"hp_percent": hp_percent,
		"current_phase": int(current_phase),
		"minors_count": (get_node_or_null(minors_path) as Node2D).get_child_count() if get_node_or_null(minors_path) != null else -1
	})
	#endregion
	_update_phase_by_hp_percent(hp_percent)


func _apply_grey_solo_spawn(minors: Node2D, grey_spawn: Node2D, from_left_side: bool) -> void:
	var grey := _get_or_spawn_minor(minors, &"MinorGrey")
	if grey == null or grey_spawn == null:
		return
	if from_left_side:
		grey.global_position = grey_spawn.global_position + grey_entry_offset
	else:
		grey.global_position = grey_spawn.global_position
	grey.visible = true
	grey.process_mode = Node.PROCESS_MODE_INHERIT
	# 回场前先切到灰马自己的表现，避免沿用上一匹马的颜色。
	_play_minor_jump(grey, &"MinorGrey")
	await _move_node(grey, grey_spawn.global_position, horse_switch_duration)
	_set_horse_movement(grey, true)
	_play_minor_travel_loop_anim(grey, &"MinorGrey")
	_active_minor_name = &"MinorGrey"


func _start_minor_switch(target_phase: BossHorseTypes.BossPhase) -> void:
	var target_minor := _phase_to_minor_name(target_phase)
	if target_minor == StringName():
		request_phase(target_phase)
		return
	if _active_minor_name == target_minor:
		request_phase(target_phase)
		return
	_is_switching_minor = true
	_queued_target_phase = target_phase
	_pending_minor_switch_phase = target_phase
	_queue_async_on_timer(Callable(self, "_minor_switch_launcher"))


func _run_minor_switch(target_phase: BossHorseTypes.BossPhase) -> void:
	var minors := get_node_or_null(minors_path) as Node2D
	if minors == null:
		_is_switching_minor = false
		request_phase(target_phase)
		return

	var current_minor := minors.get_node_or_null(String(_active_minor_name)) as Node2D
	var next_name := _phase_to_minor_name(target_phase)
	var next_minor := _get_or_spawn_minor(minors, next_name)
	var next_spawn := _spawn_marker_for_minor(next_name)

	if current_minor:
		_set_horse_movement(current_minor, false)
		await _move_node(current_minor, current_minor.global_position + horse_switch_exit_offset, horse_switch_duration)
		if use_dynamic_minor_spawn:
			current_minor.queue_free()
		else:
			current_minor.visible = false
			current_minor.process_mode = Node.PROCESS_MODE_DISABLED

	if next_minor and next_spawn:
		next_minor.global_position = next_spawn.global_position + horse_switch_entry_offset
		next_minor.visible = true
		next_minor.process_mode = Node.PROCESS_MODE_INHERIT
		_set_horse_movement(next_minor, false)
		# 回场前先切到目标马颜色，避免显示上一匹马残留颜色。
		_play_minor_jump(next_minor, next_name)
		await _move_node(next_minor, next_spawn.global_position, horse_switch_duration)
		_set_horse_movement(next_minor, true)
		_play_minor_travel_loop_anim(next_minor, next_name)
		_active_minor_name = next_name

	request_phase(target_phase)
	_is_switching_minor = false

	var hp_percent := _get_hp_percent()
	var latest_target := _resolve_target_phase_by_hp(hp_percent)
	if latest_target != target_phase and latest_target != BossHorseTypes.BossPhase.FINAL_WARNING_20:
		_start_minor_switch(latest_target)


func _resolve_target_phase_by_hp(hp_percent: float) -> BossHorseTypes.BossPhase:
	if hp_percent <= 0.2:
		return BossHorseTypes.BossPhase.FINAL_WARNING_20
	if hp_percent <= 0.4:
		_log_phase_once("40%阈值触发（红马阶段）")
		return BossHorseTypes.BossPhase.RED_SOLO
	if hp_percent <= 0.6:
		_log_phase_once("60%阈值触发（黑马阶段）")
		return BossHorseTypes.BossPhase.BLACK_SOLO
	if hp_percent <= 0.8:
		_log_phase_once("80%阈值触发（白马阶段）")
		return BossHorseTypes.BossPhase.WHITE_SOLO
	_log_phase_once("开场阶段（灰马阶段）")
	return BossHorseTypes.BossPhase.GREY_SOLO


func _phase_to_minor_name(phase: BossHorseTypes.BossPhase) -> StringName:
	match phase:
		BossHorseTypes.BossPhase.GREY_SOLO:
			return &"MinorGrey"
		BossHorseTypes.BossPhase.WHITE_SOLO:
			return &"MinorWhite"
		BossHorseTypes.BossPhase.BLACK_SOLO:
			return &"MinorBlack"
		BossHorseTypes.BossPhase.RED_SOLO:
			return &"MinorRed"
		_:
			return StringName()


func _phase_to_cumulative_minor_names(phase: BossHorseTypes.BossPhase) -> Array[StringName]:
	match phase:
		BossHorseTypes.BossPhase.GREY_SOLO:
			return [&"MinorGrey"]
		BossHorseTypes.BossPhase.WHITE_SOLO:
			return [&"MinorGrey", &"MinorWhite"]
		BossHorseTypes.BossPhase.BLACK_SOLO:
			return [&"MinorGrey", &"MinorWhite", &"MinorBlack"]
		BossHorseTypes.BossPhase.RED_SOLO:
			return [&"MinorGrey", &"MinorWhite", &"MinorBlack", &"MinorRed"]
		_:
			return []


func _apply_cumulative_minors_for_phase(phase: BossHorseTypes.BossPhase) -> void:
	var minors := get_node_or_null(minors_path) as Node2D
	if minors == null:
		return
	#region agent log
	_debug_log("run10", "H3", "boss_horse_phase_controller.gd:_apply_cumulative_minors_for_phase", "entry", {
		"phase": int(phase),
		"before_count": minors.get_child_count()
	})
	#endregion
	var should_alive := _phase_to_cumulative_minor_names(phase)
	if should_alive.is_empty():
		return
	for nm in should_alive:
		var m := _get_or_spawn_minor(minors, nm)
		if m == null:
			continue
		var spawn := _spawn_marker_for_minor(nm)
		if spawn != null:
			m.global_position = spawn.global_position
		m.visible = true
		m.process_mode = Node.PROCESS_MODE_INHERIT
		_set_horse_movement(m, true)
		_play_minor_travel_loop_anim(m, nm)
	#region agent log
	_debug_log("run10", "H3", "boss_horse_phase_controller.gd:_apply_cumulative_minors_for_phase", "exit", {
		"phase": int(phase),
		"after_count": minors.get_child_count()
	})
	#endregion


func _spawn_marker_for_minor(minor_name: StringName) -> Node2D:
	match minor_name:
		&"MinorGrey":
			return get_node_or_null("../../Bosses/SpawnMarkers/GreySpawn") as Node2D
		&"MinorWhite":
			return get_node_or_null("../../Bosses/SpawnMarkers/WhiteSpawn") as Node2D
		&"MinorBlack":
			return get_node_or_null("../../Bosses/SpawnMarkers/BlackSpawn") as Node2D
		&"MinorRed":
			return get_node_or_null("../../Bosses/SpawnMarkers/RedSpawn") as Node2D
		_:
			return null


func _play_minor_jump(minor: Node2D, minor_name: StringName) -> void:
	if minor.has_method("refresh_visual_to_horse_id"):
		minor.call("refresh_visual_to_horse_id")
	var ap := minor.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		return
	match minor_name:
		&"MinorGrey":
			if ap.has_animation(&"grey_jump"):
				ap.play(&"grey_jump")
		&"MinorWhite":
			if ap.has_animation(&"white_jump"):
				ap.play(&"white_jump")
		&"MinorBlack":
			if ap.has_animation(&"black_jump"):
				ap.play(&"black_jump")
		&"MinorRed":
			if ap.has_animation(&"red_jump"):
				ap.play(&"red_jump")


## 入场/换马 tween 结束后：左移行走对应的循环动作（灰马有专用 grey_run）
func _play_minor_travel_loop_anim(minor: Node2D, minor_name: StringName) -> void:
	var ap := minor.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		return
	match minor_name:
		&"MinorGrey":
			if ap.has_animation(&"grey_run"):
				ap.play(&"grey_run")
		&"MinorWhite":
			if ap.has_animation(&"white_jump"):
				ap.play(&"white_jump")
		&"MinorBlack":
			if ap.has_animation(&"black_jump"):
				ap.play(&"black_jump")
		&"MinorRed":
			if ap.has_animation(&"red_jump"):
				ap.play(&"red_jump")
		_:
			pass


func _move_pair(first: Node2D, first_target: Vector2, second: Node2D, second_target: Vector2, duration: float) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(first, NodePath("global_position"), first_target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(second, NodePath("global_position"), second_target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _move_pair_by_speed(first: Node2D, first_target: Vector2, second: Node2D, second_target: Vector2, speed: float) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	var spd := maxf(1.0, speed)
	var d1 := first.global_position.distance_to(first_target) / spd
	var d2 := second.global_position.distance_to(second_target) / spd
	tw.tween_property(first, NodePath("global_position"), first_target, maxf(0.01, d1)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(second, NodePath("global_position"), second_target, maxf(0.01, d2)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _target_outside_camera(node: Node2D, direction_hint: Vector2, margin: float) -> Vector2:
	if node == null:
		return Vector2.ZERO
	var dir := direction_hint.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.LEFT
	var cam := _get_player_camera2d()
	if cam == null:
		return node.global_position + dir * 600.0
	var vp := get_viewport()
	if vp == null:
		return node.global_position + dir * 600.0
	var vp_rect: Rect2 = vp.get_visible_rect()
	var half: Vector2 = vp_rect.size * 0.5
	var center: Vector2 = cam.get_screen_center_position()
	var left: float = center.x - half.x
	var right: float = center.x + half.x
	var top: float = center.y - half.y
	var bottom: float = center.y + half.y
	var m := maxf(1.0, margin)
	var out := node.global_position
	if absf(dir.x) >= absf(dir.y):
		out.x = (left - m) if dir.x < 0.0 else (right + m)
		out.y = clampf(out.y + dir.y * m, top - m, bottom + m)
	else:
		out.y = (top - m) if dir.y < 0.0 else (bottom + m)
		out.x = clampf(out.x + dir.x * m, left - m, right + m)
	return out


func _move_node(node: Node2D, target_position: Vector2, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, NodePath("global_position"), target_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _set_horse_movement(node: Node, enabled: bool) -> void:
	if node and node.has_method("set_movement_enabled"):
		node.call("set_movement_enabled", enabled)


func _zero_velocity_if_characterbody2d(node: Node2D) -> void:
	if node != null and node is CharacterBody2D:
		(node as CharacterBody2D).velocity = Vector2.ZERO


func _is_node_offscreen(node: Node2D, margin: float = 100.0) -> bool:
	if node == null:
		return false
	var cam := _get_player_camera2d()
	if cam == null:
		return false
	var vp := get_viewport()
	if vp == null:
		return false
	var vp_rect: Rect2 = vp.get_visible_rect()
	var half: Vector2 = vp_rect.size * 0.5
	var center: Vector2 = cam.get_screen_center_position()
	var left: float = center.x - half.x - margin
	var right: float = center.x + half.x + margin
	var top: float = center.y - half.y - margin
	var bottom: float = center.y + half.y + margin
	var pos := node.global_position
	return pos.x < left or pos.x > right or pos.y < top or pos.y > bottom


## call_deferred(含 await 的函数) 在首次 yield 后协程会丢；用 0s timer 的 timeout 启动。
## 必须把「异步方法」直接连到 signal（见 launcher），勿用 lambda 里 Callable.call(async)，否则会丢掉协程状态。
func _queue_async_on_timer(launcher: Callable) -> void:
	if not is_inside_tree():
		push_warning("[BossPhase] _queue_async_on_timer：节点不在树内")
		return
	var tree := get_tree()
	if tree == null:
		return
	var tw := tree.create_timer(0.0)
	tw.timeout.connect(launcher, CONNECT_ONE_SHOT)


func _await_seconds_safe(seconds: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(maxf(0.0, seconds)).timeout


func _await_process_frame_safe() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	await tree.process_frame
	var tree_after := get_tree()
	return tree_after != null


func _intro_timeline_launcher() -> void:
	await _run_boss_intro_timeline()


func _relimb_timeline_launcher() -> void:
	await _play_relimb_timeline_deferred()


func _fatal_attack_launcher() -> void:
	await _fatal_attack_full_sequence()


func _fatal_warning_hint_dialog_launcher() -> void:
	await _await_dialog_timeline(_TIMELINE_FATAL_WARNING_HINT, _TIMELINE_FATAL_WARNING_HINT_PATH)


func _minor_switch_launcher() -> void:
	await _run_minor_switch(_pending_minor_switch_phase)


func _fatal_attack_full_sequence() -> void:
	print("[BossPhase] 致命演出序列开始（警告→分尸/拉玩家→对话等）")
	_fatal_pull_sequence_active = true
	_fatal_sy_seen_before_or_during_warning = _shangyang_exists_anywhere_relaxed()
	var dialog_proxy := get_node_or_null(shangyang_dialog_proxy_path)
	if dialog_proxy != null and is_instance_valid(dialog_proxy) and dialog_proxy.has_method("set_tracking"):
		dialog_proxy.call("set_tracking", true)
	_summoned_sy_during_warning = null
	_fatal_warning_watch_active = true
	var sy_watch := Callable(self, "_on_tree_node_added_summon_sy_watch")
	get_tree().node_added.connect(sy_watch)
	_queue_async_on_timer(Callable(self, "_fatal_warning_hint_dialog_launcher"))
	print("[BossPhase] 即将播放致命预警面板（_play_fatal_warning_panel）")
	await _play_fatal_warning_panel()
	get_tree().node_added.disconnect(sy_watch)
	_fatal_warning_watch_active = false
	if dialog_proxy != null and is_instance_valid(dialog_proxy) and dialog_proxy.has_method("set_tracking"):
		dialog_proxy.call("set_tracking", false)

	var sy_target := _resolve_shangyang_for_fatal_pull()
	var want_sy_timeline := (sy_target != null and sy_target is ShangYang) or _fatal_sy_seen_before_or_during_warning
	if want_sy_timeline:
		print("[BossPhase] 走商鞅分尸时间线（当前为商鞅 或 预警前/期间曾存在商鞅）")
		var sy_for_pull: ShangYang = null
		if sy_target is ShangYang:
			sy_for_pull = sy_target as ShangYang
		else:
			sy_for_pull = _resolve_best_shangyang_for_pull()
		if sy_for_pull != null:
			await _run_shangyang_limb_pull_sequence_for(sy_for_pull, true)
			if sy_for_pull.has_method("enter_post_boss_pull_story_state"):
				sy_for_pull.call("enter_post_boss_pull_story_state")
			await _ensure_dialogic_registry_for_sy_pull_dialog(sy_for_pull as Node2D)
		else:
			push_warning("[BossPhase] 放宽判定：曾判定存在商鞅上下文，但当前无可用 ShangYang 节点，跳过绳肢体演出，仅尝试对话注册与时间线")
			await _ensure_dialogic_registry_for_sy_pull_dialog(null)
		await _await_seconds_safe(0.12)
		var focus_target := sy_for_pull.global_position + fatal_sy_pull_horses_anchor_offset if sy_for_pull != null else Vector2.ZERO
		var p_lock := _sy_pull_locked_player
		if p_lock != null and is_instance_valid(p_lock):
			_final_dialog_input_locked_player = p_lock
			_final_dialog_input_locked_saved_enable_input = _sy_pull_locked_saved_enable_input
			_pull_player_camera_to_world(focus_target, camera_pull_duration_seconds)
		await _await_dialog_timeline(_TIMELINE_SY_PULL, _TIMELINE_SY_PULL_PATH)
		await _clear_final_dialog_input_and_camera_lock()
		_sy_pull_locked_player = null
		_sy_pull_locked_saved_enable_input = null
		await _after_sy_pull_start_finale_siege()
	else:
		await _run_player_fatal_ropes_pull()
	_fatal_pull_sequence_active = false


func _on_tree_node_added_summon_sy_watch(node: Node) -> void:
	if not _fatal_warning_watch_active:
		return
	if node is ShangYang and (node as Node).is_in_group("shangyang_player_summon"):
		_summoned_sy_during_warning = node as Node2D
		_fatal_sy_seen_before_or_during_warning = true


func _play_fatal_warning_panel() -> void:
	print("[BossPhase] _play_fatal_warning_panel 进入，fatal_warning_scene=", fatal_warning_scene)
	if fatal_warning_scene == null:
		push_warning("[BossPhase] fatal_warning_scene 为空，无法实例化 boss_fatal_warning.tscn")
		await _await_seconds_safe(5.0)
		return
	var ui := fatal_warning_scene.instantiate() as Node
	print("[BossPhase] 致命预警面板实例化完成，ui=", ui)
	var scn := get_tree().current_scene
	if scn:
		scn.add_child(ui)
	else:
		get_tree().root.add_child(ui)
	print("[BossPhase] 致命预警面板已加入场景树")
	if ui.has_signal("warning_finished"):
		await ui.warning_finished
	else:
		await _await_seconds_safe(5.0)


func _set_warning_input_lock(active: bool) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	if "enable_input_control" in p:
		p.set("enable_input_control", not active)
	if p is CharacterBody2D:
		(p as CharacterBody2D).velocity = Vector2.ZERO
	if p.has_method("set_camera_drag_ignore_player_input"):
		p.call("set_camera_drag_ignore_player_input", active)


func _resolve_shangyang_for_fatal_pull() -> Node2D:
	if is_instance_valid(_summoned_sy_during_warning):
		return _summoned_sy_during_warning
	var from_path := get_node_or_null(shangyang_path) as Node2D
	if from_path != null:
		return from_path
	for n in get_tree().get_nodes_in_group("shangyang_player_summon"):
		if n is ShangYang and is_instance_valid(n):
			return n as Node2D
	return null


func _await_dialog_timeline(timeline_identifier: String, fallback_res_path: String = "") -> void:
	print("开始调用_await_dialog_timeline")
	var dlg := DialogicUtil.autoload()
	if dlg == null or not Dialogic:
		push_warning("[BossPhase] Dialogic 未启用，跳过时间线: %s" % timeline_identifier)
		return
	# 避免启动过早缓存的空 dtl 目录（Engine meta）
	if Engine.has_meta("dtl_directory"):
		Engine.remove_meta("dtl_directory")
	DialogicResourceUtil.update()

	dlg.paused = false
	var tree_paused_before := get_tree().paused
	get_tree().paused = false

	var tl_res: DialogicTimeline = null
	if fallback_res_path != "" and ResourceLoader.exists(fallback_res_path):
		tl_res = load(fallback_res_path) as DialogicTimeline
	if tl_res == null:
		tl_res = DialogicResourceUtil.get_timeline_resource(timeline_identifier) as DialogicTimeline
	if tl_res == null:
		push_warning("[BossPhase] 无法加载时间线资源: %s / %s" % [timeline_identifier, fallback_res_path])
		get_tree().paused = tree_paused_before
		return

	var timeline_done := [false]
	var on_timeline_ended := func() -> void:
		timeline_done[0] = true
	if not dlg.timeline_ended.is_connected(on_timeline_ended):
		dlg.timeline_ended.connect(on_timeline_ended, CONNECT_ONE_SHOT)

	var layout := Dialogic.start(tl_res)
	if layout == null:
		push_warning("[BossPhase] Dialogic.start 返回 null（Styles 子系统异常）")
		if dlg.timeline_ended.is_connected(on_timeline_ended):
			dlg.timeline_ended.disconnect(on_timeline_ended)
		var tree0 := get_tree()
		if tree0 != null:
			tree0.paused = tree_paused_before
		return

	# 等 Dialogic 的 defer 入树后再挂到当前场景，避免与根节点 add 顺序打架；并保证暂停时仍能推进
	var tree := get_tree()
	if tree == null:
		if dlg.timeline_ended.is_connected(on_timeline_ended):
			dlg.timeline_ended.disconnect(on_timeline_ended)
		return
	if not await _await_process_frame_safe():
		if dlg.timeline_ended.is_connected(on_timeline_ended):
			dlg.timeline_ended.disconnect(on_timeline_ended)
		return
	tree = get_tree()
	if tree == null:
		if dlg.timeline_ended.is_connected(on_timeline_ended):
			dlg.timeline_ended.disconnect(on_timeline_ended)
		return
	if not await _await_process_frame_safe():
		if dlg.timeline_ended.is_connected(on_timeline_ended):
			dlg.timeline_ended.disconnect(on_timeline_ended)
		return
	tree = get_tree()
	if tree == null:
		if dlg.timeline_ended.is_connected(on_timeline_ended):
			dlg.timeline_ended.disconnect(on_timeline_ended)
		return
	var scn := tree.current_scene
	if scn and is_instance_valid(layout):
		if layout.get_parent() != scn:
			var p := layout.get_parent()
			if p:
				p.remove_child(layout)
			scn.add_child(layout)
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
		layout.show()

	var safety := 0
	while not timeline_done[0] and safety < 7200:
		tree = get_tree()
		if tree == null:
			break
		if not await _await_process_frame_safe():
			break
		safety += 1
	if not timeline_done[0]:
		push_warning("[BossPhase] 等待 timeline_ended 超时，已断开监听: %s" % timeline_identifier)
		if dlg.timeline_ended.is_connected(on_timeline_ended):
			dlg.timeline_ended.disconnect(on_timeline_ended)

	var tree_end := get_tree()
	if tree_end != null:
		tree_end.paused = tree_paused_before


func _play_relimb_timeline_deferred() -> void:
	await _scatter_horses_flee_async()
	var sy_focus_target := _resolve_best_shangyang_for_pull()
	var focus_world := sy_focus_target.global_position if sy_focus_target != null else Vector2.ZERO
	_set_final_dialog_input_and_camera_lock(sy_focus_target != null, focus_world)
	await _await_dialog_timeline(_TIMELINE_RELIMB, _TIMELINE_RELIMB_PATH)
	await _clear_final_dialog_input_and_camera_lock()


func _after_sy_pull_start_finale_siege() -> void:
	var main := get_node_or_null(main_horse_path) as Node2D
	var minors := get_node_or_null(minors_path) as Node2D
	if main == null or minors == null:
		return
	_ensure_all_minors_present(minors)
	var horses := _get_five_horses_ordered(main, minors)
	if horses.size() < 5:
		return
	await _tween_horses_rally_after_pull_to_spawns(horses, main, minors)
	for horse in horses:
		_set_horse_movement(horse, true)
	request_phase(BossHorseTypes.BossPhase.ALL_HORSES)
	print("[BossPhase] 五马已回场，合围攻击（ALL_HORSES）。")


func _tween_horses_rally_after_pull_to_spawns(horses: Array[Node2D], main: Node2D, minors: Node2D) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	for horse in horses:
		if horse == null:
			continue
		horse.visible = true
		horse.process_mode = Node.PROCESS_MODE_INHERIT
		var rally := _finale_rally_position(horse, main, minors)
		tw.tween_property(horse, NodePath("global_position"), rally, finale_rally_after_pull_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _scatter_horses_flee_async() -> void:
	var main := get_node_or_null(main_horse_path) as Node2D
	var minors := get_node_or_null(minors_path) as Node2D
	if main == null or minors == null:
		return
	_ensure_all_minors_present(minors)
	var horses := _get_five_horses_ordered(main, minors)
	if horses.is_empty():
		return
	var dirs: Array[Vector2] = [
		Vector2(-0.95, -0.55).normalized(),
		Vector2(0.9, -0.6).normalized(),
		Vector2(-0.85, 0.65).normalized(),
		Vector2(0.85, 0.6).normalized(),
		Vector2(0.0, -1.0),
	]
	var tw := create_tween()
	tw.set_parallel(true)
	for i in horses.size():
		var h := horses[i] as Node2D
		if h == null:
			continue
		_set_horse_movement(h, false)
		if "auto_cast_enabled" in h:
			h.set("auto_cast_enabled", false)
		var dir := dirs[i] if i < dirs.size() else Vector2.RIGHT
		var target := h.global_position + dir * scatter_flee_distance
		tw.tween_property(h, NodePath("global_position"), target, scatter_flee_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	for h2 in horses:
		if h2 != null and is_instance_valid(h2):
			h2.visible = false
			h2.process_mode = Node.PROCESS_MODE_DISABLED
	print("[BossPhase] 五马已四散离场。")


func _run_shangyang_limb_pull_sequence_for(shangyang: Node2D, keep_input_lock_for_followup_dialog: bool = false) -> void:
	var ropes_root := get_node_or_null(ropes_root_path) as Node2D
	var minors := get_node_or_null(minors_path) as Node2D
	var main := get_node_or_null(main_horse_path) as Node2D
	if shangyang == null or ropes_root == null or minors == null or main == null:
		push_warning("[BossPhase] 20%商鞅牵引演出缺节点，已跳过。")
		return
	_ensure_all_minors_present(minors)

	if shangyang.has_method("force_initial_story_form"):
		shangyang.call("force_initial_story_form")

	var horses := _get_five_horses_ordered(main, minors)
	if horses.size() < 5:
		push_warning("[BossPhase] 马匹数量不足 5，无法执行五绳牵引。")
		return

	for horse in horses:
		_set_horse_movement(horse, false)

	var limb_markers := _collect_shangyang_markers(shangyang)
	if limb_markers.size() < 5:
		push_warning("[BossPhase] 商鞅肢体标记不足 5，无法执行五绳牵引。")
		for horse in horses:
			_set_horse_movement(horse, true)
		return

	var limbs := _consume_warning_spawned_limbs_or_spawn(ropes_root, limb_markers)
	if limbs.size() < 5:
		push_warning("[BossPhase] 商鞅肢体对象生成不足 5。")
		for horse in horses:
			_set_horse_movement(horse, true)
		return

	var sy_pull_anchor := shangyang.global_position + fatal_sy_pull_horses_anchor_offset
	await _tween_fatal_pull_horses_surround(sy_pull_anchor, horses, main, minors)

	var pairs := _pair_horses_to_limbs_by_nearest(horses, limbs)
	var ropes: Array[Node2D] = []
	for pair in pairs:
		var horse := pair["horse"] as Node2D
		var limb := pair["limb"] as Node2D
		var rope := _spawn_rope_between(ropes_root, horse, limb)
		if rope:
			ropes.append(rope)

	if ropes.is_empty():
		push_warning("[BossPhase] 商鞅绳未生成，跳过伸绳、镜头与玩家锁定。")
		for horse in horses:
			_set_horse_movement(horse, true)
		return

	var player_sy := get_tree().get_first_node_in_group("player") as Node2D
	var saved_input_sy: Variant = null
	if player_sy != null and "enable_input_control" in player_sy:
		saved_input_sy = player_sy.get("enable_input_control")
		player_sy.set("enable_input_control", false)
		_sy_pull_locked_player = player_sy
		_sy_pull_locked_saved_enable_input = saved_input_sy
	if player_sy != null and player_sy.has_method("set_camera_drag_ignore_player_input"):
		player_sy.call("set_camera_drag_ignore_player_input", true)
	# 商鞅被抓住时，强制镜头焦点锁定到商鞅锚点（无视其是否在屏幕内）
	_pull_player_camera_to_world(sy_pull_anchor, camera_pull_duration_seconds)

	await _tween_rope_extend_all(ropes, final_warn_rope_extend_seconds)
	# 绳子接触肢体后，停止「跟随商鞅本体」并冻结在当前点位
	_freeze_limb_following(limbs)
	_show_rope_contact_hint_fire_and_forget(rope_contact_hint_shangyang)
	await _await_seconds_safe(final_warn_pause_after_rope_seconds)
	await _tween_pull_horses_then_limbs(pairs, main, shangyang)

	for rope in ropes:
		if is_instance_valid(rope):
			rope.queue_free()

	if not keep_input_lock_for_followup_dialog:
		_restore_player_camera(camera_return_duration_seconds)
		if player_sy != null and player_sy.has_method("set_camera_drag_ignore_player_input"):
			player_sy.call("set_camera_drag_ignore_player_input", false)
		if player_sy != null and saved_input_sy != null:
			player_sy.set("enable_input_control", saved_input_sy)
		_sy_pull_locked_player = null
		_sy_pull_locked_saved_enable_input = null


func _run_player_fatal_ropes_pull() -> void:
	var ropes_root := get_node_or_null(ropes_root_path) as Node2D
	var minors := get_node_or_null(minors_path) as Node2D
	var main := get_node_or_null(main_horse_path) as Node2D
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if ropes_root == null or minors == null or main == null or player == null:
		push_warning("[BossPhase] 无商鞅时的玩家牵引演出缺节点，已跳过。")
		return
	_ensure_all_minors_present(minors)

	var horses := _get_five_horses_ordered(main, minors)
	if horses.size() < 5:
		push_warning("[BossPhase] 马匹数量不足 5，无法执行五绳拉玩家。")
		return

	for horse in horses:
		_set_horse_movement(horse, false)

	await _tween_fatal_pull_horses_surround(player.global_position, horses, main, minors)

	var saved_input: Variant = null
	if "enable_input_control" in player:
		saved_input = player.get("enable_input_control")
		player.set("enable_input_control", false)

	var ropes: Array[Node2D] = []
	var end_offsets: Array[Vector2] = [
		player_fatal_rope_end_offset_0,
		player_fatal_rope_end_offset_1,
		player_fatal_rope_end_offset_2,
		player_fatal_rope_end_offset_3,
		player_fatal_rope_end_offset_4,
	]
	for i in horses.size():
		var horse2 := horses[i] as Node2D
		var eo := end_offsets[i] if i < end_offsets.size() else Vector2.ZERO
		var rope := rope_scene.instantiate() as Node2D
		if rope == null:
			continue
		ropes_root.add_child(rope)
		if rope.has_method("bind_endpoints"):
			rope.call("bind_endpoints", horse2, player, Vector2.ZERO, eo, 0.0)
		ropes.append(rope)

	if ropes.is_empty():
		push_warning("[BossPhase] 玩家绳未生成，恢复输入与马移动。")
		if saved_input != null and "enable_input_control" in player:
			player.set("enable_input_control", saved_input)
		for horse in horses:
			_set_horse_movement(horse, true)
		return

	await _tween_rope_extend_all(ropes, final_warn_rope_extend_seconds)
	_show_rope_contact_hint_fire_and_forget(rope_contact_hint_player)
	await _await_seconds_safe(final_warn_pause_after_rope_seconds)

	for rope_u in ropes:
		if rope_u != null and is_instance_valid(rope_u) and rope_u.has_method("unbind_end_keep_vector_from_start"):
			rope_u.call("unbind_end_keep_vector_from_start")

	# 拉玩家：五马、玩家、绳端点共用同一位移向量与时长 → 同向、同速（匀速）；拉扯前清零速度避免物理与 tween 打架。
	var unified_dir := Vector2(1.0, 0.15).normalized()
	var D := final_warn_horse_pull_duration
	var dist := limb_pull_travel_distance + limb_outscreen_margin
	var pull_delta := unified_dir * dist
	for h0 in horses:
		_zero_velocity_if_characterbody2d(h0)
	_zero_velocity_if_characterbody2d(player)

	var tw := create_tween()
	tw.set_parallel(true)
	for horse3 in horses:
		if horse3:
			var ht := horse3.global_position + pull_delta
			tw.tween_property(horse3, NodePath("global_position"), ht, D).set_trans(Tween.TRANS_LINEAR)
	var pt := player.global_position + pull_delta
	tw.tween_property(player, NodePath("global_position"), pt, D).set_trans(Tween.TRANS_LINEAR)
	await tw.finished

	for rope2 in ropes:
		if is_instance_valid(rope2):
			rope2.queue_free()

	if is_instance_valid(Game) and Game.player_stats:
		Game.player_stats.health = 0

	if saved_input != null and is_instance_valid(player) and "enable_input_control" in player:
		if is_instance_valid(Game) and Game.player_stats and Game.player_stats.health > 0:
			player.set("enable_input_control", saved_input)


func _set_final_dialog_input_and_camera_lock(enable_focus: bool, focus_world: Vector2) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	_final_dialog_input_locked_player = p
	_final_dialog_input_locked_saved_enable_input = null
	if p == null:
		return
	if "enable_input_control" in p:
		_final_dialog_input_locked_saved_enable_input = p.get("enable_input_control")
		p.set("enable_input_control", false)
	if p.has_method("set_camera_drag_ignore_player_input"):
		p.call("set_camera_drag_ignore_player_input", true)
	if enable_focus:
		_pull_player_camera_to_world(focus_world, camera_pull_duration_seconds)


func _clear_final_dialog_input_and_camera_lock() -> void:
	var p := _final_dialog_input_locked_player
	if p == null or not is_instance_valid(p):
		_final_dialog_input_locked_player = null
		_final_dialog_input_locked_saved_enable_input = null
		return
	_restore_player_camera(camera_return_duration_seconds)
	await _await_seconds_safe(maxf(0.05, final_dialog_camera_return_wait_seconds))
	await _await_player_camera_recently_centered(0.55, maxf(0.05, camera_return_duration_seconds + 0.08))
	if p.has_method("set_camera_drag_ignore_player_input"):
		p.call("set_camera_drag_ignore_player_input", false)
	if _final_dialog_input_locked_saved_enable_input != null and "enable_input_control" in p:
		p.set("enable_input_control", _final_dialog_input_locked_saved_enable_input)
	_final_dialog_input_locked_player = null
	_final_dialog_input_locked_saved_enable_input = null


func _await_player_camera_recently_centered(threshold: float = 0.55, max_wait_seconds: float = 6.0) -> void:
	var cam := _get_player_camera2d()
	if cam == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var elapsed := 0.0
	var dt := 1.0 / 60.0
	var limit := maxf(0.05, max_wait_seconds)
	while elapsed < limit:
		if not is_instance_valid(cam):
			return
		if cam.position.length() <= maxf(0.05, threshold):
			return
		if not await _await_process_frame_safe():
			return
		elapsed += dt


func _resolve_player_camera_base_local(player: Node2D) -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.ZERO
	var marker := player.get_node_or_null("CameraAimMarker") as Node2D
	return marker.position if marker != null else Vector2.ZERO


func _resolve_player_camera_base_world(player: Node2D) -> Vector2:
	if player == null or not is_instance_valid(player):
		return Vector2.ZERO
	var marker := player.get_node_or_null("CameraAimMarker") as Node2D
	return marker.global_position if marker != null else player.global_position


func _pull_player_camera_to_world(target_world: Vector2, duration_seconds: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or not is_instance_valid(p):
		return
	if not p.has_method("set_camera_focus_target_world"):
		return
	var speed := 1200.0
	var cam := _get_player_camera2d()
	if cam != null:
		var base_local := _resolve_player_camera_base_local(p)
		var base_world := _resolve_player_camera_base_world(p)
		var desired_local := base_local + (target_world - base_world)
		var dist := cam.position.distance_to(desired_local)
		speed = dist / maxf(0.01, duration_seconds)
	p.call("set_camera_focus_target_world", target_world, maxf(1.0, speed))


func _restore_player_camera(duration_seconds: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null or not is_instance_valid(p):
		return
	if not p.has_method("clear_camera_focus_target"):
		return
	var speed := 1200.0
	var cam := _get_player_camera2d()
	if cam != null:
		var base_local := _resolve_player_camera_base_local(p)
		var dist := cam.position.distance_to(base_local)
		speed = dist / maxf(0.01, duration_seconds)
	p.call("clear_camera_focus_target", maxf(1.0, speed))


func _get_five_horses_ordered(main: Node2D, minors: Node2D) -> Array[Node2D]:
	var out: Array[Node2D] = [main]
	var order: Array[StringName] = [&"MinorGrey", &"MinorWhite", &"MinorBlack", &"MinorRed"]
	for nm in order:
		var h := minors.get_node_or_null(String(nm)) as Node2D
		if h:
			out.append(h)
	return out


func _horse_needs_finale_entry(horse: Node2D) -> bool:
	if horse == null:
		return false
	if not horse.visible:
		return true
	if horse.process_mode == Node.PROCESS_MODE_DISABLED:
		return true
	return false


func _finale_rally_position(horse: Node2D, main: Node2D, minors: Node2D) -> Vector2:
	if horse == main:
		var m := get_node_or_null(main_horse_spawn_path) as Node2D
		if m:
			return m.global_position
		return main.global_position
	match StringName(horse.name):
		&"MinorGrey":
			var g := _spawn_marker_for_minor(&"MinorGrey")
			return g.global_position if g else horse.global_position
		&"MinorWhite":
			var w := _spawn_marker_for_minor(&"MinorWhite")
			return w.global_position if w else horse.global_position
		&"MinorBlack":
			var b := _spawn_marker_for_minor(&"MinorBlack")
			return b.global_position if b else horse.global_position
		&"MinorRed":
			var r := _spawn_marker_for_minor(&"MinorRed")
			return r.global_position if r else horse.global_position
		_:
			return horse.global_position


func _finale_entry_start_pos(rally: Vector2, shang_center: Vector2) -> Vector2:
	var away := rally - shang_center
	if away.length_squared() < 1.0:
		away = Vector2.RIGHT * final_warn_entry_push_distance
	else:
		away = away.normalized() * final_warn_entry_push_distance
	return rally + away


func _get_player_camera2d() -> Camera2D:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var p := tree.get_first_node_in_group("player") as Node2D
	if p == null:
		return null
	return p.get_node_or_null("Camera2D") as Camera2D


## 五马围到目标周围圆环（半径 fatal_pull_surround_radius_px），再进入连绳
func _tween_fatal_pull_horses_surround(target_global: Vector2, horses: Array[Node2D], _main: Node2D, _minors: Node2D) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	var added := 0
	var n := horses.size()
	for i in n:
		var horse := horses[i] as Node2D
		if horse == null:
			continue
		horse.visible = true
		horse.process_mode = Node.PROCESS_MODE_INHERIT
		var ang := -PI * 0.5 + TAU * float(i) / float(max(n, 1))
		var ring := target_global + Vector2(cos(ang), sin(ang)) * fatal_pull_surround_radius_px
		tw.tween_property(horse, NodePath("global_position"), ring, fatal_pull_surround_rush_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		added += 1
	if added > 0:
		await tw.finished


func _tween_finale_horses_enter_scene(horses: Array[Node2D], main: Node2D, minors: Node2D, shang_center: Vector2) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	var added := false
	for horse in horses:
		if horse == null:
			continue
		horse.visible = true
		horse.process_mode = Node.PROCESS_MODE_INHERIT
		var rally := _finale_rally_position(horse, main, minors)
		if _horse_needs_finale_entry(horse):
			horse.global_position = _finale_entry_start_pos(rally, shang_center)
			tw.tween_property(horse, NodePath("global_position"), rally, final_warn_horse_entry_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			added = true
	if added:
		await tw.finished


func _tween_rope_extend_all(
	ropes: Array[Node2D],
	seconds: float,
	pan_camera: Camera2D = null,
	camera_end_position_local: Vector2 = Vector2.ZERO,
	camera_pan_duration: float = -1.0
) -> void:
	var has_rope := false
	for rope in ropes:
		if rope != null and rope.has_method("set_extend_progress"):
			has_rope = true
			break
	var do_cam := pan_camera != null and camera_pan_duration > 0.0
	if not has_rope and not do_cam:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	for rope in ropes:
		if rope and rope.has_method("set_extend_progress"):
			tw.tween_method(Callable(rope, "set_extend_progress"), 0.0, 1.0, seconds).set_trans(Tween.TRANS_LINEAR)
	if do_cam:
		tw.tween_property(pan_camera, "position", camera_end_position_local, camera_pan_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _show_rope_contact_hint_fire_and_forget(message: String) -> void:
	var one_line := message.replace("\n", " ")
	print("[BossPhase] 绳索已接触目标: ", one_line)
	var lab := get_node_or_null(rope_limb_hint_label_path) as Label
	if lab == null or not is_instance_valid(lab):
		return
	lab.text = message
	lab.visible = true
	lab.modulate = Color(1, 1, 1, 1)
	var tree := get_tree()
	if tree == null:
		return
	var tw := tree.create_timer(rope_contact_hint_duration)
	tw.timeout.connect(
		func() -> void:
			if is_instance_valid(lab):
				lab.visible = false
	,
		CONNECT_ONE_SHOT
	)


func _phase_to_enter_broadcast_text(phase: BossHorseTypes.BossPhase) -> String:
	match phase:
		BossHorseTypes.BossPhase.GREY_SOLO:
			return "灰马进入了直播间"
		BossHorseTypes.BossPhase.WHITE_SOLO:
			return "白马进入了直播间"
		BossHorseTypes.BossPhase.BLACK_SOLO:
			return "黑马进入了直播间"
		BossHorseTypes.BossPhase.RED_SOLO:
			return "红马进入了直播间"
		BossHorseTypes.BossPhase.FINAL_WARNING_20:
			return "主马进入了直播间"
		_:
			return ""


func _show_phase_enter_hint_if_needed(phase: BossHorseTypes.BossPhase) -> void:
	var msg := _phase_to_enter_broadcast_text(phase)
	if msg == "":
		return
	var lab := get_node_or_null(phase_enter_hint_label_path) as Label
	if lab == null or not is_instance_valid(lab):
		return
	lab.text = msg
	lab.visible = true
	lab.modulate = Color(1, 1, 1, 1)
	var tree := get_tree()
	if tree == null:
		return
	var tw := tree.create_timer(maxf(0.2, phase_enter_hint_duration))
	tw.timeout.connect(
		func() -> void:
			if is_instance_valid(lab):
				lab.visible = false
	,
		CONNECT_ONE_SHOT
	)


func _collect_five_horses(main: Node2D, minors: Node2D) -> Array[Node2D]:
	return _get_five_horses_ordered(main, minors)


func _collect_shangyang_markers(shangyang: Node2D) -> Array[Node2D]:
	if shangyang and shangyang.has_method("get_limb_marker_nodes"):
		var queried: Array = shangyang.call("get_limb_marker_nodes")
		var typed: Array[Node2D] = []
		for item in queried:
			if item is Node2D:
				typed.append(item as Node2D)
		return typed
	var markers: Array[Node2D] = []
	var root := shangyang.get_node_or_null("LimbMarkers")
	if root:
		for c in root.get_children():
			if c is Node2D:
				markers.append(c as Node2D)
	return markers


func _spawn_shangyang_limbs(parent: Node2D, markers: Array[Node2D]) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if shangyang_limb_scene == null:
		return result
	for i in markers.size():
		var marker := markers[i]
		if marker == null:
			continue
		var limb := shangyang_limb_scene.instantiate() as Node2D
		if limb == null:
			continue
		parent.add_child(limb)
		limb.global_position = marker.global_position
		if limb.has_method("set_follow_target"):
			limb.call("set_follow_target", marker)
		if limb.has_method("apply_limb_visual"):
			if i == 0:
				limb.call("apply_limb_visual", 0) # HEAD
			elif i <= 2:
				limb.call("apply_limb_visual", 1) # HAND
			else:
				limb.call("apply_limb_visual", 2) # FOOT
		result.append(limb)
	return result


func _freeze_limb_following(limbs: Array[Node2D]) -> void:
	for l in limbs:
		if l != null and is_instance_valid(l) and l.has_method("freeze_follow"):
			l.call("freeze_follow")


func _filter_valid_limbs(limbs: Array[Node2D]) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for l in limbs:
		if l != null and is_instance_valid(l):
			out.append(l)
	return out


func _consume_warning_spawned_limbs_or_spawn(parent: Node2D, markers: Array[Node2D]) -> Array[Node2D]:
	_warning_spawned_limbs = _filter_valid_limbs(_warning_spawned_limbs)
	if _warning_spawned_limbs.size() >= 5:
		var reused := _warning_spawned_limbs
		_warning_spawned_limbs = []
		return reused
	return _spawn_shangyang_limbs(parent, markers)


func _pair_horses_to_limbs_by_nearest(horses: Array[Node2D], limbs: Array[Node2D]) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	var remaining := limbs.duplicate()
	for horse in horses:
		if remaining.is_empty():
			break
		var best_idx := 0
		var best_dist := INF
		for i in remaining.size():
			var limb := remaining[i] as Node2D
			if limb == null:
				continue
			var d := horse.global_position.distance_squared_to(limb.global_position)
			if d < best_dist:
				best_dist = d
				best_idx = i
		var picked := remaining[best_idx] as Node2D
		remaining.remove_at(best_idx)
		pairs.append({"horse": horse, "limb": picked})
	return pairs


func _spawn_rope_between(parent: Node2D, horse: Node2D, limb: Node2D) -> Node2D:
	if rope_scene == null:
		return null
	var rope := rope_scene.instantiate() as Node2D
	if rope == null:
		return null
	parent.add_child(rope)
	if rope.has_method("bind_endpoints"):
		# 视觉校正：绳子瞄准点在肢体锚点基础上下移 32 像素。
		rope.call("bind_endpoints", horse, limb, Vector2.ZERO, Vector2(0, 32), 0.0)
	return rope


func _tween_pull_horses_then_limbs(pairs: Array[Dictionary], main_horse: Node2D, shangyang: Node2D = null) -> void:
	var D := final_warn_horse_pull_duration
	var delay := clampf(final_warn_limb_follow_delay_seconds, 0.0, maxf(D - 0.05, 0.0))
	var limb_dur := maxf(D - delay, 0.05)
	print("[BossPhase] _tween_pull_horses_then_limbs 开始 pairs=%d D=%.2f delay=%.2f limb_dur=%.2f（单 tween 并行）" % [pairs.size(), D, delay, limb_dur])

	# 马与肢体放在同一 Tween 的并行轨道：肢体用 set_delay(delay)，避免 tw_h / tw_l 分两次 await 时错过 finished。
	var tw := create_tween()
	tw.set_parallel(true)
	var n_pairs := 0
	for pair in pairs:
		var horse := pair["horse"] as Node2D
		var limb := pair["limb"] as Node2D
		if horse == null or limb == null:
			continue
		var dir := _pull_dir_for_horse(horse, main_horse)
		var dist := limb_pull_travel_distance + limb_outscreen_margin
		var horse_target := horse.global_position + dir * dist
		var limb_target := limb.global_position + dir * dist
		var horse_label := String(horse.name)
		var limb_label := "%s/%s" % [String(limb.name), limb.get_path()]
		var te_h := tw.tween_property(horse, NodePath("global_position"), horse_target, D).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		te_h.finished.connect(func() -> void: print("[BossPhase] pull tween 单条结束: 马 ", horse_label), CONNECT_ONE_SHOT)
		var te_l := tw.tween_property(limb, NodePath("global_position"), limb_target, limb_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(delay)
		te_l.finished.connect(func() -> void: print("[BossPhase] pull tween 单条结束: 肢体 ", limb_label), CONNECT_ONE_SHOT)
		n_pairs += 1
	print("[BossPhase] _tween_pull_horses_then_limbs: 已添加 %d 组马+肢体（同一并行 tween）" % n_pairs)
	if n_pairs == 0:
		return
	if is_instance_valid(shangyang) and shangyang.has_method("play_be_pull_animation"):
		var tree2 := get_tree()
		if tree2 == null:
			return
		var t := tree2.create_timer(delay)
		t.timeout.connect(
			func() -> void:
				if is_instance_valid(shangyang):
					shangyang.call("play_be_pull_animation")
				# 肢体离开商鞅时，播放两次全屏白闪
				if Game != null and Game.has_method("_play_world3_death_fullscreen_flash"):
					Game._play_world3_death_fullscreen_flash()
					var flash2 := get_tree().create_timer(0.2)
					flash2.timeout.connect(
						func():
							if Game != null and is_instance_valid(Game):
								Game._play_world3_death_fullscreen_flash()
					,
						CONNECT_ONE_SHOT
					)
		,
			CONNECT_ONE_SHOT
		)
	print("[BossPhase] _tween_pull_horses_then_limbs: 等待合并 tween.finished …")
	await tw.finished
	print("[BossPhase] _tween_pull_horses_then_limbs: 合并 tween 已全部结束")

	for pair in pairs:
		var limb3 := pair["limb"] as Node2D
		if limb3 and is_instance_valid(limb3):
			limb3.queue_free()


func _get_view_bounds_x() -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Vector2(-10000.0, 10000.0)
	var vp := get_viewport()
	if vp == null:
		return Vector2(-10000.0, 10000.0)
	var rect := vp.get_visible_rect().size
	var half_w := rect.x * 0.5 * camera.zoom.x
	var center := camera.get_screen_center_position()
	return Vector2(center.x - half_w, center.x + half_w)


func _pull_dir_for_horse(horse: Node2D, main_horse: Node2D) -> Vector2:
	if horse == main_horse:
		return Vector2.UP
	if horse != main_horse and "horse_id" in horse:
		match horse.get("horse_id"):
			BossHorseTypes.HorseId.GREY:
				return Vector2.LEFT
			BossHorseTypes.HorseId.WHITE:
				return Vector2.RIGHT
			BossHorseTypes.HorseId.BLACK:
				return Vector2(-1.0, 1.0).normalized()
			BossHorseTypes.HorseId.RED:
				return Vector2(1.0, 1.0).normalized()
	return Vector2.RIGHT


func _clear_all_minors_runtime(minors: Node2D) -> void:
	#region agent log
	_debug_log("run10", "H1", "boss_horse_phase_controller.gd:_clear_all_minors_runtime", "entry", {
		"before_count": minors.get_child_count()
	})
	#endregion
	for c in minors.get_children():
		if c is Node:
			(c as Node).queue_free()


func _ensure_all_minors_present(minors: Node2D) -> void:
	var order: Array[StringName] = [&"MinorGrey", &"MinorWhite", &"MinorBlack", &"MinorRed"]
	for nm in order:
		_get_or_spawn_minor(minors, nm)


func _get_or_spawn_minor(minors: Node2D, minor_name: StringName) -> Node2D:
	if minors == null or minor_name == StringName():
		return null
	var existed := minors.get_node_or_null(String(minor_name)) as Node2D
	if existed != null:
		#region agent log
		_debug_log("run13", "H2", "boss_horse_phase_controller.gd:_get_or_spawn_minor", "reuse_existing_minor", {
			"minor_name": String(minor_name),
			"horse_id": int(existed.get("horse_id")) if "horse_id" in existed else -1
		})
		#endregion
		return existed
	if not use_dynamic_minor_spawn:
		return null
	if dynamic_minor_scene == null:
		return null
	var spawned := dynamic_minor_scene.instantiate() as Node2D
	if spawned == null:
		return null
	spawned.name = String(minor_name)
	if "horse_id" in spawned:
		var key := String(minor_name)
		if _minor_name_to_horse_id.has(key):
			spawned.set("horse_id", _minor_name_to_horse_id[key])
	#region agent log
	_debug_log("run13", "H2", "boss_horse_phase_controller.gd:_get_or_spawn_minor", "spawn_minor_assigned_horse_id", {
		"minor_name": String(minor_name),
		"assigned_horse_id": int(spawned.get("horse_id")) if "horse_id" in spawned else -1
	})
	#endregion
	minors.add_child(spawned)
	spawned.visible = false
	spawned.process_mode = Node.PROCESS_MODE_DISABLED
	_set_horse_movement(spawned, false)
	return spawned


func ensure_saved_minors_present(minors_state: Dictionary) -> void:
	# 读档时，_ready 可能已清空 Minors；这里按存档键名先补回节点，再由 world3_boss_arena.from_dict 应用状态。
	if minors_state == null or minors_state.is_empty():
		return
	var minors := get_node_or_null(minors_path) as Node2D
	if minors == null:
		return
	#region agent log
	_debug_log("run10", "H2", "boss_horse_phase_controller.gd:ensure_saved_minors_present", "entry", {
		"saved_keys": minors_state.keys(),
		"before_count": minors.get_child_count()
	})
	#endregion
	for raw_name in minors_state.keys():
		var nm := StringName(String(raw_name))
		if nm == StringName():
			continue
		_get_or_spawn_minor(minors, nm)
	#region agent log
	_debug_log("run10", "H2", "boss_horse_phase_controller.gd:ensure_saved_minors_present", "exit", {
		"after_count": minors.get_child_count()
	})
	#endregion


func restore_minor_horse_ids(minors_root: Node) -> void:
	for c in minors_root.get_children():
		if not (c is Node2D):
			continue
		var key := String(c.name)
		if not _minor_name_to_horse_id.has(key) or not "horse_id" in c:
			continue
		var expected := int(_minor_name_to_horse_id[key])
		if c.get("horse_id") != expected:
			c.set("horse_id", expected)
			if c.has_method("refresh_visual_to_horse_id"):
				c.refresh_visual_to_horse_id()


func restore_combat_state_from_save(saved_phase: int, should_restore_direct_minors: bool) -> void:
	var target_phase := clampi(saved_phase, int(BossHorseTypes.BossPhase.INTRO), int(BossHorseTypes.BossPhase.CHAIN_CINEMATIC))
	#region agent log
	_debug_log("run12", "H6", "boss_horse_phase_controller.gd:restore_combat_state_from_save", "entry", {
		"saved_phase": saved_phase,
		"target_phase": target_phase,
		"current_phase_before": int(current_phase),
		"should_restore_direct_minors": should_restore_direct_minors
	})
	#endregion
	if target_phase > int(BossHorseTypes.BossPhase.INTRO) and int(current_phase) != target_phase:
		request_phase(target_phase as BossHorseTypes.BossPhase)
	if should_restore_direct_minors:
		_apply_cumulative_minors_for_phase(target_phase as BossHorseTypes.BossPhase)
	var main := get_node_or_null(main_horse_path) as Node2D
	if main != null and is_instance_valid(main):
		main.visible = true
		main.process_mode = Node.PROCESS_MODE_INHERIT
		if main.has_method("set_movement_enabled"):
			main.call("set_movement_enabled", true)
	var minors := get_node_or_null(minors_path) as Node2D
	if minors != null:
		for c in minors.get_children():
			if not (c is Node2D):
				continue
			var m := c as Node2D
			m.visible = true
			m.process_mode = Node.PROCESS_MODE_INHERIT
			if m.has_method("set_movement_enabled"):
				m.call("set_movement_enabled", true)
	#region agent log
	_debug_log("run12", "H6", "boss_horse_phase_controller.gd:restore_combat_state_from_save", "exit", {
		"current_phase_after": int(current_phase),
		"minors_count": minors.get_child_count() if minors != null else -1,
		"main_visible": main.visible if main != null else false,
		"main_process_mode": main.process_mode if main != null else -1
	})
	#endregion


func _debug_log(run_id: String, hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	var payload := {
		"sessionId": "5144a3",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000.0)
	}
	var f := FileAccess.open(_DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(_DEBUG_LOG_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.close()
