extends Node

# 自动加载节点，用于全局角色注册
var character_map: Dictionary = {}

# 角色资源映射
var character_resource_map: Dictionary = {
	"中学生": "res://assets/Dialogic/中学生.dch",
	"老教师": "res://assets/Dialogic/老教师.dch"
}

func _ready():
	print("DialogicRegistry 自动加载节点已就绪")

# 注册角色
func register_character(character_id: String, node: Node, character_resource_path: String = "") -> bool:
	if not node or not is_instance_valid(node):
		print("错误：尝试注册无效的节点")
		return false
	
	# 保存节点路径
	character_map[character_id] = node.get_path()
	
	# 如果有自定义角色资源路径，更新映射
	if character_resource_path and not character_resource_path.is_empty():
		character_resource_map[character_id] = character_resource_path
	
	print("DialogicRegistry: 注册角色 ", character_id, " -> ", node.get_path())
	return true

# 获取角色节点
func get_character_node(character_id: String) -> Node:
	if not character_map.has(character_id):
		print("DialogicRegistry: 角色未注册: ", character_id)
		return null
	
	var node_path: NodePath = character_map[character_id]
	var node = get_node_or_null(node_path)
	
	if not node or not is_instance_valid(node):
		print("DialogicRegistry: 角色节点无效，清理注册: ", character_id)
		character_map.erase(character_id)
		return null
	
	return node

# 获取角色资源路径
func get_character_resource(character_id: String) -> String:
	return character_resource_map.get(character_id, "")

# 清理所有注册
func clear_all() -> void:
	character_map.clear()
	print("DialogicRegistry: 已清理所有角色注册")

# 保存注册信息
func save_registry() -> Dictionary:
	var saved_data = {}
	for character_id in character_map:
		saved_data[character_id] = str(character_map[character_id])
	
	return saved_data

# 加载注册信息
func load_registry(data: Dictionary) -> void:
	character_map.clear()
	for character_id in data:
		var node_path = NodePath(data[character_id])
		character_map[character_id] = node_path
		print("DialogicRegistry: 加载角色注册 ", character_id, " -> ", node_path)
