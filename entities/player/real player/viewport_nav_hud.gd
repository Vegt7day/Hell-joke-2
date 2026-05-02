extends Control

@onready var _btn_menu: TextureButton = $MenuBtnGroup/BtnGroup_Menu/BtnMenu
@onready var _btn_pack: TextureButton = $MenuBtnGroup/BtnGroup_Pack/BtnPack
@onready var _btn_map: TextureButton = $MenuBtnGroup/BtnGroup_Map/BtnMap


func _ready() -> void:
	_btn_menu.pressed.connect(_on_menu_pressed)
	_btn_pack.pressed.connect(_on_pack_pressed)
	_btn_map.pressed.connect(_on_map_pressed)


func _on_menu_pressed() -> void:
	if is_instance_valid(Game):
		Game.open_pause_menu()


func _on_pack_pressed() -> void:
	if is_instance_valid(Game):
		Game.open_inventory_ui()


func _on_map_pressed() -> void:
	if is_instance_valid(Game):
		Game.open_abstract_map_ui()
