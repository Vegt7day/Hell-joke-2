extends Node2D
## 商鞅肢体对象：支持头/手/脚三类贴图或同图集帧切换。

enum LimbType {
	HEAD,
	HAND,
	FOOT,
}

@export var limb_type: LimbType = LimbType.HAND
@export var source_texture: Texture2D
@export var head_texture: Texture2D
@export var hand_texture: Texture2D
@export var foot_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
var _follow_target: Node2D
var _follow_offset: Vector2 = Vector2.ZERO
var _follow_enabled: bool = false


func _ready() -> void:
	apply_limb_visual(limb_type)


func apply_limb_visual(kind: LimbType) -> void:
	limb_type = kind
	if sprite == null:
		return
	var tex := _pick_texture_by_type(kind)
	if tex:
		sprite.texture = tex
		sprite.region_enabled = false
		return
	# 兼容旧资源：若只给了整图，则按帧索引粗分三类显示。
	if source_texture:
		sprite.texture = source_texture
		sprite.region_enabled = false
		sprite.hframes = 3
		match kind:
			LimbType.HEAD:
				sprite.frame = 0
			LimbType.HAND:
				sprite.frame = 1
			LimbType.FOOT:
				sprite.frame = 2


func _pick_texture_by_type(kind: LimbType) -> Texture2D:
	match kind:
		LimbType.HEAD:
			return head_texture
		LimbType.HAND:
			return hand_texture
		LimbType.FOOT:
			return foot_texture
		_:
			return null


func set_follow_target(target: Node2D) -> void:
	_follow_target = target
	if _follow_target != null and is_instance_valid(_follow_target):
		_follow_offset = global_position - _follow_target.global_position
		_follow_enabled = true
	else:
		_follow_enabled = false


func freeze_follow() -> void:
	_follow_enabled = false
	_follow_target = null


func _process(_delta: float) -> void:
	if not _follow_enabled:
		return
	if _follow_target == null or not is_instance_valid(_follow_target):
		_follow_enabled = false
		return
	global_position = _follow_target.global_position + _follow_offset
