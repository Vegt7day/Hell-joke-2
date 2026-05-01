class_name InventoryDb
extends RefCounted

## 与 Docs/UI设计方案 §18.4 一致：`res://resources/items/{id}.tres`
const ITEM_DIR := "res://resources/items/"


static func load_item_by_id(item_id: String) -> InventoryItem:
	if item_id.is_empty():
		return null
	var path := ITEM_DIR + item_id + ".tres"
	if not ResourceLoader.exists(path):
		return null
	var res := load(path)
	if res is InventoryItem:
		return res as InventoryItem
	return null
