extends CanvasLayer

const FONT_12: FontFile = preload("res://assets/资源总库/11_字体/VonwaonBitmap-12px.ttf")
const FONT_16: FontFile = preload("res://assets/资源总库/11_字体/VonwaonBitmap-16px.ttf")
const CONFIRM_POPUP_SCENE: PackedScene = preload("res://system/ui/confirm_popup.tscn")
const BUTTON_THEME: Theme = preload("res://system/ui/button_theme.tres")
const MENU_BG: Texture2D = preload("res://assets/资源总库/03_图像_UI/菜单背景.png")
const CONTEXT_MENU_SCENE: PackedScene = preload("res://system/ui/context_menu_popup.tscn")

const INV_GRID_COLS := 8
const INV_GRID_ROWS := 5
const SLOTS_PER_PAGE := INV_GRID_COLS * INV_GRID_ROWS
const INV_PAGES := 3
const INV_SLOT_COUNT := INV_PAGES * SLOTS_PER_PAGE

const SLOT_PANEL_SZ := Vector2(28, 28)
const SLOT_ICON_SZ := Vector2(22, 22)

@onready var _hotbar_row: HBoxContainer = $Root/back/Center/MainVBox/DragArea/PanelGrid2/HotbarRow
@onready var _grid: GridContainer = $Root/back/Center/MainVBox/DragArea/PanelGrid/GridVBox/SlotGrid
@onready var _btn_page_prev: Button = $Root/back/Center/MainVBox/DragArea/PanelGrid/GridVBox/PageNavRow/BtnPagePrev
@onready var _btn_page_next: Button = $Root/back/Center/MainVBox/DragArea/PanelGrid/GridVBox/PageNavRow/BtnPageNext
@onready var _page_label: Label = $Root/back/Center/MainVBox/DragArea/PanelGrid/GridVBox/PageNavRow/PageLabel
@onready var _item_icon_large: TextureRect = $Root/back/Center/MainVBox/DragArea/DescPanel/DetailVBox/ItemIconLarge
@onready var _item_name: Label = $Root/back/Center/MainVBox/DragArea/DescPanel/DetailVBox/ItemNameLabel
@onready var _item_desc: Label = $Root/back/Center/MainVBox/DragArea/DescPanel/DetailVBox/ItemDescLabel


var _inv: PlayerInventory
var _selected_slot: int = 0
var _page_index: int = 0
var _slot_panels: Array[PanelContainer] = []
var _hotbar_panels: Array[PanelContainer] = []
@onready var _style_normal: StyleBoxTexture = $Root/back/Center/MainVBox/DragArea/SlotStyleNormal.get("theme_override_styles/panel") as StyleBoxTexture
@onready var _style_selected: StyleBoxTexture = $Root/back/Center/MainVBox/DragArea/SlotStyleSelected.get("theme_override_styles/panel") as StyleBoxTexture
var _drag_source_slot: int = -1
var _drag_source_is_hotbar: bool = false
var _selected_is_hotbar: bool = false
var _drag_preview: PanelContainer = null
var _may_drag: bool = false
var _last_click_slot: int = -1
var _last_click_is_hotbar: bool = false
var _last_click_time: int = 0
var _context_menu: PanelContainer = null

# 面板拖拽
var _dragging_panel: PanelContainer = null
var _drag_mouse_offset: Vector2 = Vector2.ZERO

# 3 个可拖拽面板
@onready var _panel_grid: PanelContainer = $Root/back/Center/MainVBox/DragArea/PanelGrid
@onready var _panel_detail: PanelContainer = $Root/back/Center/MainVBox/DragArea/DescPanel



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 115
	add_to_group(&"inventory_ui")

	var p := get_tree().get_first_node_in_group(&"player")
	if p != null:
		_inv = p.get_node_or_null("PlayerInventory") as PlayerInventory
	if _inv != null:
		_inv.inventory_changed.connect(_refresh_all)
		_inv.hotbar_selection_changed.connect(_refresh_hotbar_strip)

	_build_hotbar_cells()
	_build_grid_cells()

	_btn_page_prev.pressed.connect(_on_page_prev_pressed)
	_btn_page_next.pressed.connect(_on_page_next_pressed)

	# 标题栏拖拽
	for panel in [_panel_grid, _panel_detail]:
		var title := panel.get_child(0).get_child(0) as Label
		if title != null:
			title.gui_input.connect(func(ev: InputEvent): _on_title_gui(panel, ev))

	var hi := _inv_slot_count_runtime() - 1
	if hi >= 0:
		_selected_slot = clampi(_selected_slot, 0, hi)
	_sync_page_to_selection()
	_refresh_all()


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null:
		tree.paused = false


func _on_title_gui(panel: PanelContainer, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging_panel = panel
			_drag_mouse_offset = panel.position - get_viewport().get_mouse_position()
		elif _dragging_panel == panel:
			_dragging_panel = null


func _make_slot_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = SLOT_PANEL_SZ
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)
	var tr := TextureRect.new()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.custom_minimum_size = SLOT_ICON_SZ
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(tr)
	var lb := Label.new()
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_override(&"font", FONT_12)
	lb.add_theme_font_size_override(&"font_size", 9)
	vb.add_child(lb)
	return panel


func _panel_parts(panel: PanelContainer) -> Array:
	var vb := panel.get_child(0) as VBoxContainer
	if vb == null:
		return [null, null]
	var tr := vb.get_child(0) as TextureRect
	var lb := vb.get_child(1) as Label
	return [tr, lb]


func _build_hotbar_cells() -> void:
	var hotbar_n := 8
	if _inv != null:
		hotbar_n = mini(8, _inv.hotbar.size())
	for i in hotbar_n:
		var panel := _make_slot_panel()
		var hi := i
		panel.gui_input.connect(func(ev: InputEvent): _on_item_slot_gui(hi, ev))
		_hotbar_row.add_child(panel)
		_hotbar_panels.append(panel)


func _build_grid_cells() -> void:
	for local_i in SLOTS_PER_PAGE:
		var panel := _make_slot_panel()
		var li := local_i
		panel.gui_input.connect(func(ev: InputEvent): _on_grid_panel_gui(li, ev))
		_grid.add_child(panel)
		_slot_panels.append(panel)


func _on_item_slot_gui(hotbar_idx: int, ev: InputEvent) -> void:
	if _inv == null:
		return
	if hotbar_idx < 0 or hotbar_idx >= _inv.hotbar.size():
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_selected_slot = hotbar_idx
			_selected_is_hotbar = true
			_sync_page_to_selection()
			_refresh_selection_and_detail()
			if _inv.hotbar[hotbar_idx].item != null:
				_drag_source_slot = hotbar_idx
				_drag_source_is_hotbar = true
				_may_drag = true
			var now := Time.get_ticks_msec()
			if hotbar_idx == _last_click_slot and _last_click_is_hotbar and now - _last_click_time < 300 and _inv.hotbar[hotbar_idx].item != null:
				_apply_use()
			_last_click_slot = hotbar_idx
			_last_click_is_hotbar = true
			_last_click_time = now
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _inv.hotbar[hotbar_idx].item != null:
				_selected_slot = hotbar_idx
				_selected_is_hotbar = true
				_sync_page_to_selection()
				_refresh_selection_and_detail()
				_show_context_menu(get_viewport().get_mouse_position())


func _close() -> void:
	queue_free()


func _inv_slot_count_runtime() -> int:
	if _inv == null:
		return INV_SLOT_COUNT
	return mini(INV_SLOT_COUNT, _inv.slots.size())


func _sync_page_to_selection() -> void:
	var hi := _inv_slot_count_runtime() - 1
	if hi < 0:
		return
	var clamped_sel := clampi(_selected_slot, 0, hi)
	_page_index = clampi(clamped_sel / SLOTS_PER_PAGE, 0, INV_PAGES - 1)
	_update_page_nav()


func _update_page_nav() -> void:
	_btn_page_prev.disabled = _page_index <= 0
	_btn_page_next.disabled = _page_index >= INV_PAGES - 1
	_page_label.text = "第 %d / %d 页" % [_page_index + 1, INV_PAGES]


func _on_page_prev_pressed() -> void:
	_page_index = maxi(0, _page_index - 1)
	_update_page_nav()
	_refresh_grid_cells_only()


func _on_page_next_pressed() -> void:
	_page_index = mini(INV_PAGES - 1, _page_index + 1)
	_update_page_nav()
	_refresh_grid_cells_only()


func _global_index_local(local_on_page: int) -> int:
	return _page_index * SLOTS_PER_PAGE + clampi(local_on_page, 0, SLOTS_PER_PAGE - 1)


func _input(event: InputEvent) -> void:
	# 面板拖拽
	if event is InputEventMouseMotion and _dragging_panel != null:
		_dragging_panel.position = get_viewport().get_mouse_position() + _drag_mouse_offset
		return
	if event is InputEventMouseButton and not event.pressed and _dragging_panel != null:
		_dragging_panel = null
		return

	if event is InputEventMouseButton and event.pressed and _context_menu != null:
		var menu_rect := _context_menu.get_global_rect()
		if not menu_rect.has_point(event.global_position):
			_close_context_menu()

	if event.is_action_pressed(&"ui_inventory"):
		get_viewport().set_input_as_handled()
		_close()
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
		return

	if event is InputEventKey:
		var ke := event as InputEventKey
		if not ke.pressed or ke.echo:
			return
		var pk := ke.physical_keycode

		if pk == KEY_Q:
			if _inv != null and _selected_slot >= 0 and _selected_slot < _inv.slots.size():
				_inv.assign_slot_to_hotbar(_selected_slot, _inv.hotbar_selection)
				_refresh_all()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed(&"ui_accept") or (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_SPACE):
		_apply_use()
		get_viewport().set_input_as_handled()
		return

	if _handle_grid_navigation(event):
		get_viewport().set_input_as_handled()

	# 物品拖拽启动与跟随
	if event is InputEventMouseMotion:
		if _may_drag and event.button_mask & MOUSE_BUTTON_MASK_LEFT and _drag_source_slot >= 0 and _inv != null:
			_may_drag = false
			var slot: InventorySlot = _inv.hotbar[_drag_source_slot] if _drag_source_is_hotbar else _inv.slots[_drag_source_slot]
			if slot.item != null:
				_create_drag_preview(slot)
				_refresh_all()
		if _drag_preview != null:
			_drag_preview.global_position = event.global_position - SLOT_PANEL_SZ * 0.4

	# 物品拖拽结束
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_finish_grid_drag()
		return




func _handle_grid_navigation(event: InputEvent) -> bool:
	var col_n := INV_GRID_COLS
	var max_i := _inv_slot_count_runtime() - 1
	var idx := clampi(_selected_slot, 0, maxi(0, max_i))
	var moved := false
	if event.is_action_pressed(&"ui_left") or (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_A):
		if idx % col_n > 0:
			idx -= 1
			moved = true
	elif event.is_action_pressed(&"ui_right") or (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_D):
		if idx % col_n < col_n - 1 and idx < max_i:
			idx += 1
			moved = true
	elif event.is_action_pressed(&"ui_up") or (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_W):
		if idx >= col_n:
			idx -= col_n
			moved = true
	elif event.is_action_pressed(&"ui_down") or (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_S):
		if idx <= max_i - col_n:
			idx += col_n
			moved = true
	if moved:
		_selected_slot = clampi(idx, 0, max_i)
		_sync_page_to_selection()
		_refresh_selection_and_detail()
		return true
	return false


func _on_grid_panel_gui(local_on_page: int, ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var gi := _global_index_local(local_on_page)
			_selected_slot = gi
			_selected_is_hotbar = false
			_refresh_selection_and_detail()
			if _inv != null and gi < _inv.slots.size() and _inv.slots[gi].item != null:
				_drag_source_slot = gi
				_drag_source_is_hotbar = false
				_may_drag = true
			var now := Time.get_ticks_msec()
			if _inv != null and gi < _inv.slots.size() and gi == _last_click_slot and not _last_click_is_hotbar and now - _last_click_time < 300 and _inv.slots[gi].item != null:
				_apply_use()
			_last_click_slot = gi
			_last_click_is_hotbar = false
			_last_click_time = now
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var gi := _global_index_local(local_on_page)
			if _inv != null and gi < _inv.slots.size() and _inv.slots[gi].item != null:
				_selected_slot = gi
				_selected_is_hotbar = false
				_refresh_selection_and_detail()
				_show_context_menu(get_viewport().get_mouse_position())


func _finish_grid_drag() -> void:
	_may_drag = false
	if _drag_source_slot < 0 or _inv == null:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var target_gi := -1
	var target_is_hotbar := false
	for local_i in _slot_panels.size():
		var gi := _page_index * SLOTS_PER_PAGE + local_i
		if gi >= _inv.slots.size():
			continue
		var rect := _slot_panels[local_i].get_global_rect()
		if rect.has_point(mouse_pos):
			target_gi = gi
			target_is_hotbar = false
			break
	if target_gi < 0:
		for hi in _hotbar_panels.size():
			var rect := _hotbar_panels[hi].get_global_rect()
			if rect.has_point(mouse_pos):
				target_gi = hi
				target_is_hotbar = true
				break
	if target_gi >= 0:
		if _drag_source_is_hotbar and target_is_hotbar:
			if target_gi != _drag_source_slot:
				_inv.swap_hotbar_slots(_drag_source_slot, target_gi)
		elif not _drag_source_is_hotbar and not target_is_hotbar:
			if target_gi != _drag_source_slot:
				_inv.swap_slots(_drag_source_slot, target_gi)
		else:
			if _drag_source_is_hotbar:
				_inv.swap_grid_hotbar(target_gi, _drag_source_slot)
			else:
				_inv.swap_grid_hotbar(_drag_source_slot, target_gi)
	_clear_drag_preview()
	_drag_source_slot = -1
	_drag_source_is_hotbar = false
	if target_gi >= 0:
		_selected_slot = target_gi
		_selected_is_hotbar = target_is_hotbar
	_refresh_all()


func _on_use_pressed() -> void:
	_apply_use()


func _apply_use() -> void:
	if _inv == null:
		return
	_inv.use_item(_selected_slot)
	_refresh_all()


func _on_drop_pressed() -> void:
	if _inv == null:
		return
	var slot := _inv.slots[_selected_slot]
	if slot.item == null:
		return
	if slot.item.item_type == InventoryItem.ItemType.QUEST:
		return
	var item_name := slot.item.name
	var popup := CONFIRM_POPUP_SCENE.instantiate() as ConfirmPopup
	if popup == null:
		return
	get_tree().root.add_child(popup)
	popup.show_confirm(
		"丢弃物品",
		"确定丢弃「%s」？" % item_name,
		func(): _inv.drop_item(_selected_slot)
	)


func _on_unequip_pressed() -> void:
	if _inv == null:
		return
	_inv.unequip_summon()
	_refresh_all()


func _refresh_hotbar_strip(_i: int = 0) -> void:
	_refresh_hotbar_cells_only()


func _refresh_all() -> void:
	var hi := _inv_slot_count_runtime() - 1
	if hi >= 0:
		_selected_slot = clampi(_selected_slot, 0, hi)
	_sync_page_to_selection()
	_refresh_hotbar_cells_only()
	_refresh_grid_cells_only()
	_refresh_selection_and_detail()


func _refresh_hotbar_cells_only() -> void:
	if _inv == null:
		return
	for i in _hotbar_panels.size():
		var slot: InventorySlot = _inv.hotbar[i]
		var parts := _panel_parts(_hotbar_panels[i])
		var tr: TextureRect = parts[0]
		var lb: Label = parts[1]
		_paint_slot(tr, lb, slot)
		var sel := _selected_is_hotbar and i == _selected_slot
		_hotbar_panels[i].add_theme_stylebox_override(&"panel", _style_selected if sel else _style_normal)
		if _drag_source_is_hotbar and i == _drag_source_slot:
			_paint_slot(tr, lb, slot, true)


func _refresh_grid_cells_only() -> void:
	if _inv == null:
		return
	var max_i := _inv_slot_count_runtime() - 1
	for local_i in _slot_panels.size():
		var gi := _page_index * SLOTS_PER_PAGE + local_i
		var parts := _panel_parts(_slot_panels[local_i])
		var tr: TextureRect = parts[0]
		var lb: Label = parts[1]
		if gi > max_i or gi >= _inv.slots.size():
			_paint_slot(tr, lb, null)
			_slot_panels[local_i].add_theme_stylebox_override(&"panel", _style_normal)
			continue
		var slot: InventorySlot = _inv.slots[gi]
		_paint_slot(tr, lb, slot, gi == _drag_source_slot)
		var sel := not _selected_is_hotbar and gi == _selected_slot
		_slot_panels[local_i].add_theme_stylebox_override(&"panel", _style_selected if sel else _style_normal)


func _paint_slot(tr: TextureRect, lb: Label, slot: InventorySlot, is_drag_source: bool = false) -> void:
	if slot != null and slot.item != null and not is_drag_source:
		tr.texture = slot.item.icon
		tr.visible = slot.item.icon != null
		if slot.item.icon == null:
			lb.text = _slot_char(slot.item)
			lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lb.add_theme_font_override(&"font", FONT_16)
			lb.add_theme_font_size_override(&"font_size", 19)
		elif slot.item.stackable and slot.quantity > 1:
			lb.text = str(slot.quantity)
			lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lb.add_theme_font_override(&"font", FONT_12)
			lb.add_theme_font_size_override(&"font_size", 9)
		else:
			lb.text = ""
	else:
		tr.texture = null
		tr.visible = false
		lb.text = ""


func _slot_char(item: InventoryItem) -> String:
	match item.id:
		&"summon_shangyang": return "商"
		&"summon_zhong": return "重"
		&"summon_hui": return "恢"
		_: return item.name[-1]


func _create_drag_preview(slot: InventorySlot) -> void:
	if _drag_preview != null:
		_clear_drag_preview()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = SLOT_PANEL_SZ
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", _style_selected)
	panel.scale = Vector2(0.8, 0.8)
	var lb := Label.new()
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.custom_minimum_size = SLOT_PANEL_SZ
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if slot.item.icon != null:
		lb.text = ""
	else:
		lb.text = _slot_char(slot.item)
		lb.add_theme_font_override(&"font", FONT_16)
		lb.add_theme_font_size_override(&"font_size", 19)
	panel.add_child(lb)
	panel.global_position = get_viewport().get_mouse_position() - SLOT_PANEL_SZ * 0.4
	add_child(panel)
	_drag_preview = panel


func _clear_drag_preview() -> void:
	_may_drag = false
	if _drag_preview != null and is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
	_drag_preview = null


func _show_context_menu(screen_pos: Vector2) -> void:
	_close_context_menu()
	if _inv == null:
		return
	var slot: InventorySlot
	if _selected_is_hotbar:
		slot = _inv.hotbar[_selected_slot]
	else:
		slot = _inv.slots[_selected_slot]
	if slot == null or slot.item == null:
		return
	
	var panel := CONTEXT_MENU_SCENE.instantiate() as PanelContainer
	var vb := panel.get_child(0) as VBoxContainer
	var btn_use := vb.get_child(0) as Button
	var btn_drop := vb.get_child(1) as Button
	var btn_unequip := vb.get_child(2) as Button
	
	match slot.item.item_type:
		InventoryItem.ItemType.CONSUMABLE, InventoryItem.ItemType.SUMMON_BOOK:
			btn_use.disabled = false
		_:
			btn_use.disabled = true
	btn_use.pressed.connect(func():
		_close_context_menu()
		_apply_use()
	)
	
	btn_drop.disabled = slot.item.item_type == InventoryItem.ItemType.QUEST
	btn_drop.pressed.connect(func():
		_close_context_menu()
		_on_drop_pressed()
	)
	
	btn_unequip.visible = _inv.active_summon_item != null
	btn_unequip.pressed.connect(func():
		_close_context_menu()
		_on_unequip_pressed()
	)
	
	panel.global_position = screen_pos
	panel.mouse_exited.connect(_on_context_menu_mouse_exited)
	add_child(panel)
	_context_menu = panel


func _on_context_menu_mouse_exited() -> void:
	if _context_menu == null:
		return
	# 等一帧让子控件的 mouse_entered 先触发
	await get_tree().process_frame
	if _context_menu != null and is_instance_valid(_context_menu):
		var rect := _context_menu.get_global_rect()
		if not rect.has_point(get_viewport().get_mouse_position()):
			_close_context_menu()


func _close_context_menu() -> void:
	if _context_menu != null and is_instance_valid(_context_menu):
		_context_menu.queue_free()
	_context_menu = null


func _refresh_selection_and_detail() -> void:
	_refresh_hotbar_cells_only()
	_update_page_nav()
	_refresh_grid_cells_only()
	if _inv == null:
		return
	if _selected_is_hotbar:
		var hi := _inv.hotbar.size() - 1
		if hi < 0:
			return
		_selected_slot = clampi(_selected_slot, 0, hi)
		var slot: InventorySlot = _inv.hotbar[_selected_slot]
		_hotbar_detail(slot)
		return
	var grid_hi := _inv.slots.size() - 1
	if grid_hi < 0:
		return
	_selected_slot = clampi(_selected_slot, 0, mini(grid_hi, INV_SLOT_COUNT - 1))
	var grid_slot: InventorySlot = _inv.slots[_selected_slot]
	_hotbar_detail(grid_slot)


func _hotbar_detail(slot: InventorySlot) -> void:
	if slot.item == null:
		_item_icon_large.texture = null
		_item_icon_large.visible = false
		_item_name.text = "空格子"
		_item_desc.text = ""
	else:
		var icon_tex: Texture2D = slot.item.icon
		_item_icon_large.texture = icon_tex
		_item_icon_large.visible = icon_tex != null
		_item_name.text = slot.item.name
		var desc_parts: Array[String] = []
		if not slot.item.description.is_empty():
			desc_parts.append(slot.item.description)
		desc_parts.append("数量：%d" % slot.quantity)
		var desc_joined := ""
		for i in desc_parts.size():
			if i > 0:
				desc_joined += "\n\n"
			desc_joined += desc_parts[i]
		_item_desc.text = desc_joined
