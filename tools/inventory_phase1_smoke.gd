extends SceneTree

func _init() -> void:
	var book := InventoryDb.load_item_by_id("summon_shangyang")
	if book == null or book.id != &"summon_shangyang":
		push_error("smoke: summon_shangyang load failed")
		quit(1)
		return
	var pot := InventoryDb.load_item_by_id("potion_health")
	if pot == null:
		push_error("smoke: potion_health load failed")
		quit(1)
		return
	var inv := PlayerInventory.new()
	inv._initialize_slots()
	if inv.has_item_with_id(&"summon_shangyang"):
		push_error("smoke: empty inv should not have book")
		quit(1)
		return
	inv.add_item(book, 1)
	if not inv.has_item_with_id(&"summon_shangyang"):
		push_error("smoke: book not in inv after add")
		quit(1)
		return
	var packed: Dictionary = inv.to_dict()
	var inv2 := PlayerInventory.new()
	inv2._initialize_slots()
	inv2.from_dict(packed)
	if not inv2.has_item_with_id(&"summon_shangyang"):
		push_error("smoke: from_dict roundtrip lost summon_shangyang")
		quit(1)
		return
	var found_in_slots := false
	for entry in packed.get("slots", []):
		if entry is Dictionary and str(entry.get("item_id", "")) == "summon_shangyang":
			found_in_slots = true
			break
	if not found_in_slots:
		push_error("smoke: to_dict slots missing summon_shangyang")
		quit(1)
		return
	print("inventory_phase1_smoke: ok")
	quit(0)
