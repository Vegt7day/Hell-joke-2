extends Node2D

const FONT_HOTBAR := preload("res://assets/资源总库/11_字体/VonwaonBitmap-12px.ttf")
const FONT_16 := preload("res://assets/资源总库/11_字体/VonwaonBitmap-16px.ttf")
const SLOT_TEX := preload("res://assets/资源总库/03_图像_UI/格子.png")

@export var stats:Stats

@export var heart_cell_scene: PackedScene = preload("res://system/ui/heart_cell.tscn")
@export var max_hearts_cap: int = 20
@export var ink_slot_scene: PackedScene = preload("res://system/ui/ink_slot.tscn")
@export var ink_per_attack: int = 1
## <=0 表示不限制格子上限，直接按 max_ink 生成
@export var max_ink_slots_cap: int = -1

@onready var hearts_box: HBoxContainer = $Hearts
@onready var inks_box: HBoxContainer = $Inks
@onready var heart_ink_stinger: AudioStreamPlayer = get_node_or_null("HeartInkStinger") as AudioStreamPlayer
@onready var ink_recover_sfx: AudioStreamPlayer = get_node_or_null("InkRecoverSfx") as AudioStreamPlayer
## 快捷栏挂在玩家根下 ViewportHotbarHud（跟随视口）；可直接指向导出路径覆盖默认查找
@export var hotbar_row_path: NodePath = NodePath("")
var hotbar_row: HBoxContainer = null

var _inv_ref: PlayerInventory = null
var _hotbar_frames: Array[PanelContainer] = []
var _hotbar_icons: Array[TextureRect] = []
var _hotbar_qtys: Array[Label] = []
var _hotbar_qty_overlays: Array[Label] = []
var _hotbar_static_masks: Array[ColorRect] = []
var _hotbar_cd_bars: Array[ColorRect] = []
var _hotbar_style_normal: StyleBoxTexture
var _hotbar_style_selected: StyleBoxTexture

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


func _resolve_hotbar_row() -> HBoxContainer:
	if hotbar_row_path != NodePath():
		var node := get_node_or_null(hotbar_row_path)
		if node is HBoxContainer:
			return node as HBoxContainer
	var layer := get_parent()
	var player := layer.get_parent() if layer != null else null
	if player != null:
		var hb := player.get_node_or_null("ViewportHotbarHud/HotbarRoot/HotbarRow")
		if hb is HBoxContainer:
			return hb as HBoxContainer
	return null


func _ready() -> void:
	add_to_group(&"status_panel")
	hotbar_row = _resolve_hotbar_row()
	_hotbar_style_normal = StyleBoxTexture.new()
	_hotbar_style_normal.texture = SLOT_TEX
	_hotbar_style_normal.texture_margin_left = 2
	_hotbar_style_normal.texture_margin_top = 2
	_hotbar_style_normal.texture_margin_right = 2
	_hotbar_style_normal.texture_margin_bottom = 2
	_hotbar_style_normal.region_rect = Rect2(1, 1, 14, 14)
	_hotbar_style_normal.content_margin_left = 0
	_hotbar_style_normal.content_margin_right = 0
	_hotbar_style_normal.content_margin_top = 0
	_hotbar_style_normal.content_margin_bottom = 0
	_hotbar_style_selected = StyleBoxTexture.new()
	_hotbar_style_selected.texture = SLOT_TEX
	_hotbar_style_selected.texture_margin_left = 2
	_hotbar_style_selected.texture_margin_top = 2
	_hotbar_style_selected.texture_margin_right = 2
	_hotbar_style_selected.texture_margin_bottom = 2
	_hotbar_style_selected.region_rect = Rect2(17, 1, 14, 14)
	_hotbar_style_selected.content_margin_left = 0
	_hotbar_style_selected.content_margin_right = 0
	_hotbar_style_selected.content_margin_top = 0
	_hotbar_style_selected.content_margin_bottom = 0
	_build_hotbar_slots()
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
	_bind_inventory_ref()


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
	_bind_inventory_ref()


func _process(_delta: float) -> void:
	_update_hotbar_cd_bars()


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
	
	_bind_inventory_ref()


func _build_hotbar_slots() -> void:
	if hotbar_row == null:
		return
	for c in hotbar_row.get_children():
		c.queue_free()
	_hotbar_frames.clear()
	_hotbar_icons.clear()
	_hotbar_qtys.clear()
	for i in 8:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(30, 30)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override(&"panel", _hotbar_style_normal)
		var ctrl := Control.new()
		ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ctrl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_child(ctrl)
		var tr := TextureRect.new()
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.custom_minimum_size = Vector2(22, 22)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(4, 4)
		ctrl.add_child(tr)
		var lb := Label.new()
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lb.add_theme_font_override(&"font", FONT_16)
		lb.add_theme_font_size_override(&"font_size", 22)
		ctrl.add_child(lb)
		var qty := Label.new()
		qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		qty.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		qty.anchor_left = 0.0
		qty.anchor_top = 0.0
		qty.anchor_right = 1.0
		qty.anchor_bottom = 1.0
		qty.add_theme_font_override(&"font", FONT_HOTBAR)
		qty.add_theme_font_size_override(&"font_size", 10)
		ctrl.add_child(qty)
		hotbar_row.add_child(panel)
		_hotbar_frames.append(panel)
		_hotbar_icons.append(tr)
		_hotbar_qtys.append(lb)
		_hotbar_qty_overlays.append(qty)
		# 静态灰色掩膜：始终显示
		var static_mask := ColorRect.new()
		static_mask.color = Color(0.15, 0.15, 0.15, 0.35)
		static_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		static_mask.anchor_left = 0.0
		static_mask.anchor_top = 0.0
		static_mask.anchor_right = 1.0
		static_mask.anchor_bottom = 1.0
		static_mask.offset_left = 0
		static_mask.offset_right = 0
		static_mask.offset_top = 0
		static_mask.offset_bottom = 0
		ctrl.add_child(static_mask)
		_hotbar_static_masks.append(static_mask)
		# 动态 CD 条：灰色，从底部向上填充
		var cd_bar := ColorRect.new()
		cd_bar.color = Color(0.3, 0.3, 0.3, 0.65)
		cd_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd_bar.anchor_left = 0.0
		cd_bar.anchor_top = 1.0
		cd_bar.anchor_right = 1.0
		cd_bar.anchor_bottom = 1.0
		cd_bar.offset_left = 0
		cd_bar.offset_right = 0
		cd_bar.offset_top = 0
		cd_bar.offset_bottom = 0
		cd_bar.visible = false
		ctrl.add_child(cd_bar)
		_hotbar_cd_bars.append(cd_bar)


func _bind_inventory_ref() -> void:
	if hotbar_row == null:
		return
	var p := get_tree().get_first_node_in_group(&"player")
	var inv: PlayerInventory = null
	if p != null:
		inv = p.get_node_or_null("PlayerInventory") as PlayerInventory
	if inv == _inv_ref:
		if inv != null:
			_refresh_hotbar_ui()
		elif not _hotbar_frames.is_empty():
			_refresh_hotbar_ui()
		return
	if _inv_ref != null:
		if _inv_ref.inventory_changed.is_connected(_refresh_hotbar_ui):
			_inv_ref.inventory_changed.disconnect(_refresh_hotbar_ui)
		if _inv_ref.hotbar_selection_changed.is_connected(_on_hotbar_selection_changed_inv):
			_inv_ref.hotbar_selection_changed.disconnect(_on_hotbar_selection_changed_inv)
	_inv_ref = inv
	if _inv_ref != null:
		if not _inv_ref.inventory_changed.is_connected(_refresh_hotbar_ui):
			_inv_ref.inventory_changed.connect(_refresh_hotbar_ui)
		if not _inv_ref.hotbar_selection_changed.is_connected(_on_hotbar_selection_changed_inv):
			_inv_ref.hotbar_selection_changed.connect(_on_hotbar_selection_changed_inv)
	_refresh_hotbar_ui()


func _on_hotbar_selection_changed_inv(_idx: int) -> void:
	_refresh_hotbar_ui()
	_show_hotbar_tooltip(_idx)


## 快捷栏切换时在鼠标旁显示物品图标+名称，0.5s渐隐消失
func _show_hotbar_tooltip(idx: int) -> void:
	if _inv_ref == null or idx < 0 or idx >= _inv_ref.hotbar.size():
		return
	var slot := _inv_ref.hotbar[idx]
	if slot == null or slot.item == null:
		return
	if not is_inside_tree():
		return
	var root := get_tree().root
	if root == null:
		return
	# 创建浮动标签
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var item_name := slot.item.name
	var qty := slot.quantity
	if qty > 1:
		item_name += " x" + str(qty)
	label.text = item_name
	label.add_theme_font_override(&"font", FONT_HOTBAR)
	label.add_theme_font_size_override(&"font_size", 12)
	label.add_theme_color_override(&"font_color", Color(1, 1, 1, 1))
	# 放在光标右上角
	var mp := get_viewport().get_mouse_position()
	label.global_position = mp + Vector2(16, -28)
	label.modulate = Color(1, 1, 1, 0)
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.add_child(label)
	# 0.5s 渐隐动画
	var tw := create_tween()
	tw.tween_property(label, "modulate", Color(1, 1, 1, 1), 0.08)
	tw.tween_interval(0.15)
	tw.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.4)
	tw.finished.connect(label.queue_free)


func _refresh_hotbar_ui() -> void:
	if hotbar_row == null or _hotbar_frames.is_empty():
		return
	if _inv_ref == null:
		for i in _hotbar_frames.size():
			_paint_hotbar_cell(i, null)
		return
	for i in _hotbar_frames.size():
		var slot: InventorySlot = null
		if i < _inv_ref.hotbar.size():
			slot = _inv_ref.hotbar[i]
		_paint_hotbar_cell(i, slot)
		var sel := _inv_ref.hotbar_selection == i
		_hotbar_frames[i].add_theme_stylebox_override(&"panel", _hotbar_style_selected if sel else _hotbar_style_normal)


func _paint_hotbar_cell(idx: int, slot: Variant) -> void:
	if idx < 0 or idx >= _hotbar_icons.size():
		return
	var tr := _hotbar_icons[idx]
	var lb := _hotbar_qtys[idx]
	var qty_lb := _hotbar_qty_overlays[idx]
	if slot != null and slot.item != null:
		tr.texture = slot.item.icon
		tr.visible = slot.item.icon != null
		if slot.item.icon == null:
			lb.text = _slot_char(slot.item)
			lb.visible = true
		else:
			lb.text = ""
			lb.visible = false
		qty_lb.text = str(slot.quantity)
	else:
		tr.texture = null
		tr.visible = false
		lb.text = ""
		lb.visible = false
		qty_lb.text = ""


func _slot_char(item: InventoryItem) -> String:
	match item.id:
		&"summon_shangyang": return "商"
		&"summon_zhong": return "重"
		&"summon_hui": return "恢"
		_: return item.name[-1]


func _update_hotbar_cd_bars() -> void:
	if _hotbar_cd_bars.is_empty():
		return
	var p := get_tree().get_first_node_in_group(&"player")
	if p == null:
		for bar in _hotbar_cd_bars:
			bar.visible = false
		return
	var ratio := 0.0
	var active_slot := -1
	if p.has_method("get_consumable_cooldown_ratio"):
		ratio = clampf(float(p.call("get_consumable_cooldown_ratio")), 0.0, 1.0)
	if _inv_ref != null and ratio > 0.01:
		active_slot = _inv_ref.hotbar_selection
	for i in _hotbar_cd_bars.size():
		var bar := _hotbar_cd_bars[i]
		if i == active_slot:
			bar.visible = true
			var panel_h := _hotbar_frames[i].size.y
			if panel_h > 0:
				bar.offset_top = -int(panel_h * (1.0 - ratio))
			else:
				bar.offset_top = -int(30.0 * (1.0 - ratio))
		else:
			bar.visible = false


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


## 立即停止血量动画，将血量跳到目标值（用于死亡时）
func stop_health_animation() -> void:
	_is_animating = false
	if _stats_valid():
		var h := clampi(int(stats.health), 0, maxi(0, int(stats.max_health)))
		_sync_cells_instant(h, maxi(0, int(stats.max_health)))
		_display_health = h


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
	



	
