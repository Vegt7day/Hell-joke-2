extends CanvasLayer

const FONT_12: FontFile = preload("res://assets/资源总库/11_字体/VonwaonBitmap-12px.ttf")
const FONT_16: FontFile = preload("res://assets/资源总库/11_字体/VonwaonBitmap-16px.ttf")
const CONFIRM_POPUP_SCENE: PackedScene = preload("res://system/ui/confirm_popup.tscn")

## 每页 8 列 × 6 行 = 48 格；槽间距与快捷栏 separation（3）一致（见 SlotGrid）
const INV_GRID_COLS := 8
const INV_GRID_ROWS := 6
const SLOTS_PER_PAGE := INV_GRID_COLS * INV_GRID_ROWS
## 与 PlayerInventory._DEFAULT_SLOT_COUNT 一致：3 × 48 = 144
const INV_PAGES := 3
const INV_SLOT_COUNT := INV_PAGES * SLOTS_PER_PAGE

const SLOT_PANEL_SZ := Vector2(28, 28)
const SLOT_ICON_SZ := Vector2(22, 22)

@onready var _hotbar_row: HBoxContainer = $Root/Center/MainPanel/MainVBox/BodyHBox/LeftGrow/PageCenter/LeftColumn/HotbarRow
@onready var _grid: GridContainer = $Root/Center/MainPanel/MainVBox/BodyHBox/LeftGrow/PageCenter/LeftColumn/SlotGrid
@onready var _btn_page_prev: Button = $Root/Center/MainPanel/MainVBox/BodyHBox/LeftGrow/PageCenter/LeftColumn/PageNavRow/BtnPagePrev
@onready var _btn_page_next: Button = $Root/Center/MainPanel/MainVBox/BodyHBox/LeftGrow/PageCenter/LeftColumn/PageNavRow/BtnPageNext
@onready var _page_label: Label = $Root/Center/MainPanel/MainVBox/BodyHBox/LeftGrow/PageCenter/LeftColumn/PageNavRow/PageLabel
@onready var _item_icon_large: TextureRect = $Root/Center/MainPanel/MainVBox/BodyHBox/RightVBox/DetailPanel/DetailVBox/ItemIconLarge
@onready var _item_name: Label = $Root/Center/MainPanel/MainVBox/BodyHBox/RightVBox/DetailPanel/DetailVBox/ItemNameLabel
@onready var _item_desc: Label = $Root/Center/MainPanel/MainVBox/BodyHBox/RightVBox/DetailPanel/DetailVBox/ItemDescLabel
@onready var _btn_use: Button = $Root/Center/MainPanel/MainVBox/BtnRow/BtnUse
@onready var _btn_drop: Button = $Root/Center/MainPanel/MainVBox/BtnRow/BtnDrop
@onready var _btn_unequip: Button = $Root/Center/MainPanel/MainVBox/BtnRow/BtnUnequipSummon

var _inv: PlayerInventory
var _selected_slot: int = 0
var _page_index: int = 0
var _slot_panels: Array[PanelContainer] = []
var _hotbar_panels: Array[PanelContainer] = []
var _style_normal: StyleBoxFlat
var _style_selected: StyleBoxFlat


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	add_to_group(&"inventory_ui")
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.12, 0.12, 0.14, 0.92)
	_style_normal.set_border_width_all(1)
	_style_normal.border_color = Color(0.35, 0.35, 0.38, 1.0)
	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = Color(0.18, 0.22, 0.28, 0.95)
	_style_selected.set_border_width_all(2)
	_style_selected.border_color = Color(0.85, 0.78, 0.35, 1.0)

	var p := get_tree().get_first_node_in_group(&"player")
	if p != null:
		_inv = p.get_node_or_null("PlayerInventory") as PlayerInventory
	if _inv != null:
		_inv.inventory_changed.connect(_refresh_all)
		_inv.hotbar_selection_changed.connect(_refresh_hotbar_strip)

	_build_hotbar_cells()
	_build_grid_cells()
	_apply_fonts()
	_btn_use.pressed.connect(_on_use_pressed)
	_btn_drop.pressed.connect(_on_drop_pressed)
	_btn_unequip.pressed.connect(_on_unequip_pressed)
	_btn_page_prev.pressed.connect(_on_page_prev_pressed)
	_btn_page_next.pressed.connect(_on_page_next_pressed)

	var hi := _inv_slot_count_runtime() - 1
	if hi >= 0:
		_selected_slot = clampi(_selected_slot, 0, hi)
	_sync_page_to_selection()
	_refresh_all()


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null:
		tree.paused = false


func _apply_fonts() -> void:
	var title: Label = $Root/Center/MainPanel/MainVBox/TitleLabel
	title.add_theme_font_override(&"font", FONT_16)
	title.add_theme_font_size_override(&"font_size", 24)

	var hint: Label = $Root/Center/MainPanel/MainVBox/BodyHBox/LeftGrow/PageCenter/LeftColumn/HotbarHint
	hint.add_theme_font_override(&"font", FONT_12)
	hint.add_theme_font_size_override(&"font_size", 11)

	_page_label.add_theme_font_override(&"font", FONT_12)
	_page_label.add_theme_font_size_override(&"font_size", 11)
	_btn_page_prev.add_theme_font_override(&"font", FONT_16)
	_btn_page_prev.add_theme_font_size_override(&"font_size", 14)
	_btn_page_next.add_theme_font_override(&"font", FONT_16)
	_btn_page_next.add_theme_font_size_override(&"font_size", 14)

	_item_name.add_theme_font_override(&"font", FONT_16)
	_item_name.add_theme_font_size_override(&"font_size", 15)
	_item_desc.add_theme_font_override(&"font", FONT_12)
	_item_desc.add_theme_font_size_override(&"font_size", 11)

	for b in [_btn_use, _btn_drop, _btn_unequip]:
		b.add_theme_font_override(&"font", FONT_16)
		b.add_theme_font_size_override(&"font_size", 13)


func _build_hotbar_cells() -> void:
	var hotbar_n := 8
	if _inv != null:
		hotbar_n = mini(8, _inv.hotbar.size())
	for i in hotbar_n:
		var panel := _make_slot_panel()
		_hotbar_row.add_child(panel)
		_hotbar_panels.append(panel)


func _build_grid_cells() -> void:
	for local_i in SLOTS_PER_PAGE:
		var panel := _make_slot_panel()
		var li := local_i
		panel.gui_input.connect(func(ev: InputEvent): _on_grid_panel_gui(li, ev))
		_grid.add_child(panel)
		_slot_panels.append(panel)


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
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
		if pk >= KEY_1 and pk <= KEY_8:
			if _inv != null:
				_inv.set_hotbar_selection(int(pk - KEY_1))
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed(&"ui_accept") or (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_SPACE):
		_apply_use()
		get_viewport().set_input_as_handled()
		return

	if _handle_grid_navigation(event):
		get_viewport().set_input_as_handled()


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
			var max_i := _inv_slot_count_runtime() - 1
			if max_i >= 0:
				_selected_slot = clampi(gi, 0, max_i)
			_refresh_selection_and_detail()


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
		var sel := _inv.hotbar_selection == i
		_hotbar_panels[i].add_theme_stylebox_override(&"panel", _style_selected if sel else _style_normal)


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
		_paint_slot(tr, lb, slot)
		var sel := gi == _selected_slot
		_slot_panels[local_i].add_theme_stylebox_override(&"panel", _style_selected if sel else _style_normal)


func _paint_slot(tr: TextureRect, lb: Label, slot: InventorySlot) -> void:
	if slot != null and slot.item != null:
		tr.texture = slot.item.icon
		tr.visible = slot.item.icon != null
		if slot.item.stackable and slot.quantity > 1:
			lb.text = str(slot.quantity)
		else:
			lb.text = ""
	else:
		tr.texture = null
		tr.visible = false
		lb.text = ""


func _refresh_selection_and_detail() -> void:
	_update_page_nav()
	_refresh_grid_cells_only()
	if _inv == null:
		return
	var hi := _inv.slots.size() - 1
	if hi < 0:
		return
	_selected_slot = clampi(_selected_slot, 0, mini(hi, INV_SLOT_COUNT - 1))
	var slot: InventorySlot = _inv.slots[_selected_slot]
	if slot.item == null:
		_item_icon_large.texture = null
		_item_icon_large.visible = false
		_item_name.text = "空格子"
		_item_desc.text = ""
		_btn_use.disabled = true
		_btn_drop.disabled = true
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
		_btn_drop.disabled = slot.item.item_type == InventoryItem.ItemType.QUEST
		match slot.item.item_type:
			InventoryItem.ItemType.CONSUMABLE, InventoryItem.ItemType.SUMMON_BOOK:
				_btn_use.disabled = false
			_:
				_btn_use.disabled = true
	_btn_unequip.visible = _inv.active_summon_item != null
	_btn_unequip.disabled = _inv.active_summon_item == null
