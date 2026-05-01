# UI 设计方案

> 项目：文字地狱重制版  
> 分辨率：640×360（`canvas_items` 拉伸模式）  
> 风格：像素风，与游戏视觉基调统一  
> 引擎：Godot 4.6  

---

## 一、设计原则

1. **一致的艺术风格** — 所有 UI 元素使用像素风贴图或与现有 UI 资源（`03_图像_UI/`）风格统一的素材。
2. **操作闭环** — 每个 UI 界面必须有明确的打开/关闭方式，且不阻塞不相关的游戏功能。
3. **低侵入度** — HUD 类 UI 常驻，菜单/背包类 UI 暂停游戏（`tree.paused = true`），但动画/音效由 `PROCESS_MODE_ALWAYS` 保障。
4. **可扩展性** — 物品栏/背包的数据结构支持未来任意类型道具的增删，UI 层面通过配置化生成格子。
5. **手柄/键盘友好** — 所有可交互 UI 支持方向键/WSAD 导航 + 交互键（E/Space）确认，不支持鼠标也可完成所有操作。

---

## 二、UI 体系总览

| 编号 | 名称 | 层级 | 暂停游戏 | 完成状态 |
|------|------|------|----------|----------|
| 1 | **HUD（状态面板）** | CanvasLayer | 否 | ✅ 已有（需求扩展） |
| 2 | **快捷物品栏（Hotbar）** | CanvasLayer | 否 | ❌ 新增 |
| 3 | **背包/物品栏** | CanvasLayer | 是 | ❌ 新增 |
| 4 | **存档点交互面板** | CanvasLayer | 是 | ❌ 新增 |
| 5 | **地图系统** | CanvasLayer | 是 | ❌ 新增 |
| 6 | **传送功能** | 按场景切换 | 是 | ❌ 新增 |
| 7 | **暂停菜单** | CanvasLayer | 是 | ❌ 新增 |
| 8 | **设置页面** | CanvasLayer | 是 | ❌ 新增 |
| 9 | **Game Over 画面** | CanvasLayer | 是 | ❌ 新增 |
| 10 | **关卡结算画面** | CanvasLayer | 是 | ❌ 新增 |
| 11 | **确认弹窗** | CanvasLayer | 否（叠加态） | ❌ 新增 |
| 12 | **存档槽位选择** | CanvasLayer | 是 | ❌ 新增 |
| 13 | **NPC 交互提示** | World Space / 世界空间 | 否 | ❌ 新增 |
| 14 | **Boss 血条** | CanvasLayer | 否 | ✅ 已有 |
| 15 | **标题画面** | Control（Scene） | - | ✅ 已有（需扩展） |

---

## 三、HUD（状态面板）— 改造现有

**位置：** `system/ui/status_panel.tscn`  
**已有功能：** 心形血量（左）、墨水格（左）、召唤冷却条（左）  
**改造目标：** 在屏幕底部新增快捷物品栏，与现有 HUD 共存。

### 3.1 布局

```
┌──────────────────────────────────────────────────┐
│ ┌──────┐ ┌──────┐ ┌──────┐                    │
│ │ ♥♥♥  │ │ 墨墨  │ │ 召喚  │                    │  ← 左上角：现有 HUD
│ └──────┘ └──────┘ └──────┘                    │
│                                                  │
│                                                  │  ← 中间：游戏世界
│                                                  │
│              ┌──┬──┬──┬──┬──┬──┬──┬──┐        │
│              │药│速│书│？│  │  │  │  │        │  ← 底部：快捷物品栏（Hotbar）
│              └──┴──┴──┴──┴──┴──┴──┴──┘        │
│              1   2  3  4  5  6  7  8           │  ← 数字快捷键提示
└──────────────────────────────────────────────────┘
```

### 3.2 快捷物品栏（Hotbar）设计

- **位置：** 屏幕底部居中，8 格
- **交互方式：** 键盘数字键 `1`~`8` 选择/使用，或鼠标点击
- **视觉：** 选中格有高亮边框，物品显示小图标 + 数量角标（可堆叠时）
- **数据结构：** `Player` 节点上持有一个 `hotbar: Array[InventorySlot]`，最大 8 格

### 3.3 输入控制

- 按 `1`~`8`：选中对应快捷栏格子（高亮）
- 按 `E`（交互键）/ `Space`：使用当前选中格的物品
- 选中一个物品格 + 按 `I` / `B`：打开背包（定位到该物品）
- 按 `Tab` / 滚轮：循环切换快捷栏选中格

---

## 四、背包/物品栏系统（核心新增）

### 4.1 数据层设计

#### InventoryItem（资源，`.tres`）

```gdscript
# item_base.gd
class_name InventoryItem
extends Resource

@export var id: StringName               # 唯一标识，如 "potion_health", "summon_shangyang"
@export var name: String                  # 显示名称
@export var description: String           # 描述文本
@export var icon: Texture2D               # 物品图标
@export var stackable: bool = false       # 是否可堆叠
@export var max_stack: int = 1            # 最大堆叠数（可堆叠时）
@export var item_type: ItemType           # 枚举：CONSUMABLE, SUMMON_BOOK, EQUIPMENT, QUEST
@export var use_animation: String = ""    # 使用时的玩家动画名称（可选）
```

#### InventorySlot（单格数据）

```gdscript
# inventory_slot.gd
class_name InventorySlot
extends RefCounted

var item: InventoryItem = null
var quantity: int = 0
```

#### PlayerInventory（玩家节点上）

```gdscript
# 挂载在 Player 节点上
extends Node
class_name PlayerInventory

var slots: Array[InventorySlot] = []      # 主背包格子（初始 24 格，可扩展）
var hotbar: Array[InventorySlot]          # 快捷栏格子（固定 8 格）
var max_slots: int = 24

signal inventory_changed                  # 背包内容变动
signal hotbar_selection_changed(index: int)
signal item_used(item: InventoryItem)
```

### 4.2 物品类型枚举

```gdscript
enum ItemType {
	CONSUMABLE,      # 消耗品：血药、加速药、变大变小药等
	SUMMON_BOOK,     # 召唤书：商鞅、后续角色等
	EQUIPMENT,       # 装备：不影响背包核心逻辑
	QUEST,           # 任务道具：不可丢弃、不可使用
}
```

### 4.3 初始物品清单（规划）

| ID | 名称 | 类型 | 堆叠 | 效果 |
|----|------|------|------|------|
| `potion_health` | 血药 | CONSUMABLE | 是（max=9） | 恢复 1 颗心 |
| `potion_speed` | 加速药 | CONSUMABLE | 是（max=5） | 短时间内提升移速 |
| `summon_shangyang` | 商鞅召唤书 | SUMMON_BOOK | 否 | 装备后可召唤商鞅（F键） |
| `summon_xx` | （预留）其他角色召唤书 | SUMMON_BOOK | 否 | 装备后替换召唤技能 |
| `potion_grow` | 变大药（未来） | CONSUMABLE | 是（max=3） | 角色体型变大 |
| `potion_shrink` | 变小药（未来） | CONSUMABLE | 是（max=3） | 角色体型变小 |
| `key_xx` | 钥匙（未来） | QUEST | 否 | 开某个门 |

### 4.4 背包 UI 布局

```
┌──────────────────────────────────────────────────┐
│  物品栏                      [关闭]              │  ← 标题栏
├──────────────────────────────────────────────────┤
│ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐      │
│ │药│ │速│ │书│ │  │ │  │ │  │ │  │ │  │      │  ← 快捷栏（与HUD底部联动）
│ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘      │
│  1    2    3    4    5    6    7    8           │
├──────────────────────────────────────────────────┤
│                                                  │
│ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐                │
│ │  │ │  │ │  │ │  │ │  │ │  │                │  ← 主背包网格（4列 × 6行 = 24格）
│ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘                │
│ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐                │
│ │  │ │  │ │  │ │  │ │  │ │  │                │
│ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘                │
│ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐                │
│ │  │ │  │ │  │ │  │ │  │ │  │                │
│ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘                │
│ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐                │
│ │  │ │  │ │  │ │  │ │  │ │  │                │
│ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘                │
│                                                  │
├──────────────────────────────────────────────────┤
│  选中: 血药 × 3                                 │  ← 物品详情区
│  恢复 1 颗心                                     │
│  [使用] [丢弃] [移到快捷栏第__格]              │
│  金币: 0（预留）                                 │
└──────────────────────────────────────────────────┘
```

### 4.5 背包交互

- **打开/关闭：** `I` 或 `B` 键（暂停游戏），再次按同一键或 `ESC` 关闭
- **导航：** 方向键/WASD 在网格中移动选中框
- **使用：** 选中物品后按 `E` / `Space` / 点击 [使用] 按钮
  - 消耗品：执行效果并扣除数量
  - 召唤书：装备到召唤槽（替换当前召唤技能），无需读档即可切换
- **丢弃：** 选中后按 `Q` 或点击 [丢弃]（有确认弹窗）
- **移入快捷栏：** 选中物品按数字 `1`~`8` 或拖拽到快捷栏区域
- **分类/排序（未来）：** 按类型/名称/获取时间排序

### 4.6 召唤书装备逻辑

```
┌─────────────────────────────┐
│  召唤书装备槽               │
│  ┌───────────────────────┐  │
│  │  商鞅召唤书（当前）    │  │  ← 背包界面右上或物品详情旁
│  └───────────────────────┘  │
│  [卸下]                      │
└─────────────────────────────┘
```

- 玩家同时只能装备 **1 本召唤书**
- 装备后，HUD 上的召唤冷却条图标更新为对应角色图标
- 按 `F` 键召唤当前装备的召唤书对应的角色
- 在背包中选择召唤书 → [使用] → 自动装备到召唤槽，原召唤书被替换（不消耗、不减数量）
- 召唤书本身不堆叠，每个角色占 1 格

### 4.7 与存档系统的集成

`PlayerInventory` 需要接入 `Game.gd` 的存档体系：

```gdscript
# 在 PlayerInventory 中
func to_dict() -> Dictionary:
	var data = []
	for slot in slots:
		if slot.item != null:
			data.append({
				"item_id": slot.item.id,
				"quantity": slot.quantity
			})
		else:
			data.append(null)
	return {
		"slots": data,
		"hotbar_indices": hotbar.map(func(s): return slots.find(s)),
		"equipped_summon_id": equipped_summon_id,
	}

func from_dict(dict: Dictionary) -> void:
	# 根据 item_id 从资源库重建 InventorySlot
	...
```

同时在 `Game.gd` 的 `save_game` / `load_game` 中包含玩家背包数据。

---

## 五、暂停菜单（新增）

### 5.1 触发方式

- 游戏中按 `ESC`：触发暂停菜单（**取代当前直接存档的行为**）
- 暂停时弹出菜单，游戏暂停（`tree.paused = true`），背景暗化

### 5.2 菜单内容

```
┌──────────────────────────────────┐
│          ⏸ 暂停                  │
│                                  │
│     [继续游戏]                    │
│     [背包 / 物品栏  I]           │  ← 也可在暂停菜单中打开背包
│     [设置]                       │
│     [保存游戏]                   │
│     [读取存档]                   │
│     [返回标题画面]               │
│     [离开游戏]                   │
└──────────────────────────────────┘
```

- 按 `ESC` 再次关闭暂停菜单，恢复游戏
- 选择"返回标题画面"时弹出确认弹窗
- 选择"离开游戏"时弹出确认弹窗
- "保存游戏"调用 `Game.save_game()`（短暂暂停后恢复）

### 5.3 现有冲突解决

当前 `Game._unhandled_input` 中 `ESC` 直接调用 `save_game()`。改造后：

```
ESC 按下 → 弹出暂停菜单（暂停状态）
         → 菜单中 [保存游戏] 按钮手动触发存档
         → [继续游戏] 关闭菜单并解除暂停
```

---

## 六、设置页面（新增）

### 6.1 设置内容

```
┌──────────────────────────────────┐
│          ⚙ 设置                  │
│                                  │
│  音量                            │
│  ┌────────────●──────┐  主音量   │
│  ┌────────────────────┐  BGM     │
│  ┌────────●───────────┐  SFX     │
│  ┌───────────●────────┐  UI      │
│                                  │
│  显示                            │
│  [全屏 / 窗口化]                 │
│  [分辨率：640×360 / 1280×720]   │  ← 引擎缩放
│                                  │
│  键位 / 自定义（未来）           │
│  [重置为默认]                    │
│                                  │
│  [返回]                          │
└──────────────────────────────────┘
```

### 6.2 音量实现

- 通过 `AudioServer.set_bus_volume_db()` 控制各总线
- 现有总线：`Master`, `BGM`, `SFX`, `UI`, `Voice`
- 使用 `HSlider` 控件

---

## 七、Game Over 画面（新增）

### 7.1 触发条件

- 玩家血量归零，且**不在 World3 Boss 场景**（World3 已有独立死亡重试 UI）
- 统一死亡流程：角色死亡 → 等待 0.5s → 红屏遮罩淡入 → Game Over UI

### 7.2 UI 内容

```
┌──────────────────────────────────┐
│                                  │
│          💀 游戏结束              │
│                                  │
│      [读取上一个存档点]          │
│      [返回标题画面]              │
│                                  │
└──────────────────────────────────┘
```

- "读取上一个存档点"：调用 `Game.load_game()`

---


---


## 八、存档点交互改造（新增）

### 8.1 现状

当前 `SavePointInteractable`（`system/levels/world3/props/save_point_interactable.gd`）的行为：

1. 玩家靠近按 `E` 交互
2. 立即触发回血 + 存档（`Game.save_game("savepoint")`）
3. 播放 ready → save → recover 三阶段动画

### 8.2 改造目标：存档点交互面板

在现有回血存档动画的基础上，弹出**交互选择面板**让玩家选择操作：

```
┌──────────────────────────────┐
│         📍 存档点              │
│                              │
│     [💾 保存游戏]             │
│     [🗺️ 打开地图 / 传送]      │
│     [✖️ 取消]                 │
│                              │
│     按方向键选择，E 确认       │
└──────────────────────────────┘
```

### 8.3 交互流程

```
玩家进入存档点区域 → 出现 [E] 提示（复用 NPC 交互提示风格）
      ↓ 按 E
弹出交互选择面板（暂停游戏）
      ↓
  ┌───┴───┐
  │       │
[保存]  [地图/传送]     [取消]
  │       │              │
  ↓       ↓              ↓
原存档流程  打开地图界面   关闭面板，恢复游戏
（回血→   （见地图系统）  （不保存）
 播放动画
 →保存）
```

### 8.4 保存流程

选择 [保存] 时，沿用现有逻辑：
- `Game.save_game("savepoint")`
- 玩家回血（`recover_full_health_once`）
- 播放存档点 ready → save → recover 动画
- 保存完成后自动关闭面板

### 8.5 数据层

`SavePointData`（存档点配置资源）：

```gdscript
class_name SavePointData
extends Resource

@export var point_id: StringName          # 唯一标识，如 "world1_save_1"
@export var display_name: String          # 显示名称，如 "第一节 教室"
@export var scene_path: String            # 目标场景路径，如 "res://system/levels/world.tscn"
@export var player_position: Vector2      # 传送后玩家坐标
@export var player_direction: int = 1     # 传送后玩家朝向
@export var world_name: String            # 所属世界，如 "世界一"
```

每个存档点对应一个 `.tres`，存储在 `resources/save_points/` 目录。

---

## 九、地图系统（新增）

### 9.1 设计理念

- **缩略文字地图** — 使用 VonwaonBitmap-12px 字体以缩小的字号渲染，展示已走过的区域
- **标记点** — 使用 16px 字号的高亮标记表示已发现的存档点
- **当前位置** — 闪烁的光标指示玩家所在位置
- **传送入口** — 在地图上选择已发现的存档点可以直接传送

### 9.2 布局

```
┌──────────────────────────────────┐
│         🗺️ 地图                  │
│                                  │
│   ┌────────────────────────┐     │
│   │                        │     │
│   │    世界一   教室         │     │  ← 12px文字表示已走过区域
│   │    🏴 教室存档点         │     │  ← 16px高亮标记+存档点名
│   │    世界一   操场         │     │
│   │    🏴 操场存档点         │     │
│   │    ▽ 出口（未开启）       │     │
│   │                        │     │
│   │  ─── 世界二 ───         │     │  ← 分隔线
│   │                        │     │
│   │    🏴 商鞅场景           │     │
│   │    🏴 马车场景           │     │
│   │                        │     │
│   └────────────────────────┘     │
│                                  │
│   已探索: 70%  |  [返回]         │  ← 探索进度 + 关闭按钮
└──────────────────────────────────┘
```

### 9.3 核心机制

#### 探索记录

```gdscript
# 挂在 Player 或 Game 上
class_name MapExploration
extends Node

var explored_regions: Dictionary = {}           # { "region_id": true }
var discovered_save_points: Array[StringName] = []

var exploration_percentage: float:
	get:
		var total = _total_region_count()
		if total == 0:
			return 0.0
		return float(explored_regions.size()) / float(total) * 100.0

signal region_discovered(region_id: StringName)
signal save_point_discovered(point_id: StringName)
```

#### 地图数据配置

```gdscript
class_name MapWorldConfig
extends Resource

@export var world_name: String                     # "世界一"
@export var regions: Array[MapRegionConfig]


class_name MapRegionConfig
extends Resource

@export var region_id: StringName
@export var display_name: String                   # "教室"
@export var rect: Rect2                            # 在地图上的矩形区域
@export var connected_regions: Array[StringName]
@export var save_point_id: StringName = &""        # 关联的存档点 ID
```

地图数据集中存放在 `resources/map_data/`。

### 9.4 区域发现机制

- 玩家进入新区域 → 自动记录 `explored_regions`
- 首次发现时弹出通知 `[发现] 教室`
- 地图上已探索区域用 12px 字体渲染，未探索区域显示为 `???`
- 靠近存档点（进入交互范围）→ 自动记录 `discovered_save_points`
- 存档点位置在地图上用 16px 字体高亮标记

```gdscript
class_name MapRegionTrigger
extends Area2D

@export var region_id: StringName
@export var display_name: String

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var map: MapExploration = _get_map_exploration()
		if map and not map.explored_regions.has(region_id):
			map.explored_regions[region_id] = true
			map.region_discovered.emit(region_id)
			_show_notification("发现: %s" % display_name)
```

### 9.5 地图渲染规则

- 地图渲染使用 `Label` 节点，设置 VonwaonBitmap-12px 字体
- 实际视觉上缩小显示（整体缩放或调节字号渲染）
- 探索过的区域用 12px 字号显示区域名
- 存档点标记用 16px 字号高亮
- 当前位置用闪烁光标（定时切换可见性）
- 分隔线用 Unicode 字符 `───` 拼接

文字渲染方式（按行构建）：

```gdscript
class MapRowSegment:
	var text: String          # 显示文本，如 "教室"
	var font_size: int        # 12 或 16
	var color: Color          # 字体颜色
	var is_blinking: bool     # 是否闪烁（当前位置）
	var save_point_id: String # 关联存档点（用于传送）
```

### 9.6 打开方式

- 暂停菜单 → [地图] 按钮
- 存档点交互面板 → [打开地图 / 传送]
- 按 `M` 键（新增快捷键）

打开时暂停游戏（`tree.paused = true`），显示全屏 CanvasLayer（layer = 100）。

---

## 十、传送功能（新增）

### 10.1 传送入口

| 入口 | 说明 |
|------|------|
| 存档点交互 → [地图/传送] | 在存档点打开地图，选择目标存档点传送 |
| 暂停菜单 → [地图] | 打开地图后选择目标存档点传送 |
| 地图内选中存档点 → 按 E | 确认传送到该存档点 |

### 10.2 传送流程

```
在地图上选中一个已发现的存档点
      ↓ 按 E / [传送] 按钮
弹出确认弹窗："传送到 [存档点名]？"
      ↓
┌───┴───┐
[确认]  [取消]
  │      │
  ↓      ↓
保存当前状态   关闭确认弹窗
→ 黑屏淡出     → 返回地图
→ 加载目标场景
→ 设置玩家位置
→ 黑屏淡入
→ 恢复游戏
```

### 10.3 传送实现

```gdscript
func teleport_to_save_point(point_id: StringName) -> void:
	if not _is_discovered(point_id):
		return
	
	var data := _load_save_point_data(point_id)
	if data == null:
		return
	
	Game.save_game("savepoint", true)
	
	Game.change_scene(data.scene_path, {
		"position": data.player_position,
		"direction": data.player_direction,
	})
```

### 10.4 地图界面的传送交互

在地图界面中用方向键/WASD 移动选中框，选中存档点标记时高亮，按 `E` / `Space` 弹出确认弹窗，确认后执行传送。按 `M` / `ESC` 关闭地图。

### 10.5 传送限制

- 只能传送到 **已发现** 的存档点
- 当前场景未保存的状态在传送前自动保存（`Game.save_game("savepoint", true)`）
- 战斗中或 Boss 战场景中**禁止传送**（地图界面上禁用传送按钮或灰化标记）
- 传送后不清除 `world_states`，确保回到原场景时状态完整

---

## 十二、确认弹窗（通用组件，新增）

### 12.1 设计

```
┌─────────────────────────────┐
│                             │
│  确定要离开游戏吗？          │
│  未保存的进度将丢失。        │
│                             │
│      [确定]   [取消]        │
└─────────────────────────────┘
```

### 12.2 引用方式

```gdscript
# 全局函数（挂载在 Game 或独立的 PopupManager 上）
func show_confirm(
	title: String,
	message: String,
	on_confirm: Callable,
	on_cancel: Callable = Callable()
) -> void
```

- 叠加在当前 UI 之上（半透明遮罩）
- 不影响当前 UI 的 paused 状态
- 按 `ESC` 默认触发取消

---

## 十三、存档槽位选择（新增）

### 13.1 入口

- 标题画面的"继续冒险" → 如果有存档 → 自动加载（当前行为）
- 暂停菜单的"读取存档" → 弹出存档槽位列表

### 13.2 UI

```
┌──────────────────────────────────┐
│          读取存档                │
│                                  │
│  ┌────────────────────────┐      │
│  │ 存档位 1   World2      │      │  ← 显示关卡名、日期
│  │  2026-05-01 14:30      │      │
│  ├────────────────────────┤      │
│  │ 存档位 2   [空]        │      │
│  ├────────────────────────┤      │
│  │ 存档位 3   [空]        │      │
│  └────────────────────────┘      │
│                                  │
│  [取消]                          │
└──────────────────────────────────┘
```

- **暂定 3 个存档槽位**（可扩展），未来可视需要增加
- 选择存档位 → 调用 `Game.load_game(true, slot_name)`

---

## 十四、NPC 交互提示（新增 World Space UI）

### 14.1 设计

- 当玩家进入 NPC 交互区域时，NPC 头顶或上方显示 `[E] 交互` 提示
- 使用 World Space 的 `Node2D`（挂载在 NPC 子节点），始终面向镜头
- 现有资源 `按e提示.png` 可直接复用

### 14.2 行为

- 淡入/淡出动画（进入/离开交互区域）
- 交互后暂时消失（如商鞅在对话中隐藏提示）
- 当玩家背对 NPC 时透明度降低或隐藏（可选）

---

## 十五、Boss 血条 — 已有，无需大改

- 已有 `boss_health_bar.tscn`，支持阶段动画切换
- 建议后续补充：Boss 名称文字使用像素字体统一风格
- 需确保在 Boss 场景中始终正确绑定 `Stats` 节点

---

## 十六、标题画面 — 需扩展

**当前：** 新游戏 / 继续冒险 / 离开游戏  
**扩展后：**

```
┌──────────────────────────────────┐
│                                  │
│        文字地狱                  │  ← 游戏标题（像素风）
│        重制版                    │
│                                  │
│     [梦的开始]  新游戏           │
│     [继续冒险]  读档             │
│     [设置]                       │  ← 新增
│     [离开游戏]                   │
│                                  │
└──────────────────────────────────┘
```

- "设置"：复用第六节的设置页面

---

## 十七、实现优先级与排期

### Phase 1 — 基础框架（必须有）

| 任务 | 预估工作量 | 前置依赖 |
|------|------------|----------|
| `InventoryItem` 资源类 + 物品数据配置 | 半天 | 无 |
| `PlayerInventory` 节点 + 存档集成 | 1 天 | InventoryItem |
| **背包 UI**（打开/关闭/网格/详情/使用） | 2 天 | PlayerInventory |
| **快捷物品栏 Hotbar**（HUD 底部） | 1 天 | PlayerInventory |
| **暂停菜单**（改造 ESC 行为） | 1 天 | 无 |
| **Game Over 通用画面** | 1 天 | 无 |

### Phase 2 — 体验完善

| 任务 | 预估工作量 | 前置依赖 |
|------|------------|----------|
| **设置页面**（音量+BGM/SFX/UI 控制） | 1 天 | 无 |
| **确认弹窗**（通用组件） | 0.5 天 | 无 |
| **存档槽位选择 UI** | 1 天 | 无 |
| **关卡结算画面** | 1 天 | Phase 1 |

### Phase 3 — 锦上添花

| 任务 | 预估工作量 | 前置依赖 |
|------|------------|----------|
| NPC 交互提示（World Space） | 0.5 天 | 无 |
| 标题画面扩展（章节选择 + 设置入口） | 1 天 | 设置页面 |
| 背包拖拽交互（鼠标拖放移动物品） | 1 天 | 背包 UI |
| 背包排序/筛选 | 0.5 天 | 背包 UI |

---

## 十八、技术要点

### 18.1 UI 层级约定

| Layer | 内容 |
|-------|------|
| 0~10 | 游戏世界 |
| 64 | HUD（status_panel, hotbar） |
| 100 | 背包 / 暂停菜单 / 设置 |
| 120 | 确认弹窗（叠加在其他 UI 之上） |
| 128 | 死亡重试 / Game Over |
| 200 | 全屏特效过渡（白闪等） |

### 18.2 输入处理

所有新增 UI 使用 `Control` 节点的 `_input(event)` 或 `gui_input` 处理。当 UI 打开时阻止事件向下传递（`Control.MOUSE_FILTER_STOP`）。暂停菜单/背包通过 `Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)` 显示鼠标。

### 18.3 资源目录结构

```
system/ui/
├── status_panel.tscn/.gd       # 已有 HUD
├── heart_cell.tscn/.gd          # 已有
├── ink_slot.tscn/.gd            # 已有
├── boss_health_bar.tscn/.gd     # 已有
├── world3_death_retry_ui.tscn/.gd  # 已有
│
├── inventory/                   # 新增：背包系统
│   ├── inventory_item.gd        # 物品资源基类
│   ├── inventory_slot.gd        # 单格数据类
│   ├── player_inventory.gd      # 玩家背包管理器
│   ├── inventory_ui.tscn/.gd    # 背包主界面
│   ├── inventory_slot_ui.tscn/.gd  # 单格 UI 控件
│   └── hotbar_ui.tscn/.gd       # 快捷栏 UI
│
├── map/                         # 新增：地图系统
│   ├── map_ui.tscn/.gd          # 地图主界面
│   ├── map_exploration.gd       # 探索记录管理器
│   ├── map_region_trigger.gd    # 区域检测触发器
│   └── map_savepoint_marker.tscn/.gd  # 存档点标记 UI
│
├── save_point/                  # 新增：存档点交互
│   ├── save_point_panel.tscn/.gd  # 存档点交互选择面板
│   └── save_point_data.gd       # 存档点配置资源
│
├── pause_menu.tscn/.gd          # 新增：暂停菜单
├── settings_panel.tscn/.gd      # 新增：设置页面
├── game_over.tscn/.gd           # 新增：Game Over
├── level_complete.tscn/.gd      # 新增：结算画面
├── confirm_popup.tscn/.gd       # 新增：确认弹窗
├── save_slot_selector.tscn/.gd  # 新增：存档槽选择
└── npc_interact_hint.tscn/.gd   # 新增：NPC 交互提示（World Space）
```

### 18.4 物品数据配置

每个物品对应一个 `.tres` 文件，集中管理：

```
resources/items/
├── potion_health.tres
├── potion_speed.tres
├── summon_shangyang.tres
├── summon_xx.tres
└── ...
```

通过一个全局 `InventoryDB`（或直接在 `Game` 上）按 `id` 加载物品资源。

### 18.5 召唤书切换机制

```
当前行为（固定）:
 Player.shangyang_summon_unlocked = true
 → HUD 显示召唤冷却条
 → F 键召唤商鞅

改为背包装备后（动态）:
 Player.active_summon_item: InventoryItem
 → 如果 active_summon_item 为 null: 无召唤能力，HUD 隐藏冷却条
 → 如果 active_summon_item == summon_shangyang: F 键召唤商鞅（现有逻辑）
 → 如果 active_summon_item == summon_xx: F 键召唤 XX（预留）
```

背包 UI 中选中召唤书 → [使用] → `PlayerInventory.equip_summon(item_id)` → 玩家获得对应召唤能力。

---

## 十九、物品掉落/获取机制（规划）

- 关卡结算奖励 → 背包获取（显示通知 `[获得] 血药 × 1`）
- NPC 剧情奖励（如商鞅获得能力后 → 解锁 `summon_shangyang` 放入背包）
- 场景中拾取（World2 肢体收集完成后 → 关底奖励召唤书）
- 未来：商店购买、宝箱开启等

通知形式：屏幕中央偏上浮现 `[获得] 物品名 × 数量`，淡入停留 → 淡出，不阻塞操作。

---

## 二十、字体规范（新增）

### 20.1 可用字体

| 字体文件 | 路径 | 用途 |
|---------|------|------|
| VonwaonBitmap-12px | `res://assets/资源总库/11_字体/VonwaonBitmap-12px.ttf` | HUD 文字、地图区域名、物品描述、UI 正文、提示文字 |
| VonwaonBitmap-16px | `res://assets/资源总库/11_字体/VonwaonBitmap-16px.ttf` | 标题、存档点名标记、Boss 名称、数值显示、按钮文字 |

两字体均有副本在 `res://addons/dialogic/样式/字体/`，优先使用 `res://assets/资源总库/11_字体/` 下的主副本。

### 20.2 字号规则

所有 UI 文字字号必须为 **12 的倍数** 或 **16 的倍数**，取决于使用的字体：

| 字体 | 允许字号 | 典型使用场景 |
|------|---------|-------------|
| VonwaonBitmap-12px | 12, 24, 36, 48 | 地图区域名(12px)、HUD 数值(24px)、通知文字(12px) |
| VonwaonBitmap-16px | 16, 32, 48, 64 | 标题(32px)、按钮(16px)、存档点名(16px)、Boss 名(32px) |

### 20.3 地图文字渲染规则

- 地图上的区域名称使用 **VonwaonBitmap-12px** 渲染，实际显示时通过 `scale` 或 `theme_override_font_sizes` 缩小视觉尺寸
- 已探索区域：白色 12px，不透明度 0.9
- 未探索区域：灰色 12px，显示 `???`
- 存档点标记：使用 **VonwaonBitmap-16px** 高亮，颜色随世界不同（世界一：青色，世界二：黄色，世界三：红色）
- 当前位置光标：使用 16px `▶` 符号定时闪烁
- 探索进度百分比：12px，白色

### 20.4 资源加载方式

```gdscript
const FONT_12 := preload("res://assets/资源总库/11_字体/VonwaonBitmap-12px.ttf")
const FONT_16 := preload("res://assets/资源总库/11_字体/VonwaonBitmap-16px.ttf")

# Label 节点设置字体
label.add_theme_font_override(&"font", FONT_12)
label.add_theme_font_size_override(&"font_size", 12)

# RichTextLabel 使用
rich_label.push_font(FONT_16, 16)
```

### 20.5 背景与按钮占位规则

- 所有新增 UI 的背景元素（ColorRect、Panel、NinePatchRect）和按钮素材暂时使用临时占位
- 占位方式：纯色 ColorRect（深色半透明背景 `#1a1a1acc`，按钮使用 `#333333`）、或使用现有 UI 资源（`ui.png`）中的可用区域裁切
- 后续由美术统一替换为像素风 UI 贴图（`03_图像_UI/` 下新增对应素材）
- 暂不追求视觉细节，优先保证功能完整和布局正确

---


Phase 1 — 基础设施（必须从这开始）
#	任务	原因
1	数据层：InventoryItem 资源类 + 物品 .tres 配置	所有 UI 的数据基础，无前置依赖
2	数据层：PlayerInventory 节点 + 存档集成	背包/快捷栏/召唤书都依赖它
3	ConfirmPopup 通用确认弹窗	暂停菜单、存档、丢弃物品、传送全部需要
4	暂停菜单（改造 ESC 行为、替代当前直接存档）	背包/地图/设置的入口
Phase 2 — 背包与快捷栏
#	任务	原因
5	背包 UI（打开/关闭/网格/详情/使用/丢弃/装备）	核心界面，依赖 Phase 1
6	Hotbar 快捷栏（屏幕底部 8 格，数字键切换）	依赖 PlayerInventory，与背包装备联动
7	召唤书装备机制（Player 属性改造 + HUD 联动）	依赖背包装备功能
Phase 3 — 存档点与地图
#	任务	原因
8	SavePointData 资源配置 + 修改现有 SavePointInteractable 弹出交互面板	需要 ConfirmPopup
9	地图系统：MapExploration + 文字地图 UI + 区域检测触发器	需要暂停菜单入口
10	传送功能：地图内选中存档点传送 + 限制逻辑	依赖地图系统 + 存档点改造
Phase 4 — 体验完善
#	任务	原因
11	Game Over 通用画面（非 World3 场景死亡）	可以作为独立任务
12	设置页面（音量+显示模式）	暂停菜单入口已就绪
13	关卡结算画面	低优先级
14	NPC 交互提示 + 存档点 [E] 提示	低优先级，World Space UI
15	标题画面扩展（加"设置"入口）	依赖设置页面
16	存档槽位选择 UI（3 槽位）	低优先级
核心原则
Phase 1 请严格按 1→2→3→4 顺序，后面的可以跳过或调整顺序
如果时间紧张，可以直接给我发 Phase 1 全部 或 Phase 1 #1 + Phase 2 #5 #6 这样打包
如果想先看效果再决定，可以从 Phase 2 #5（背包 UI） 开始——我可以用假数据先跑通界面，但注意背包打开时需要暂停菜单（#4）做的 tree.paused 逻辑
要我直接开始 Phase 1 的第 1 项吗？

> 本文档为设计方案，具体实现时各 UI 按 Phase 优先级独立完成。每个 UI 完成后需接入 Game 存档体系，确保断点续玩。