extends Node2D

@export var stats:Stats

@export var heart_cell_scene: PackedScene = preload("res://system/ui/heart_cell.tscn")
@export var max_hearts_cap: int = 20
@export var ink_slot_scene: PackedScene = preload("res://system/ui/ink_slot.tscn")
@export var ink_per_attack: int = 1
## <=0 表示不限制格子上限，直接按 max_ink 生成
@export var max_ink_slots_cap: int = -1

@onready var hearts_box: HBoxContainer = $Hearts
@onready var inks_box: HBoxContainer = $Inks
@onready var summon_skill: Control = $SummonSkill
@onready var summon_bar: TextureProgressBar = $SummonSkill/CooldownBar
@onready var heart_ink_stinger: AudioStreamPlayer = get_node_or_null("HeartInkStinger") as AudioStreamPlayer
@onready var ink_recover_sfx: AudioStreamPlayer = get_node_or_null("InkRecoverSfx") as AudioStreamPlayer

var _cells: Array[HeartCell] = []
var _display_health: int = 0
var _target_health: int = 0
var _is_animating: bool = false

var _ink_slots: Array[Node] = []
var _display_ink_slots_full: int = 0
var _target_ink_slots_full: int = 0
var _ink_is_animating: bool = false
var _recovering_slot: Node = null
var _pending_ink_use_steps: int = 0
var _ignore_ink_changed_once: bool = false


func _stats_valid() -> bool:
	return stats != null and is_instance_valid(stats)


func _ready() -> void:
	_bind_player_stats()
	# 玩家 _ready（含 add_to_group / stats 统一）可能晚于 UI，这里下一帧再绑一次，确保连到真实玩家 stats
	call_deferred("_rebind_stats_next_frame")
	if not _stats_valid():
		return
	_rebuild_hearts_if_needed(true)
	_display_health = int(stats.health)
	_target_health = _display_health
	_sync_cells_instant(_display_health, int(stats.max_health))
	_rebuild_ink_slots_if_needed(true)
	_display_ink_slots_full = _calc_full_ink_slots_from_stats()
	_target_ink_slots_full = _display_ink_slots_full
	_sync_ink_slots_instant(_display_ink_slots_full)
	_update_summon_skill_ui()
	
	# 占位：生成 1x1 白色纹理使 TextureProgressBar 可见；替换为真实贴图后删除此段
	if summon_bar != null and summon_bar.texture_under == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		var tex := ImageTexture.create_from_image(img)
		summon_bar.texture_under = tex
		summon_bar.texture_progress = tex
		summon_bar.tint_under = Color(0.12, 0.12, 0.12, 0.7)
		summon_bar.tint_progress = Color(0.95, 0.9, 0.25, 1.0)


func _rebind_stats_next_frame() -> void:
	await get_tree().process_frame
	_bind_player_stats()
	if not _stats_valid():
		return
	# 二次绑定后立刻全量同步，防止“数值变化了但 UI 不动”
	_rebuild_hearts_if_needed(true)
	_display_health = int(stats.health)
	_target_health = _display_health
	_sync_cells_instant(_display_health, int(stats.max_health))
	_rebuild_ink_slots_if_needed(true)
	_display_ink_slots_full = _calc_full_ink_slots_from_stats()
	_target_ink_slots_full = _display_ink_slots_full
	_sync_ink_slots_instant(_display_ink_slots_full)
	_update_summon_skill_ui()


func _process(_delta: float) -> void:
	_update_summon_skill_ui()


func _bind_player_stats() -> void:
	# 血量 UI 必须与玩家真实状态强绑定：优先跟随玩家节点上的 stats，其次回退到 Game.player_stats
	if _stats_valid():
		if stats.health_changed.is_connected(_on_health_changed):
			stats.health_changed.disconnect(_on_health_changed)
		if stats.ink_changed.is_connected(_on_ink_changed):
			stats.ink_changed.disconnect(_on_ink_changed)
	var resolved: Stats = null
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		var ps: Variant = p.get("stats")
		if ps is Stats and is_instance_valid(ps):
			resolved = ps as Stats
	if resolved == null and Game.player_stats != null and is_instance_valid(Game.player_stats):
		resolved = Game.player_stats
	stats = resolved
	if not _stats_valid():
		return
	if not stats.health_changed.is_connected(_on_health_changed):
		stats.health_changed.connect(_on_health_changed)
	if not stats.ink_changed.is_connected(_on_ink_changed):
		stats.ink_changed.connect(_on_ink_changed)
	

func _on_health_changed() -> void:
	if not _stats_valid():
		_bind_player_stats()
		if not _stats_valid():
			return
	_target_health = int(stats.health)
	_rebuild_hearts_if_needed(false)
	if _is_animating:
		return
	_is_animating = true
	call_deferred("_run_health_animation_queue")


func _rebuild_hearts_if_needed(force: bool) -> void:
	if not _stats_valid():
		return
	if hearts_box == null:
		return
	var max_health: int = maxi(0, int(stats.max_health))
	# 两滴血对应一个心格
	var need_hearts := int(ceil(float(max_health) / 2.0))
	need_hearts = clampi(need_hearts, 1, max_hearts_cap)
	if not force and _cells.size() == need_hearts:
		return
	for c in _cells:
		if c != null and is_instance_valid(c):
			c.queue_free()
	_cells.clear()
	for i in need_hearts:
		var inst := heart_cell_scene.instantiate() as Node
		if inst == null:
			continue
		hearts_box.add_child(inst)
		var cell := inst as HeartCell
		if cell != null:
			_cells.append(cell)
	# 立即按当前血量刷新
	_sync_cells_instant(_display_health, max_health)


func _sync_cells_instant(health_value: int, max_health_value: int) -> void:
	if _cells.is_empty():
		return
	var max_h: int = maxi(0, max_health_value)
	var hp := clampi(health_value, 0, max_h)
	# 右侧为“最后一颗心”
	for idx in _cells.size():
		var cell := _cells[idx]
		if cell == null:
			continue
		var heart_from_left := idx
		var heart_value := hp - heart_from_left * 2
		var st := 0
		if heart_value >= 2:
			st = 2
		elif heart_value == 1:
			st = 1
		else:
			st = 0
		cell.set_state_instant(st)


func _run_health_animation_queue() -> void:
	if not _stats_valid():
		_is_animating = false
		return
	var max_h: int = maxi(0, int(stats.max_health))
	_target_health = clampi(_target_health, 0, max_h)
	_display_health = clampi(_display_health, 0, max_h)
	while _display_health != _target_health:
		var step := -1 if _target_health < _display_health else 1
		if step < 0:
			await _apply_one_damage_step()
			_display_health -= 1
		else:
			await _apply_one_heal_step()
			_display_health += 1
		_display_health = clampi(_display_health, 0, max_h)
		if not _stats_valid():
			break
		_target_health = clampi(int(stats.health), 0, max_h)
	# 最终校正
	_sync_cells_instant(_display_health, max_h)
	_is_animating = false


func _rightmost_cell_that_can_damage() -> HeartCell:
	for i in range(_cells.size() - 1, -1, -1):
		var c := _cells[i]
		if c != null and is_instance_valid(c) and c.state > 0:
			return c
	return null


func _leftmost_cell_that_can_heal() -> HeartCell:
	for i in _cells.size():
		var c := _cells[i]
		if c != null and is_instance_valid(c) and c.state < 2:
			return c
	return null


func _apply_one_damage_step() -> void:
	var c := _rightmost_cell_that_can_damage()
	if c == null:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		return
	_play_heart_ink_stinger(1.12)
	await c.play_damage_step()


func _apply_one_heal_step() -> void:
	var c := _leftmost_cell_that_can_heal()
	if c == null:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		return
	_play_heart_ink_stinger(1.28)
	await c.play_heal_step()


## ===== 墨水格（一次攻击一格） =====

func consume_ink_once() -> bool:
	# 提供给玩家：尝试消耗 1 格墨水（从右侧开始）
	if _display_ink_slots_full <= 0:
		return false
	# 先扣 stats（作为“真实值”）；UI 会在 ink_changed 里做动画与恢复逻辑
	var cost: int = maxi(1, ink_per_attack)
	stats.ink = maxf(0.0, stats.ink - float(cost))
	return true


func _on_ink_changed() -> void:
	if not _stats_valid():
		_bind_player_stats()
		if not _stats_valid():
			return
	if _ignore_ink_changed_once:
		_ignore_ink_changed_once = false
		return
	_target_ink_slots_full = _calc_full_ink_slots_from_stats()
	_rebuild_ink_slots_if_needed(false)
	var diff := _display_ink_slots_full - _target_ink_slots_full
	if diff > 0:
		_pending_ink_use_steps += diff
		if not _ink_is_animating:
			_ink_is_animating = true
			call_deferred("_run_pending_ink_uses")
	elif diff < 0:
		# 墨水增加：通常由“恢复动画结束后发放”触发，UI 已经提前置满；这里直接同步到最新值
		_display_ink_slots_full = _target_ink_slots_full
		_sync_ink_slots_instant(_display_ink_slots_full)


func _calc_full_ink_slots_from_stats() -> int:
	if not _stats_valid():
		return 0
	var per: int = maxi(1, ink_per_attack)
	var max_slots := maxi(1, int(floor(float(stats.max_ink) / float(per))))
	if max_ink_slots_cap > 0:
		max_slots = clampi(max_slots, 1, max_ink_slots_cap)
	var full := int(floor(float(stats.ink) / float(per)))
	return clampi(full, 0, max_slots)


func _rebuild_ink_slots_if_needed(force: bool) -> void:
	if inks_box == null:
		return
	var per: int = maxi(1, ink_per_attack)
	var need := maxi(1, int(floor(float(stats.max_ink) / float(per))))
	if max_ink_slots_cap > 0:
		need = clampi(need, 1, max_ink_slots_cap)
	if not force and _ink_slots.size() == need:
		return
	_recovering_slot = null
	for s in _ink_slots:
		if s != null and is_instance_valid(s):
			s.queue_free()
	_ink_slots.clear()
	for i in need:
		var inst := ink_slot_scene.instantiate() as Node
		if inst == null:
			continue
		inks_box.add_child(inst)
		var slot: Node = inst
		if slot != null:
			_ink_slots.append(slot)
			if slot.has_signal("recover_finished"):
				slot.connect("recover_finished", Callable(self, "_on_ink_slot_recover_finished"))


func _sync_ink_slots_instant(full_count: int) -> void:
	var n := _ink_slots.size()
	for i in n:
		var slot: Node = _ink_slots[i]
		if slot == null:
			continue
		# 约定：左到右排布时，满格连续占据左侧；消耗从右往左会优先把右侧变空
		var is_full: bool = i < full_count
		if slot.has_method("set_state_instant"):
			slot.call("set_state_instant", 1 if is_full else 0)


func _run_pending_ink_uses() -> void:
	# 只串行“消耗动画”；恢复动画并行且可中途转移
	while _pending_ink_use_steps > 0:
		_pending_ink_use_steps -= 1
		await _apply_one_ink_use_step()
		_display_ink_slots_full = maxi(0, _display_ink_slots_full - 1)
		# 这里不立即强制同步，避免把 use 动画瞬间覆盖成 empty
	# 如果还有空槽且当前没有在恢复，则启动恢复链
	if _recovering_slot == null:
		_try_start_recover_chain_on_leftmost_empty()
	_ink_is_animating = false


func _rightmost_full_slot() -> Node:
	for i in range(_ink_slots.size() - 1, -1, -1):
		var s: Node = _ink_slots[i]
		if s != null and is_instance_valid(s) and int(s.get("state")) == 1:
			return s
	return null


func _apply_one_ink_use_step() -> void:
	var used: Node = _rightmost_full_slot()
	if used == null:
		await get_tree().process_frame
		return

	# 规则：恢复中若再次消耗，则把“正在恢复瓶”和其左侧瓶子交换位置；
	# 恢复动画在原恢复瓶上继续，不转移进度。
	if _recovering_slot != null and is_instance_valid(_recovering_slot) and _recovering_slot != used:
		_swap_slot_with_left_neighbor(_recovering_slot)

	# 消耗：先播 use，再立即切 empty（由 slot.play_use_step 内完成）
	_play_heart_ink_stinger(0.95)
	if used.has_method("play_use_step"):
		await used.call("play_use_step")

	# 若当前无恢复任务，则立刻开始 recover（无额外间隔）
	if _recovering_slot == null:
		_recovering_slot = used
		if _recovering_slot.has_method("start_recover"):
			_recovering_slot.call("start_recover", {})


func _on_ink_slot_recover_finished(slot: Node) -> void:
	# 恢复完毕才“获得一次攻击墨水”
	if slot != _recovering_slot:
		return
	_recovering_slot = null

	var per: int = maxi(1, ink_per_attack)
	var next := minf(float(stats.max_ink), float(stats.ink) + float(per))
	_ignore_ink_changed_once = true
	stats.ink = next
	_display_ink_slots_full = _calc_full_ink_slots_from_stats()
	_sync_ink_slots_instant(_display_ink_slots_full)
	if ink_recover_sfx != null and ink_recover_sfx.stream != null:
		ink_recover_sfx.play()
	# 如果还有空槽，继续恢复下一格（仍然保证只有 1 格在恢复）
	_try_start_recover_chain_on_leftmost_empty()


func _play_heart_ink_stinger(pitch: float = 1.0) -> void:
	if heart_ink_stinger == null or heart_ink_stinger.stream == null:
		return
	heart_ink_stinger.pitch_scale = pitch
	heart_ink_stinger.play()


func _leftmost_empty_slot() -> Node:
	for i in _ink_slots.size():
		var s: Node = _ink_slots[i]
		if s != null and is_instance_valid(s) and int(s.get("state")) == 0:
			return s
	return null


func _try_start_recover_chain_on_leftmost_empty() -> void:
	if _recovering_slot != null:
		return
	# 只有当还未满时才恢复
	if _calc_full_ink_slots_from_stats() >= _ink_slots.size():
		return
	var s: Node = _leftmost_empty_slot()
	if s == null:
		return
	_recovering_slot = s
	if _recovering_slot.has_method("start_recover"):
		_recovering_slot.call("start_recover", {})


func _update_summon_skill_ui() -> void:
	if summon_skill == null:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		if summon_bar != null:
			summon_bar.visible = false
			summon_bar.value = 0.0
		return
	var unlocked := false
	if "shangyang_summon_unlocked" in p:
		unlocked = bool(p.get("shangyang_summon_unlocked"))
	
	# 没有召唤权限时隐藏冷却条
	if summon_bar != null:
		summon_bar.visible = unlocked
	
	var cooldown_ratio := 0.0
	if p.has_method("get_summon_cooldown_ratio"):
		cooldown_ratio = clampf(float(p.call("get_summon_cooldown_ratio")), 0.0, 1.0)
	var cooling := cooldown_ratio < 0.999
	if summon_bar != null:
		summon_bar.value = cooldown_ratio
func _left_neighbor_slot(slot: Node) -> Node:
	var idx := _ink_slots.find(slot)
	if idx <= 0:
		return null
	var s: Node = _ink_slots[idx - 1]
	return s if s != null and is_instance_valid(s) else null


func _swap_slot_with_left_neighbor(slot: Node) -> void:
	if inks_box == null or slot == null:
		return
	var idx := _ink_slots.find(slot)
	if idx <= 0:
		return
	var left: Node = _ink_slots[idx - 1]
	if left == null or not is_instance_valid(left):
		return
	# 交换容器中的显示位置
	inks_box.move_child(slot, idx - 1)
	inks_box.move_child(left, idx)
	# 同步内部顺序，保证后续“左/右”逻辑一致
	_ink_slots[idx - 1] = slot
	_ink_slots[idx] = left


func _swap_slot_with_right_neighbor(slot: Node) -> void:
	if inks_box == null or slot == null:
		return
	var idx := _ink_slots.find(slot)
	if idx < 0 or idx >= _ink_slots.size() - 1:
		return
	var right: Node = _ink_slots[idx + 1]
	if right == null or not is_instance_valid(right):
		return
	# 交换容器中的显示位置
	inks_box.move_child(right, idx)
	inks_box.move_child(slot, idx + 1)
	# 同步内部顺序
	_ink_slots[idx] = right
	_ink_slots[idx + 1] = slot
	



	
