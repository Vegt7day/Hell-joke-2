class_name PlayerInventory
extends Node

## 主背包格子（分页 UI 每页 8×6=48 格；默认共 3 页 → 144 格）
var slots: Array[InventorySlot] = []
## 快捷栏格子（固定 8 格）
var hotbar: Array[InventorySlot] = []
## 当前选中的快捷栏索引（0-7）
var hotbar_selection: int = 0
## 当前装备的召唤书（同时只能装备 1 本）
var active_summon_item: InventoryItem = null

const _DEFAULT_SLOT_COUNT := 144
const _HOTBAR_SLOT_COUNT := 8

signal inventory_changed
signal hotbar_selection_changed(index: int)
signal item_used(item: InventoryItem)


func _ready() -> void:
	_initialize_slots()


func _initialize_slots() -> void:
	slots.clear()
	hotbar.clear()
	for i in _DEFAULT_SLOT_COUNT:
		slots.append(InventorySlot.new())
	for i in _HOTBAR_SLOT_COUNT:
		hotbar.append(InventorySlot.new())


func has_item_with_id(item_id: StringName) -> bool:
	for slot in slots:
		if slot.item != null and slot.item.id == item_id:
			return true
	return false


## 添加物品，优先堆叠已有可堆叠物品，否则放入空格
## 返回实际成功添加的数量
func add_item(item: InventoryItem, quantity: int = 1) -> int:
	if item == null or quantity <= 0:
		return 0
	var remaining := quantity
	# 先尝试堆叠到已有同类物品（无上限）
	for slot in slots:
		if slot.item != null and slot.item.id == item.id:
			slot.quantity += remaining
			inventory_changed.emit()
			return quantity
	# 没有同类物品，放入空格
	for slot in slots:
		if slot.item == null:
			var new_slot := InventorySlot.new()
			new_slot.item = item
			new_slot.quantity = remaining
			_replace_slot(slots.find(slot), new_slot)
			inventory_changed.emit()
			return quantity
	inventory_changed.emit()
	return 0


## 从指定格子移除数量
func remove_item(slot_index: int, quantity: int = 1) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return
	var slot := slots[slot_index]
	if slot.item == null or slot.quantity < quantity:
		return
	slot.quantity -= quantity
	# 数量为 0 时不删除物品，只标记为不可用
	if slot.quantity <= 0:
		slot.quantity = 0
	inventory_changed.emit()

## 交换两个格子的物品（仅交换 item 与 quantity，不改变引用）
func swap_slots(index_a: int, index_b: int) -> void:
	if index_a < 0 or index_a >= slots.size() or index_b < 0 or index_b >= slots.size():
		return
	if index_a == index_b:
		return
	var a := slots[index_a]
	var b := slots[index_b]
	var tmp_item := a.item
	var tmp_qty := a.quantity
	a.item = b.item
	a.quantity = b.quantity
	b.item = tmp_item
	b.quantity = tmp_qty
	inventory_changed.emit()


## 交换快捷栏内部两个格子的物品（独立存储）
func swap_hotbar_slots(index_a: int, index_b: int) -> void:
	if index_a < 0 or index_a >= hotbar.size() or index_b < 0 or index_b >= hotbar.size():
		return
	if index_a == index_b:
		return
	var a := hotbar[index_a]
	var b := hotbar[index_b]
	var tmp_item := a.item
	var tmp_qty := a.quantity
	a.item = b.item
	a.quantity = b.quantity
	b.item = tmp_item
	b.quantity = tmp_qty
	inventory_changed.emit()


## 交换背包格子和快捷栏格子的物品（独立存储）
func swap_grid_hotbar(slot_index: int, bar_index: int) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return
	if bar_index < 0 or bar_index >= hotbar.size():
		return
	var s := slots[slot_index]
	var h := hotbar[bar_index]
	var tmp_item := s.item
	var tmp_qty := s.quantity
	s.item = h.item
	s.quantity = h.quantity
	h.item = tmp_item
	h.quantity = tmp_qty
	inventory_changed.emit()


## 装备召唤书到召唤槽
func equip_summon(item: InventoryItem) -> void:
	if item == null or item.item_type != InventoryItem.ItemType.SUMMON_BOOK:
		return
	if active_summon_item != null:
		unequip_summon()
	active_summon_item = item
	inventory_changed.emit()


## 卸下当前召唤书
func unequip_summon() -> void:
	if active_summon_item == null:
		return
	active_summon_item = null
	inventory_changed.emit()


## 丢弃物品（带确认逻辑由 UI 层处理，这里只负责移除）
func drop_item(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return
	var slot := slots[slot_index]
	if slot.item == null:
		return
	# QUEST 类型不可丢弃
	if slot.item.item_type == InventoryItem.ItemType.QUEST:
		return
	# 若该物品是当前装备的召唤书，先卸下
	if active_summon_item != null and active_summon_item.id == slot.item.id:
		active_summon_item = null
	slot.item = null
	slot.quantity = 0
	inventory_changed.emit()


## 使用物品（由 UI 层调用）
## CONSUMABLE: 扣除 1 数量
## SUMMON_BOOK: 装备到召唤槽
func use_item(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return
	var slot := slots[slot_index]
	if slot.item == null or slot.quantity <= 0:
		return
	match slot.item.item_type:
		InventoryItem.ItemType.CONSUMABLE:
			var used: InventoryItem = slot.item
			remove_item(slot_index, 1)
			item_used.emit(used)
		InventoryItem.ItemType.SUMMON_BOOK:
			equip_summon(slot.item)
		_:
			pass # EQUIPMENT / QUEST 暂不处理


## 将主背包某一格复制到快捷栏第 bar_index 格（独立存储，不共享引用）
func assign_slot_to_hotbar(slot_index: int, bar_index: int) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return
	if bar_index < 0 or bar_index >= _HOTBAR_SLOT_COUNT:
		return
	var src := slots[slot_index]
	var dst := hotbar[bar_index]
	dst.item = src.item
	dst.quantity = src.quantity
	inventory_changed.emit()


## 设置快捷栏选中索引
func set_hotbar_selection(index: int) -> void:
	var clamped := clampi(index, 0, _HOTBAR_SLOT_COUNT - 1)
	if hotbar_selection != clamped:
		hotbar_selection = clamped
		hotbar_selection_changed.emit(hotbar_selection)


## 使用当前快捷栏选中的物品（独立处理，不依赖 slots 引用）
func use_hotbar_selection() -> void:
	if hotbar_selection < 0 or hotbar_selection >= hotbar.size():
		return
	var slot := hotbar[hotbar_selection]
	if slot.item == null or slot.quantity <= 0:
		return
	match slot.item.item_type:
		InventoryItem.ItemType.CONSUMABLE:
			var used: InventoryItem = slot.item
			slot.quantity -= 1
			if slot.quantity <= 0:
				slot.quantity = 0
			item_used.emit(used)
			inventory_changed.emit()
		InventoryItem.ItemType.SUMMON_BOOK:
			equip_summon(slot.item)
		_:
			pass


func _replace_slot(index: int, new_slot: InventorySlot) -> void:
	if index < 0 or index >= slots.size():
		return
	slots[index] = new_slot


## ===== 存档序列化 =====

func to_dict() -> Dictionary:
	var slots_data: Array = []
	for slot in slots:
		if slot.item != null:
			slots_data.append({
				"item_id": slot.item.id,
				"quantity": slot.quantity,
			})
		else:
			slots_data.append(null)
	var hotbar_data: Array = []
	for slot in hotbar:
		if slot.item != null:
			hotbar_data.append({
				"item_id": slot.item.id,
				"quantity": slot.quantity,
			})
		else:
			hotbar_data.append(null)
	return {
		"slots": slots_data,
		"hotbar_slots": hotbar_data,
		"hotbar_selection": hotbar_selection,
		"active_summon_id": active_summon_item.id if active_summon_item != null else "",
	}


func from_dict(dict: Dictionary) -> void:
	var slots_data: Array = dict.get("slots", [])
	var hotbar_data: Array = dict.get("hotbar_slots", [])
	hotbar_selection = clampi(int(dict.get("hotbar_selection", 0)), 0, _HOTBAR_SLOT_COUNT - 1)

	# 清空现有数据
	slots.clear()
	hotbar.clear()

	# 重建 slots 和 hotbar（独立）
	for i in _DEFAULT_SLOT_COUNT:
		slots.append(InventorySlot.new())
	for i in _HOTBAR_SLOT_COUNT:
		hotbar.append(InventorySlot.new())

	# 按存档恢复 slots
	for i in mini(slots_data.size(), _DEFAULT_SLOT_COUNT):
		var entry = slots_data[i]
		if entry == null:
			continue
		var item_id: String = entry.get("item_id", "")
		if item_id.is_empty():
			continue
		var item := _load_item_by_id(item_id)
		if item == null:
			continue
		slots[i].item = item
		slots[i].quantity = clampi(int(entry.get("quantity", 1)), 0, item.max_stack if item.stackable else 1)

	# 恢复 hotbar
	for i in mini(hotbar_data.size(), _HOTBAR_SLOT_COUNT):
		var entry = hotbar_data[i]
		if entry == null:
			continue
		var item_id: String = entry.get("item_id", "")
		if item_id.is_empty():
			continue
		var item := _load_item_by_id(item_id)
		if item == null:
			continue
		hotbar[i].item = item
		hotbar[i].quantity = clampi(int(entry.get("quantity", 1)), 0, item.max_stack if item.stackable else 1)

	# 恢复装备的召唤书
	var summon_id: String = dict.get("active_summon_id", "")
	if not summon_id.is_empty():
		active_summon_item = _load_item_by_id(summon_id)
	else:
		active_summon_item = null

	inventory_changed.emit()


func _load_item_by_id(item_id: String) -> InventoryItem:
	return InventoryDb.load_item_by_id(item_id)
