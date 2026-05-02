class_name ItemPickup
extends Interactable

## 通用物品拾取物：E 键交互后将指定物品加入玩家背包，然后销毁自身

@export var item_id: StringName = &""     ## 对应 resources/items/ 下的 .tres id
@export var give_quantity: int = 1        ## 给予数量
@export var display_text: String = ""     ## 可选：头顶显示的文字（留空则用物品 name）

var _collected: bool = false


func _ready() -> void:
	add_to_group("item_pickup")
	monitoring = true
	monitorable = true
	if display_text.is_empty():
		var item := InventoryDb.load_item_by_id(item_id)
		if item != null:
			display_text = item.name


func interact() -> void:
	if _collected:
		return
	var item := InventoryDb.load_item_by_id(item_id)
	if item == null:
		push_warning("ItemPickup: 找不到物品 %s" % item_id)
		return
	var p := _resolve_player()
	if p == null:
		return
	var inv := p.get_node_or_null("PlayerInventory") as PlayerInventory
	if inv == null:
		return
	_collected = true
	monitoring = false
	monitorable = false
	inv.add_item(item, give_quantity)
	print("[ItemPickup] 已拾取 %s x%d" % [item_id, give_quantity])
	super.interact()
	if p.has_method("unregister_interactable"):
		p.unregister_interactable(self)
	queue_free()


func _resolve_player() -> Player:
	## 优先用重叠体检测（与交互图标一致）；兜底从场景树查找
	for b in get_overlapping_bodies():
		if b is Player:
			return b as Player
	return get_tree().get_first_node_in_group("player") as Player


## 存档：如果已被收集则直接销毁
func apply_saved_collected() -> void:
	_collected = true
	queue_free()
