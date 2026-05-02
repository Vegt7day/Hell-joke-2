class_name InventoryItem
extends Resource
## 物品类型枚举
## CONSUMABLE: 消耗品（血药、加速药、变大变小药等）
## SUMMON_BOOK: 召唤书（商鞅、后续角色等）
## EQUIPMENT: 装备
## QUEST: 任务道具（不可丢弃、不可使用）
enum ItemType {
	CONSUMABLE,
	SUMMON_BOOK,
	EQUIPMENT,
	QUEST,
}

@export var id: StringName                ## 唯一标识，如 "potion_health", "summon_shangyang"
@export var name: String                  ## 显示名称
@export var description: String = ""      ## 描述文本
@export var icon: Texture2D               ## 物品图标
@export var stackable: bool = false       ## 是否可堆叠
@export var max_stack: int = 1            ## 最大堆叠数（可堆叠时）
@export var item_type: ItemType           ## 物品类型
@export var use_animation: String = ""    ## 使用时的玩家动画名称（可选）
@export var effect_id: StringName = &""  ## 效果标识，如 "zhong"、"hui"
@export var effect_duration: float = 0.0 ## 效果持续时间（秒），0 表示瞬时
@export var effect_value: float = 0.0    ## 效果数值（如回复量）